use warp::{sse, Filter};

use serde::{Serialize, Deserialize};
use async_stream::stream;

use lazy_static::lazy_static;

use std::collections::HashMap;
use std::sync::{Arc, Mutex};

use std::path::Path;
use std::time::Duration;
use std::convert::Infallible;

use notify::RecursiveMode;
use notify_debouncer_mini::new_debouncer;




// -- document data ------------------------------------------------------------

#[derive(Serialize, Deserialize, Debug, Clone)]
struct Text {
    text: String,
    x: f64,
    y: f64,
    width: f64,
}

lazy_static! {
    static ref DOC_PATH: String = std::env::args().nth(1).unwrap();
    static ref FRONT_PATH: String = std::env::args().nth(2).unwrap();
    static ref DOCUMENT: Arc<Mutex<HashMap<String, Text>>> = {
        let mut document = HashMap::new();
        document.insert("foo".to_string(), Text {
            text: "Hello ".repeat(50),
            x: -300.0,
            y: 0.0,
            width: 600.0,
        });
        document.insert("bar".to_string(), Text {
            text: "World ".repeat(30),
            x: 100.0,
            y: 300.0,
            width: 300.0,
        });
        Arc::new(Mutex::new(document))
    };

    // quick and dirty cross-thread signalling, by polling a bool to see if
    // we need to refresh stuff every second. Go back and try to figure out 
    // the correct solution again later.
    //
    // https://gist.github.com/FraserLee/b75d88642827c5e0f49c0b8d96ad848e

    static ref DOCUMENT_REFRESHED: Arc<Mutex<bool>> = Arc::new(Mutex::new(false));
}






fn load_document() {
    // Todo: properly parse the document and all that.

    let mut document = DOCUMENT.lock().unwrap();

    let text = std::fs::read_to_string(&*DOC_PATH).unwrap();

    document.clear();

    document.insert("foo".to_string(), Text {
        text,
        x: -350.0,
        y: 3.0,
        width: 700.0,
    });

    println!("Loaded from disk: {}", &*DOC_PATH);
}

fn save_document() { // todo: this too
    let document = DOCUMENT.lock().unwrap();

    let text = document.get("foo").unwrap().text.clone();

    std::fs::write(&*DOC_PATH, text).unwrap();

    println!("Saved to disk: {}", &*DOC_PATH);
}



// -- main ---------------------------------------------------------------------

#[tokio::main]
async fn main() {

    load_document();

    // -- watch file, reload on change -----------------------------------------

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
                    load_document(); 
                    *DOCUMENT_REFRESHED.lock().unwrap() = true;
                },
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
    let update = warp::path!("update" / String)
        .and(warp::body::json())
        .map(|key: String, text: Text| {
            DOCUMENT.lock().unwrap().insert(key, text);
            warp::reply()
        });

    // simple SSE event
    fn sse_event() -> Result<sse::Event, Infallible> { Ok(sse::Event::default().data("")) }

    // send an SSE event on /file_change every time the document is reloaded
    let file_change_sse = warp::path("file_change").and(warp::get()).map(|| {
        let stream = stream! {
            loop {
                tokio::time::sleep(Duration::from_millis(500)).await;
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
