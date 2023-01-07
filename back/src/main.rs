use warp::Filter;
use serde_json::json;


#[tokio::main]
async fn main() {
    let doc_path = std::env::args().nth(1).unwrap();
    let front_path = std::env::args().nth(2).unwrap();

    // -------------------------------- routes ---------------------------------

    // GET / => front_path/index.html
    let front = warp::path::end().and(warp::fs::file(front_path.clone() + "/index.html"));
    // GET /fetch => send json containing { hello: "world" }
    let fetch = warp::path("fetch").map(|| warp::reply::json(&json!({ "hello": "world" })));
    // GET /<path> => front_path/<path>
    let static_files = warp::fs::dir(front_path.clone() + "/");

    let routes = front.or(fetch).or(static_files);

    // -------------------------------- server ---------------------------------

    println!("serving at http://localhost:3100");
    println!("doc path: {}", doc_path);
    println!(" -- press ctrl-c to stop --");

    warp::serve(routes).run(([127, 0, 0, 1], 3100)).await;

}
