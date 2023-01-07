use warp::{sse::Event, Filter};

use serde::{Serialize, Deserialize};

use lazy_static::lazy_static;

use std::collections::HashMap;
use std::sync::{Arc, Mutex};

use futures_util::StreamExt;
use std::convert::Infallible;
use std::time::Duration;
use tokio::time::interval;
use tokio_stream::wrappers::IntervalStream;

// create server-sent event
fn sse_counter(counter: u64) -> Result<Event, Infallible> {
    Ok(warp::sse::Event::default().data(counter.to_string()))
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

// -- main ---------------------------------------------------------------------

#[tokio::main]
async fn main() {


    let doc_path = std::env::args().nth(1).unwrap();
    let front_path = std::env::args().nth(2).unwrap();

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

    let tick = warp::path("refresh").and(warp::get()).map(|| {
        let mut counter: u64 = 0;
        // create server event source
        let interval = interval(Duration::from_secs(15));
        let stream = IntervalStream::new(interval);
        let event_stream = stream.map(move |_| {
            counter += 1;
            sse_counter(counter)
        });
        // reply using server-sent events
        warp::sse::reply(event_stream)
    });

    let routes = front.or(fetch).or(static_files).or(update).or(tick);

    // -- run server -----------------------------------------------------------

    println!("doc path: {}", doc_path);
    println!(" --------------------------------------");
    println!(" -- serving at http://localhost:3100 --");
    println!(" -------- press ctrl-c to stop --------");

    warp::serve(routes).run(([127, 0, 0, 1], 3100)).await;

}
