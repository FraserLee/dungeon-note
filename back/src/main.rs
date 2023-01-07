use warp::Filter;
use serde::{Serialize, Deserialize};
use std::collections::HashMap;
use lazy_static::lazy_static;
use std::sync::{Arc, Mutex};

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

    let routes = front.or(fetch).or(static_files).or(update);

    // -- run server -----------------------------------------------------------

    println!("serving at http://localhost:3100");
    println!("doc path: {}", doc_path);
    println!(" -- press ctrl-c to stop --");

    warp::serve(routes).run(([127, 0, 0, 1], 3100)).await;

}
