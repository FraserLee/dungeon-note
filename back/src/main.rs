use std::convert::Infallible;
use std::path::Path;

use async_stream::stream;
use futures::{ channel::mpsc::{channel, Receiver}, SinkExt };
use futures_core::stream::Stream;
use futures_util::stream::StreamExt;
use futures_util::pin_mut;
use warp::sse;

use notify::{ Event, RecommendedWatcher, RecursiveMode, Watcher, Config };


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

fn watch_stream() -> impl Stream<Item = Result<sse::Event, Infallible>> {
    let (mut watcher, mut rx) = async_watcher().unwrap();

    watcher.watch(
            Path::new(&*std::env::args().nth(1).unwrap()), 
            RecursiveMode::Recursive
        ).unwrap();

    return stream! {
        while let Some(res) = rx.next().await {
            match res {
                Ok(event) => { println!("event: {:?}", event); }
                Err(e) => { println!("watch error: {:?}", e); }
            }
            yield sse_event();
        }
    };
}


async fn watch_a() {
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

    pin_mut!(stream);
    while let Some(_) = stream.next().await {
        println!("stream");
    }
}

async fn watch_b() {
    let stream = watch_stream();
    pin_mut!(stream);
    while let Some(_) = stream.next().await {
        println!("stream");
    }
}





#[tokio::main]
async fn main() {
    watch_b().await;
}


