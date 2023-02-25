#![feature(let_chains)]

use warp::{sse, Filter};

use async_stream::stream;

use lazy_static::lazy_static;

use std::convert::Infallible;
use std::path::Path;
use std::sync::{Arc, Mutex};
use std::time::{Duration, SystemTime};
use std::fs::File;
use std::io::prelude::*;

use notify::RecursiveMode;
use notify_debouncer_mini::new_debouncer;

mod parser;
use parser::{Document, DocumentUpdate, Element, TextBlock, TextChunk};

// -- document data ------------------------------------------------------------

lazy_static! {
    static ref DOC_PATH: String = std::env::args().nth(1).unwrap_or("".to_string());
    static ref FRONT_PATH: String = std::env::args().nth(2).unwrap_or("".to_string());
    static ref DOCUMENT: Arc<Mutex<Document>> = Arc::new(Mutex::new(Document::new()));

    // quick and dirty cross-thread signalling, by polling a bool to see if
    // we need to refresh stuff every second. Go back and try to figure out
    // the correct solution again later.
    //
    // https://gist.github.com/FraserLee/b75d88642827c5e0f49c0b8d96ad848e

    // set true by the file watcher thread, then set false by the main thread after
    // sending an SSE to the client telling it to refresh
    static ref DOCUMENT_REFRESHED: Arc<Mutex<bool>> = Arc::new(Mutex::new(false));

    // set to the current time (plus some small buffer) when writing to the 
    // file. Only trigger a file watcher event if the current time is greater
    // than this value.
    static ref WATCH_BLOCK_CHECK: Arc<Mutex<SystemTime>> = Arc::new(Mutex::new(SystemTime::UNIX_EPOCH));
}




fn load_document() {
    let mut document = DOCUMENT.lock().unwrap();

    let text = std::fs::read_to_string(&*DOC_PATH).unwrap();

    let parsed = parser::parse(&text);

    *document = parsed;

    // for (key, element) in document.elements.iter() {
    //     if let Element::TextBox { raw_content, .. } = element {
    //         println!("{}: {}", key, raw_content[0..100.min(raw_content.len())].replace("\n", "\\n"));
    //     }
    // }

    println!("Loaded from disk: {}", &*DOC_PATH);
}

fn save_document() {
    let document = DOCUMENT.lock().unwrap();
    let mut watch_block_check = WATCH_BLOCK_CHECK.lock().unwrap();

    // set WATCH_BLOCK_CHECK to current + 10 seconds, in case writing takes a bit of time. 
    *watch_block_check = SystemTime::now() + Duration::from_secs(10);
    // I think the fact that we're unlocking the mutex at the start of this 
    // method *should* mean we're blocking it anyways, so this is unnecessary,
    // but I'm not confident that the order of operations is guaranteed to be stable.

    let mut file = File::create(&*DOC_PATH).unwrap();

    document.elements.values().for_each(|element| {
        file.write(element.write_repr().as_bytes()).unwrap();
    });

    // set WATCH_BLOCK_CHECK to current + 1 second
    *watch_block_check = SystemTime::now() + Duration::from_secs(1);
}



// -- main ---------------------------------------------------------------------

#[tokio::main]
async fn main() {
    // -- build shared types ---------------------------------------------------

    // if the first argument is "--rebuild_shared_types", then just build shared types and exit
    if std::env::args().nth(1) == Some("--rebuild_shared_types".to_string()) {

        let mut target = File::create(
            env!("CARGO_MANIFEST_DIR").replace("rust", "elm/src/Bindings.elm"),
        ).unwrap();

        elm_rs::export!("Bindings", &mut target, {
            encoders: [Document, Element, TextBlock, TextChunk, DocumentUpdate],
            decoders: [Document, Element, TextBlock, TextChunk, DocumentUpdate],
        }).unwrap();

        return;
    }


    // -- watch file, reload on change -----------------------------------------

    load_document(); // load it once at the start

    std::thread::spawn(|| {

        let (tx, rx) = std::sync::mpsc::channel();

        let mut debouncer = new_debouncer(Duration::from_millis(500), None, tx).unwrap();

        debouncer.watcher()
                 .watch(
                     Path::new(&*DOC_PATH), 
                     RecursiveMode::Recursive
                 ).unwrap();

        loop {
            match rx.recv() {
                Ok(_) => {

                    let watch_block_check = WATCH_BLOCK_CHECK.lock().unwrap();
                    if SystemTime::now() < *watch_block_check { continue; }

                    load_document();
                    *DOCUMENT_REFRESHED.lock().unwrap() = true;
                }
                Err(e) => { println!("watch error: {:?}", e); }
            }
        }
    });



    // -- routes ---------------------------------------------------------------

    // GET / => front_path/index.html
    let front = warp::path::end().and(warp::fs::file(FRONT_PATH.clone() + "/index.html"));
    // GET /fetch => send json encoded document
    let fetch = warp::path("fetch").map(|| warp::reply::json(&*DOCUMENT.lock().unwrap()));
    // GET /<path> => front_path/<path>
    let static_files = warp::fs::dir(FRONT_PATH.clone() + "/");
    // POST /update/<id> => update document with json encoded Text
    let update = warp::path!("update" / String).and(warp::body::json()).map(
        |key: String, update: DocumentUpdate| {

            {
                let mut document = DOCUMENT.lock().unwrap();

                if document.created > update.doc_created {
                    println!("Ignoring stale update");
                    return warp::reply::with_status(warp::reply(), warp::http::StatusCode::NOT_MODIFIED);
                }

                print!("updating: {}...", key);

                // if we're updating an already existing element from Element::TextBox to Element::TextBox,
                // then keep the raw_content field the same (while replacing everything else).
                // Otherwise, just replace the whole element.

                let new_element = // weirdly hard to make this code better, yada yada borrow checker
                    if let Some(Element::TextBox { raw_content, .. }) = document.elements.get(&key) {
                        if let Element::TextBox { x, y, width, data, raw_content: _ } = update.element {
                            Element::TextBox { x, y, width, data, raw_content: raw_content.clone() }
                        } else {
                            update.element
                        }
                    } else {
                        update.element
                    };

                document.elements.insert(key, new_element);
            }

            save_document();
            
            println!("done");
            
            warp::reply::with_status(warp::reply(), warp::http::StatusCode::OK)
    } );

    // simple SSE event
    fn sse_event() -> Result<sse::Event, Infallible> {
        Ok(sse::Event::default().data(""))
    }

    // send an SSE event on /file_change every time the document is reloaded
    let file_change_sse = warp::path("file_change").and(warp::get()).map(|| {
        let stream = stream! {
            loop {
                tokio::time::sleep(Duration::from_millis(250)).await;
                if *DOCUMENT_REFRESHED.lock().unwrap() {
                    *DOCUMENT_REFRESHED.lock().unwrap() = false;
                    yield sse_event();
                }
            }
        };
        warp::sse::reply(warp::sse::keep_alive().stream(stream))
    });

    let routes = front.or(fetch).or(static_files).or(update).or(file_change_sse);



    // -- run server -----------------------------------------------------------

    println!(" --------------------------------------");
    println!(" -- serving at http://localhost:3100 --");
    println!(" -------- press ctrl-c to stop --------");

    warp::serve(routes).run(([127, 0, 0, 1], 3100)).await;

}
