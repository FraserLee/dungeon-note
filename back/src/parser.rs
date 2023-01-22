use std::collections::hash_map::DefaultHasher;
use std::collections::HashMap;
use std::hash::{Hash, Hasher};
use std::time::SystemTime;

use serde::{Serialize, Deserialize};
use elm_rs::{Elm, ElmEncode, ElmDecode};

use regex::Regex;


// --------------------------- types shared with elm ---------------------------

#[derive(Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub struct Document {
    pub elements: HashMap<String, Element>,
    pub created: u64,
}
impl Document {
    pub fn new() -> Self { Self { 
        elements: HashMap::new(), 
        created: SystemTime::now().duration_since(SystemTime::UNIX_EPOCH).unwrap().as_secs() 
    } }
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
pub enum TextChunk {
    Text { text: String, style: TextStyle },
    Code { code: String },
    // Link { text: String, url: String },
    NewLine,
}

#[derive(Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub struct TextStyle {
    pub bold: bool,
    pub italic: bool,
    pub underline: bool,
    pub strikethrough: bool,
}

// ------

#[derive(Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub struct DocumentUpdate {
    pub id: String,
    pub element: Element,
    pub doc_created: u64,
}

// -----------------------------------------------------------------------------

#[derive(Hash, Debug)]
struct ElementPrecursor {
    startline: usize,
    endline: usize,
    fields: Vec<String>,
}

#[derive(Debug)]
enum TextBlockPrecursor<'a> {
    Header { level: u8, text: &'a str },
    CodeBlock { code: &'a str },
    SpacelessBreak, // added to separate paragraphs
    VerticalSpace, 
    Paragraph { text: String }, // this one is String instead of &str for concatenation. 
                                // Fix later, so we're just referencing indices into the original
                                // string without copying.
}

pub fn parse(text: &str) -> Document {
    let mut document = Document::new();

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

    document
}

// split("foobazbar", "baz") -> Some(("foo", "bar"))
fn split<'a>(text: &'a str, delimiter: &str) -> Option<(&'a str, &'a str)> {
    let mut split = text.splitn(2, delimiter);
    let first = split.next()?;
    let second = split.next()?;
    Some((first, second))
}

// split_or_end("foobazbar", "quux") -> ("foobazbar", "")
fn split_or_end<'a>(text: &'a str, delimiter: &str) -> (&'a str, &'a str) {
    split(text, delimiter).unwrap_or((text, ""))
}



fn parse_text_blocks(mut text: &str) -> Vec<TextBlock> {
    let mut blocks: Vec<TextBlockPrecursor> = Vec::new();

    // For as long as there's still text to parse, try to parse a block. 

    // I think TextBlock parsing is LL(7), with the longest substring needed being "^###### " (h6
    // header). Doesn't really matter given this model, but it's interesting to think about how
    // I'd do this with a more involved grammar.

    text = text.trim();

    while text.len() > 0 {

        // try to parse a header -----------------------------------------------

        for level in 1..=6 {
            let header = format!("{} ", "#".repeat(level));
            if text.starts_with(&header) {
                let (header, rest) = split_or_end(text[level + 1..].trim_start(), "\n");
                blocks.push(TextBlockPrecursor::Header { level: level as u8, text: header });
                text = rest;
                continue;
            }
        }

        // try to parse a code block -------------------------------------------

        if text.starts_with("```") && let Some((code, rest)) = split(text[3..].trim_start(), "```") {
            blocks.push(TextBlockPrecursor::CodeBlock { code: code.trim() });
            text = rest;
            continue;
        }

        // parse either a vertical space or a paragraph ------------------------

        if text.starts_with("\n") {
            text = &text[1..];
            blocks.push(TextBlockPrecursor::SpacelessBreak);
            while text.starts_with("\n") {
                text = &text[1..];
                blocks.push(TextBlockPrecursor::VerticalSpace);
            }
        } else {
            let (paragraph, rest) = split_or_end(text, "\n");

            // if the previous block was a paragraph, merge them. Otherwise, create a new one.

            if let Some(TextBlockPrecursor::Paragraph { text: prev_text }) = blocks.last_mut() {

                // note: this could be done without a copy if we instead track the indices into an
                // immutable text buffer inside of TextBlockPrecursor. Maybe do that later.

                *prev_text = format!("{} {}", prev_text, paragraph);

            } else {
                blocks.push(TextBlockPrecursor::Paragraph { text: paragraph.to_string() });
            }

            text = rest;
        }
    }

    // convert the precursors into TextBlocks, parsing their contents from a
    // soup-like homogenate of characters into a deliciously chunkier form
    blocks.into_iter().filter_map(|x| match x {
        TextBlockPrecursor::Paragraph { text } => Some(TextBlock::Paragraph { chunks: parse_text_chunks(&text) }),
        TextBlockPrecursor::Header { level, text } => Some(TextBlock::Header { level, chunks: parse_text_chunks(text) }),
        TextBlockPrecursor::CodeBlock { code } => Some(TextBlock::CodeBlock { code: code.to_string() }),
        TextBlockPrecursor::VerticalSpace => Some(TextBlock::VerticalSpace),
        TextBlockPrecursor::SpacelessBreak => None,
    }).collect()
}


fn parse_text_chunks(text: &str) -> Vec<TextChunk> {

    // Might be better to convert to a recursive model, instead of trying to do 
    // everything with a single loop.

    let mut chunks: Vec<TextChunk> = Vec::new();
    let mut state = 0u8;
    let mut index = 0;

    let bold    = 0b00000001;
    let italic  = 0b00000010;
    let under   = 0b00000100;
    let strike  = 0b00001000;

    // last two really probably shouldn't be bitmasks. 
    // The others are possibly overlapping state, these are more just "things
    // that can happen in a line"

    let code    = 0b00010000;
    let newline = 0b00100000;

    fn convert(state: u8) -> TextStyle {
        TextStyle {
            bold:          state & 0b00000001 != 0,
            italic:        state & 0b00000010 != 0,
            underline:     state & 0b00000100 != 0,
            strikethrough: state & 0b00001000 != 0,
        }
    }

    // regex that will match a single asterisk, only if there's not
    // a second asterisk right after it.

    // TODO: find out if it's harmful to call Regex::new each time we need this, if this should be
    // done once statically

    let italic_regex = Regex::new(r"(?:^|[^\*])(\*)(?:[^\*]|$)").unwrap();

    while index < text.len() {
        let bold_index = text[index..].find("**").map(|x| (x, bold));
        let under_index = text[index..].find("__").map(|x| (x, under));
        let strike_index = text[index..].find("~~").map(|x| (x, strike));
        let code_index = text[index..].find("`").map(|x| (x, code));
        let italic_index = italic_regex.captures(&text[index..]).map(|x| (x.get(1).unwrap().start(), italic));

        let newline_index = text[index..].find("<br>").map(|x| (x, newline));

        let mut min_index = None;
        let mut min_flag = 0;

        if state & code != 0 {

            // when inside an inline code block, we only care about exiting it. 
            // Otherwise, we check all flags to see what's next.

            if let Some((index, flag)) = code_index {
                min_index = Some(index);
                min_flag = flag;
            }

        } else {
            [bold_index, under_index, strike_index, code_index, italic_index, newline_index]
                .iter()
                .filter_map(|x| *x)
                .for_each(|(index, flag)| {
                    if min_index.map(|x| index < x).unwrap_or(true) {
                        min_index = Some(index);
                        min_flag = flag;
                    }
                });
        }

        if let Some(min_index) = min_index {
            if state & code != 0 {
                chunks.push(TextChunk::Code { code: text[index..index + min_index].to_string() });
                state &= !code;
            } else {
                chunks.push(TextChunk::Text {
                    text: text[index..index + min_index].to_string(),
                    style: convert(state),
                });

                if min_flag == newline { chunks.push(TextChunk::NewLine); } 
                else { state ^= min_flag; }
            }

            index += min_index + match min_flag {
                0b00000001 => 2, // bold
                0b00000010 => 1, // italic
                0b00000100 => 2, // underline
                0b00001000 => 2, // strikethrough
                0b00010000 => 1, // code
                0b00100000 => 4, // newline

                _ => panic!("invalid flag"),
            };
        } else {
            // when we don't see any upcoming flags, we'll just add the rest
            // as a single text chunk in the current style.
            chunks.push(TextChunk::Text {
                text: text[index..].to_string(),
                style: convert(state),
            });
            break;
        }
    }

    chunks
}
