use std::{
    io::{prelude::*, BufReader},
    net::{TcpListener, TcpStream},
    path::Path,
    sync::{Arc, Mutex},
};

use notify::{Watcher, RecursiveMode};

use lazy_static::lazy_static;

use dungeon_parse::*;



lazy_static! {
    static ref FILE: Arc<Mutex<String>> = Arc::new(Mutex::new(String::new()));
    static ref FILENAME: Arc<Mutex<String>> = Arc::new(Mutex::new(String::new()));
}


fn load() {
    let file = std::fs::read_to_string(FILENAME.lock().unwrap().to_string());
    match file {
        Ok(c) => {
            let mut f = FILE.lock().unwrap();
            *f = c;
        }
        Err(e) => { println!("Error reading file: {:?}", e); }
    }
}

// called with `dungeon-watch some_file.md`
fn main() {

    let args: Vec<String> = std::env::args().collect();
    if args.len() != 2 {
        println!("Usage: dungeon-watch <file>");
        std::process::exit(1);
    }

    let mut filename = args[1].clone();

    // if the file doesn't exist, try with a .md extension
    if !Path::new(&filename).exists() {
        filename = if &filename[filename.len()-3..] == ".md" { filename.to_string() } 
                       else if &filename[filename.len()-1..] == "." { format!("{}md", filename) } 
                       else { format!("{}.md", filename) };

        if !Path::new(&filename).exists() {
            println!("File {} does not exist", filename);
            std::process::exit(1);
        }
    }

    {
        let mut f = FILENAME.lock().unwrap();
        *f = filename.clone();
    }

    load();

    // watch the file for changes
    println!("Watching for changes: {}", filename);

    let mut watcher = notify::recommended_watcher(|res| {
        match res {
            Ok(_) => load(),
            Err(e) => println!("Error Watching File: {:?}", e),
        }
    }).unwrap();

    watcher.watch(Path::new(&filename), RecursiveMode::Recursive).unwrap();



    let listener = TcpListener::bind("127.0.0.1:7878").unwrap();
    println!("Visit http://localhost:7878");

    for stream in listener.incoming() {
        let stream = stream.unwrap();
        handle_connection(stream);
    }
}

const HTML404: &str = r#"
<!DOCTYPE html>
<html lang="en">
    <head><title>404</title></head>
    <body>
        <h1>404</h1>
        Probably the wrong URL.
    </body>
</html>"#;



fn handle_connection(mut stream: TcpStream) {
    let buf_reader = BufReader::new(&mut stream);
    let request_line = buf_reader.lines().next().unwrap().unwrap();

    let (status_line, contents) = if request_line == "GET / HTTP/1.1" {
        ("HTTP/1.1 200 OK", parse(FILE.lock().unwrap().to_string()))
    } else {
        ("HTTP/1.1 404 NOT FOUND", HTML404.to_string())
    };

    let length = contents.len();

    let response =
        format!("{status_line}\r\nContent-Length: {length}\r\n\r\n{contents}");

    stream.write_all(response.as_bytes()).unwrap();
}
