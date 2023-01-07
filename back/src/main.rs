// MIN FAILING SAMPLE. 
// - Manually create a HTML page in a string that'll do the alert() thing. 
// - Possibly include timer one to show how working looks.
// - see if I can get it working with just a manual yield in the stream macro, not even using the watcher.

use std::convert::Infallible;
use std::path::Path;
use std::time::Duration;

use async_stream::stream;
use futures::{ channel::mpsc::{channel, Receiver}, SinkExt, };
use futures_util::stream::StreamExt;
use warp::{sse, Filter};

use notify::{ Event, RecommendedWatcher, RecursiveMode, Watcher, Config };

// index.html string
const INDEX_HTML: &str = r#"
<!DOCTYPE HTML>
<html>
<head> <meta charset="UTF-8"> </head>

<body>
  <h1>Warp SSE Push on File Change</h1>
  <script> 
      var tickSource = new EventSource("/tick");
      var fileChangeSource = new EventSource("/file_change");

      tickSource.onmessage = (event) => {
          document.body.innerHTML += "<p>tick event</p>";
      };

      fileChangeSource.onmessage = (event) => {
          document.body.innerHTML += "<p>file change event</p>";
      };
  </script>
</body>
</html>
"#;


// simple SSE event
fn sse_event() -> Result<sse::Event, Infallible> {
    Ok(sse::Event::default().data(""))
}

// async notify stuff

// https://github.com/notify-rs/notify/blob/e375fcefd23edd23e7138d8b3a97a721d6b7bbca/examples/async_monitor.rs#L22
fn async_watcher() -> notify::Result<(RecommendedWatcher, Receiver<notify::Result<Event>>)> {
    let (mut tx, rx) = channel(1);

    let watcher = RecommendedWatcher::new(move |res| {
        futures::executor::block_on(async {
            tx.send(res).await.unwrap();
        })
    }, Config::default())?;

    Ok((watcher, rx))
}

// -- main ---------------------------------------------------------------------

async fn sse_file_watch() {
    let index = warp::path::end().map(|| warp::reply::html(INDEX_HTML));

    // send an sse event on /tick every 3 seconds
    let tick_sse  = warp::path("tick").and(warp::get()).map(|| {

        let stream = stream! {
            loop {
                tokio::time::sleep(Duration::from_secs(3)).await;
                println!("tick");
                yield sse_event();
            }
        };

        warp::sse::reply(warp::sse::keep_alive().stream(stream))

    });

    // sse event on /file_change every time the file changes
    let file_change_sse = warp::path("file_change").and(warp::get()).map(|| {

        let (mut watcher, mut rx) = async_watcher().unwrap();

        watcher.watch(
                Path::new(&*std::env::args().nth(1).unwrap()), 
                RecursiveMode::Recursive
            ).unwrap();

        let stream = stream! {
            while let Some(res) = rx.next().await {
                match res {
                    Ok(event) => { println!("event: {:?}", event); }
                    Err(e) => { println!("watch error: {:?}", e); }
                }
                yield sse_event();
            }
        };

        warp::sse::reply(stream)
    });

    // -- run server -----------------------------------------------------------

    println!(" -- serving at http://localhost:3000 --");
    println!(" -------- press ctrl-c to stop --------");

    warp::serve(index.or(tick_sse).or(file_change_sse)).run(([127, 0, 0, 1], 3000)).await;
}

async fn local_file_watch() {
    let (mut watcher, mut rx) = async_watcher().unwrap();

    watcher.watch(
            Path::new(&*std::env::args().nth(1).unwrap()), 
            RecursiveMode::Recursive
        ).unwrap();

    loop {
        if let Some(res) = rx.next().await {
            match res {
                Ok(event) => { println!("event: {:?}", event); }
                Err(e) => { println!("watch error: {:?}", e); }
            }
        }
    }
}



#[tokio::main]
async fn main() { tokio::join!(sse_file_watch(), local_file_watch()); }
