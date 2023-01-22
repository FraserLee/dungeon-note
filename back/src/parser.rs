use std::collections::hash_map::DefaultHasher;
use std::collections::HashMap;
use std::hash::{Hash, Hasher};

use serde::{Serialize, Deserialize};
use elm_rs::{Elm, ElmEncode, ElmDecode};

use regex::Regex;


// --------------------------- types shared with elm ---------------------------

#[derive(Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub struct Document {
    pub elements: HashMap<String, Element>,
}
impl Document {
    pub fn new() -> Self {
        Self { elements: HashMap::new(), }
    }
}

#[derive(Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub enum Element {
    TextBox { x: f64, y: f64, width: f64, data: Vec<TextBlock> },
    Rect    { x: f64, y: f64, width: f64, height: f64, z: f64, color: String, },
    Line    { x1: f64, y1: f64, x2: f64, y2: f64, },
}

#[derive(Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub enum TextBlock {
    Paragraph { chunks: Vec<TextChunk> },
    Header { level: u8, chunks: Vec<TextChunk> },
    CodeBlock { code: String },
    VerticalSpace,
}

#[derive(Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub struct TextChunk {
    pub text: String,
    pub style: TextStyle,
}

#[derive(Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub struct TextStyle {
    pub bold: bool,
    pub italic: bool,
    pub underline: bool,
    pub strikethrough: bool,
}

// -----------------------------------------------------------------------------

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

    // TODO: grab parameters in any order
    // TODO: when missing, parse parameters to a default value

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

        let text = text.lines()
            .skip(precursor.startline + 1)
            .take(precursor.endline - precursor.startline)
            .collect::<Vec<&str>>()
            .join("\n");

        // use the hash of the precursor as the key
        let mut hasher = DefaultHasher::new();
        precursor.hash(&mut hasher);
        let hash = hasher.finish();

        let element = Element::TextBox {
            x: precursor.fields[1].parse().unwrap(),
            y: precursor.fields[2].parse().unwrap(),
            width: precursor.fields[3].parse().unwrap(),
            data: parse_text_blocks(&text),
        };

        document.elements.insert(hash.to_string(), element);
    }

    println!("document: {:#?}", document);

    document
}

// split("foobazbar", "baz") -> ("foo", "bar")
fn split<'a>(text: &'a str, delimiter: &str) -> Option<(&'a str, &'a str)> {
    let mut split = text.splitn(2, delimiter);
    let first = split.next()?;
    let second = split.next()?;
    Some((first, second))
}

fn split_or_end<'a>(text: &'a str, delimiter: &str) -> (&'a str, &'a str) {
    split(text, delimiter).unwrap_or((text, ""))
}



fn parse_text_blocks(mut text: &str) -> Vec<TextBlock> {
    let mut blocks: Vec<TextBlock> = Vec::new();

    // while there's still text to parse, try to parse a block. TextBlock parsing is LL(7), with
    // the longest substring needed being "^###### " (h6 header).

    while text.len() > 0 {

        // try to parse a header
        for level in 1..=6 {
            let header = format!("{} ", "#".repeat(level));
            if text.starts_with(&header) {
                let (header, rest) = split_or_end(text[level + 1..].trim_start(), "\n");
                let chunks = parse_text_chunks(header);
                blocks.push(TextBlock::Header { level: level as u8, chunks });
                text = rest;
                continue;
            }
        }

        // try to parse a code block
        if text.starts_with("```") && let Some((code, rest)) = split(text[3..].trim_start(), "```") {
            blocks.push(TextBlock::CodeBlock { code: code.to_string() });
            text = rest;
            continue;
        }

        // finish by parsing a either a paragraph or a vertical space
        if text.starts_with("\n") {
            blocks.push(TextBlock::VerticalSpace);
            text = &text[1..];
        } else {
            let (paragraph, rest) = split_or_end(text, "\n\n"); // TODO: ending immediately with a
                                                                // codeblock or header should be
                                                                // fine. Maybe go linewise and
                                                                // append to old instead.
            let chunks = parse_text_chunks(paragraph);
            blocks.push(TextBlock::Paragraph { chunks });
            text = rest;
        }
    }

    blocks
}

fn parse_text_chunks(text: &str) -> Vec<TextChunk> {
    // for now, just return a single chunk without any formatting
    vec![TextChunk {
        text: text.to_string(),
        style: TextStyle {
            bold: false,
            italic: false,
            underline: false,
            strikethrough: false,
        },
    }]
}

