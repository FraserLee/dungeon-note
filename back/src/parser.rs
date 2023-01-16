use std::collections::hash_map::DefaultHasher;
use std::collections::HashMap;
use std::hash::{Hash, Hasher};

use serde::{Serialize, Deserialize};

use regex::Regex;


pub type Document = HashMap<String, Element>;

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Element {
    text: String,
    x: f64,
    y: f64,
    width: f64,
}

#[derive(Hash, Debug)]
struct ElementPrecursor {
    startline: usize,
    endline: usize,
    fields: Vec<String>,
}

pub fn parse(text: &str) -> Document {
    let mut document = Document::new();

    // find all the elements in the document
    // a element header will look like this:
    // !!!!Text!x:370.0!y:150.0!width:300.0!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    let re = Regex::new(r"^!!(?:!+)(Text)!x:(-?\d+(?:\.\d)?)!y:(-?\d+(?:\.\d)?)!width:(-?\d+(?:\.\d)?)!!!").unwrap();

    // first pass: scan through and mark out the boundaries of each element, and save all metadata info
    let mut element_precursors: Vec<ElementPrecursor> = Vec::new();

    for (i, line) in text.lines().enumerate() {
        if let Some(caps) = re.captures(line) {

            let l = element_precursors.len();
            if l > 0 {
                element_precursors[l - 1].endline = i - 1;
            }

            let fields = caps.iter().skip(1).map(|x| x.unwrap().as_str().to_string()).collect();
            let precursor = ElementPrecursor { fields, startline: i, endline: i };
            element_precursors.push(precursor);
        }
    }

    let l = element_precursors.len();
    element_precursors[l - 1].endline = text.lines().count();

    // now we have all the elements, we can parse the contents of each and add them to the document
    for precursor in element_precursors {

        let text = text.lines().skip(precursor.startline + 1).take(precursor.endline - precursor.startline).collect::<Vec<&str>>().join("\n");

        // use the hash of the precursor as the key
        let mut hasher = DefaultHasher::new();
        precursor.hash(&mut hasher);
        let hash = hasher.finish();

        let element = Element {
            text,
            x: precursor.fields[1].parse().unwrap(),
            y: precursor.fields[2].parse().unwrap(),
            width: precursor.fields[3].parse().unwrap(),
        };

        document.insert(hash.to_string(), element);
    }

    document
}

