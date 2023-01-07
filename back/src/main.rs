use warp::{sse, Filter};

use serde::{Serialize, Deserialize};

use lazy_static::lazy_static;

use std::collections::HashMap;
use std::sync::{Arc, Mutex};

use async_stream::stream;
use futures_util::stream::StreamExt;
use futures_util::pin_mut;
use std::convert::Infallible;
use std::time::Duration;
use tokio::time::interval;
use tokio_stream::wrappers::IntervalStream;
use futures_core::stream::Stream;
use futures::{
    channel::mpsc::{channel, Receiver},
    SinkExt,
};
use notify::{Event, RecommendedWatcher, RecursiveMode, Watcher, Config};
use std::path::Path;

// create server-sent event
fn sse_counter(counter: u64) -> Result<sse::Event, Infallible> {
    Ok(sse::Event::default().data(counter.to_string()))
}


// -- document data ------------------------------------------------------------

#[derive(Serialize, Deserialize, Debug, Clone)]
struct Text {
    text: String,
    x: f64,
    y: f64,
    width: f64,
}

lazy_static! {
    static ref doc_path: String = std::env::args().nth(1).unwrap();
    static ref front_path: String = std::env::args().nth(2).unwrap();
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
}

// -- watch for changes --------------------------------------------------------

fn async_watcher() -> notify::Result<(RecommendedWatcher, Receiver<notify::Result<Event>>)> {
    let (mut tx, rx) = channel(1);

    let watcher = RecommendedWatcher::new(move |res| {
        futures::executor::block_on(async {
            tx.send(res).await.unwrap();
        })
    }, Config::default())?;

    Ok((watcher, rx))
}

fn async_watcher_stream() -> impl Stream<Item = ()> {
    let (mut watcher, mut rx) = async_watcher().unwrap();
    watcher.watch(Path::new(&*doc_path), RecursiveMode::Recursive).unwrap();

    let stream = stream! {
        while let Some(res) = rx.next().await {
            match res {
                Ok(event) => {
                    println!("event: {:?}", event);
                    yield;
                }
                Err(e) => {
                    println!("watch error: {:?}", e);
                }
            }
        }
    };

    stream
}


// -- main ---------------------------------------------------------------------

#[tokio::main]
async fn main() {
    let watch_path = Path::new(&*doc_path);

    println!("doc path: {}", &*doc_path);


    // futures::executor::block_on(async {
    //     let (mut watcher, mut rx) = async_watcher().unwrap();
    //     watcher.watch(watch_path, RecursiveMode::Recursive).unwrap();
    //     while let Some(res) = rx.next().await {
    //         match res {
    //             Ok(event) => println!("changed: {:?}", event),
    //             Err(e) => println!("watch error: {:?}", e),
    //         }
    //     }
    // });

    // -- routes ---------------------------------------------------------------

    // GET / => front_path/index.html
    let front = warp::path::end().and(warp::fs::file(front_path.clone() + "/index.html"));
    // GET /fetch => send json encoded document
    let fetch = warp::path("fetch").map(|| warp::reply::json(&*DOCUMENT.lock().unwrap()));
    // GET /<path> => front_path/<path>
    let static_files = warp::fs::dir(front_path.clone() + "/");

    let update = warp::path!("update" / String)
        .and(warp::body::json())
        .map(|key: String, text: Text| {
            DOCUMENT.lock().unwrap().insert(key, text);
            warp::reply()
        });

    // let (mut watcher, mut rx) = async_watcher().unwrap();
    //
    // watcher.watch(watch_path, RecursiveMode::Recursive).unwrap();
    //
    // let stream = async_stream::stream! {
    //     while let Some(res) = rx.next().await {
    //         println!("AAAA");
    //         match res {
    //             Ok(event) => { println!("changed: {:?}", event); },
    //             Err(e) => { println!("watch error: {:?}", e); },
    //         }
    //         yield sse_counter(3);
    //     }
    // };
    //

    // let refresh = warp::path("refresh").map(|| {
    //     async_watcher_stream()
    // })
    // .map(|stream| stream)
    // .and(warp::sse())
    // .map(|stream, sse| {
    //     let stream = stream.map(|_| sse_counter(3));
    //     sse.reply(sse::keep_alive().stream(stream))
    // });



    // pin_mut!(stream);

    let refresh = warp::path("refresh").and(warp::get()).map(|| {
    //     warp::sse::reply(warp::sse::keep_alive().stream(stream))


        // // create server event source
        // let interval = interval(Duration::from_secs(10));
        // let stream = IntervalStream::new(interval);
        // let event_stream = stream.map(move |_| {
        //     dbg!("tick");
        //     sse_counter(0)
        // });
        // // reply using server-sent events
        // warp::sse::reply(event_stream)

        let (mut watcher, mut rx) = async_watcher().unwrap();

        // Add a path to be watched. All files and directories at that path and
        // below will be monitored for changes.
        watcher.watch(Path::new(&*doc_path), RecursiveMode::Recursive).unwrap();


        let stream = stream! {
            while let Some(res) = rx.next().await {
                match res {
                    Ok(event) => { println!("event: {:?}", event); }
                    Err(e) => { println!("watch error: {:?}", e); }
                }
                yield sse_counter(0);
            }
        };


        warp::sse::reply(stream)

    });

    let routes = front.or(fetch).or(static_files).or(update).or(refresh);

    // -- run server -----------------------------------------------------------

    println!(" --------------------------------------");
    println!(" -- serving at http://localhost:3100 --");
    println!(" -------- press ctrl-c to stop --------");

    warp::serve(routes).run(([127, 0, 0, 1], 3100)).await;

}
