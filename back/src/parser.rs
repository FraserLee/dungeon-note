use std::collections::hash_map::DefaultHasher;
use std::collections::HashMap;
use std::hash::{Hash, Hasher};
use std::time::SystemTime;

use lazy_static::lazy_static;

use elm_rs::{Elm, ElmDecode, ElmEncode};
use serde::{Deserialize, Serialize};

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
            created: SystemTime::now()
                .duration_since(SystemTime::UNIX_EPOCH)
                .unwrap()
                .as_secs(),
    } }
}

#[derive(Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub enum Element {
    TextBox { x: f64, y: f64, width: f64, data: Vec<TextBlock>, },
    Rect    { x: f64, y: f64, width: f64, height: f64, z: f64, color: String, },
    Line    { x1: f64, y1: f64, x2: f64, y2: f64, },
}

#[derive(Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub enum TextBlock {
    Paragraph { chunks: Vec<TextChunk> },
    Header { level: u8, chunks: Vec<TextChunk> },
    CodeBlock { code: String },
    UnorderedList { items: Vec<TextBlock> },
    OrderedList { items: Vec<TextBlock> },
    VerticalSpace,
    HorizontalRule,
}

#[derive(Debug, Serialize, Deserialize, Elm, ElmEncode, ElmDecode)]
pub enum TextChunk {
    Link { title: Vec<TextChunk>, url: String },
    Code { text: String },
    Bold { chunks: Vec<TextChunk> },
    Italic { chunks: Vec<TextChunk> },
    Underline { chunks: Vec<TextChunk> },
    Strikethrough { chunks: Vec<TextChunk> },
    Text(String),
    NewLine,
}

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
    UnorderedList { items: Vec<TextBlockPrecursor<'a>> },
    OrderedList { items: Vec<TextBlockPrecursor<'a>> },
    SpacelessBreak, // added to separate paragraphs
    VerticalSpace,
    HorizontalRule,
    Paragraph { text: String }, // this one is String instead of &str for concatenation.
                                // Fix later, so we're just referencing indices into the original
                                // string without copying.
}

// ----------------------------- regex definitions -----------------------------

lazy_static! {
    // a element header will look like this:
    // !!!!Text!x:370.0!y:150.0!width:300.0!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    static ref ELEMENT_HEADER_REGEX: Regex = Regex::new(r"^!!(?:!+)(Text)!x:(-?\d+(?:\.\d)?)!y:(-?\d+(?:\.\d)?)!width:(-?\d+(?:\.\d)?)!!!").unwrap();

    // matches numbers, but also some simple roman numerals. The choice of
    // which you use doesn't actually effect the output (yet, look into this)
    static ref ORDERED_LIST_REGEX: Regex = Regex::new(r"^(?:\s*)((?:[ivx]+|\d+)\.\s+)").unwrap();

    static ref UNORDERED_LIST_REGEX: Regex = Regex::new(r"^(?:\s*)([*+-]\s+)").unwrap();

    // For italics, I have a regex that will match a single asterisk, only if
    // there's not a second asterisk right after it.
    static ref ITALIC_REGEX: Regex = Regex::new(r"(?:^|[^\*])(\*)(?:[^\*]|$)").unwrap();

}

// -----------------------------------------------------------------------------

pub fn parse(text: &str) -> Document {
    let mut document = Document::new();

    // TODO: grab parameters in any order
    // TODO: when missing, parse parameters to a default value

    // first pass: scan through and mark out the boundaries of each element, and save all metadata info
    let mut element_precursors: Vec<ElementPrecursor> = Vec::new();

    for (i, line) in text.lines().enumerate() {
        if let Some(caps) = ELEMENT_HEADER_REGEX.captures(line) {

            let l = element_precursors.len();

            if l > 0 {
                element_precursors[l - 1].endline = i - 1;
            }

            let fields = caps.iter()
                .skip(1)
                .map(|x| x.unwrap().as_str().to_string())
                .collect();

            let precursor = ElementPrecursor { fields, startline: i, endline: i, };

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




// I tried to turn this into a trait, but stuff is weird with lifetimes.
fn trim_start_no_newline(text: &str) -> &str {
    text.trim_start_matches(|c: char| c.is_whitespace() && c != '\n')
}

// Tabs counted as 4 spaces.
fn count_indent(text: &str) -> usize {
    let mut count = 0;
    for c in text.chars() {
        match c {
            '\t' => count += 4,
            ' ' => count += 1,
            _ => break,
        }
    }
    count
}

#[test]
fn split_scope_test() {
    let text = r#"header
        line 1
            line 2
        line 3
    line 4"#;

    let (first, second) = split_scope(text, 8, false);

    assert_eq!(first, "header\n        line 1\n            line 2\n        line 3\n");
    assert_eq!(second, "    line 4");
}


// Takes a string and an indent level, splits at the first line less indented than the indent
// level. Set test_first_line to true if you want the possibility of the first line being rejected
// outright, returning ("" , text).
fn split_scope<'a>(text: &'a str, indent: usize, test_first_line: bool) -> (&'a str, &'a str) {
    let mut index = 0;
    for (i, line) in text.lines().enumerate() {
        if (i != 0 || test_first_line) && count_indent(line) < indent { break; }
        index += line.len() + 1;
    }
    if index < text.len() { (&text[..index], &text[index..]) } 
    else { (text, "") }
}



fn parse_text_blocks(text: &str) -> Vec<TextBlock> {
    // convert the precursors into TextBlocks, parsing their contents from a
    // soup-like homogenate of characters into a deliciously chunkier form
    fn convert_precursor(x: TextBlockPrecursor) -> Option<TextBlock> {
        match x {
            TextBlockPrecursor::Paragraph { text } => Some(TextBlock::Paragraph { chunks: chunk_text(&text) }),
            TextBlockPrecursor::Header { level, text } => Some(TextBlock::Header { level, chunks: chunk_text(text) }),
            TextBlockPrecursor::CodeBlock { code } => Some(TextBlock::CodeBlock { code: code.to_string() }),
            TextBlockPrecursor::UnorderedList { items } => Some(TextBlock::UnorderedList { items: items.into_iter().filter_map(|x| convert_precursor(x)).collect() }),
            TextBlockPrecursor::OrderedList { items } => Some(TextBlock::OrderedList { items: items.into_iter().filter_map(|x| convert_precursor(x)).collect() }),
            TextBlockPrecursor::VerticalSpace => Some(TextBlock::VerticalSpace),
            TextBlockPrecursor::HorizontalRule => Some(TextBlock::HorizontalRule),
            TextBlockPrecursor::SpacelessBreak => None,
        }
    }

    parse_text_block_precursors(text).into_iter().filter_map(|x| convert_precursor(x)).collect()
}


fn parse_text_block_precursors(mut text: &str) -> Vec<TextBlockPrecursor> {
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
                blocks.push(TextBlockPrecursor::Header {
                    level: level as u8,
                    text: header,
                });
                text = rest;
                continue;
            }
        }

        // try to parse a code block -------------------------------------------

        if text.starts_with("```") && let Some((code, rest)) = split(text[3..].trim_start(), "```") {

            blocks.push(TextBlockPrecursor::CodeBlock { code: code.trim() });

            // skip forwards to the start of "code code code```[ \t]*\nHERE"
            text = trim_start_no_newline(rest);
            text = &text[1.min(text.len())..];

            continue;
        }

        // try to parse an <hr> ------------------------------------------------

        if text.starts_with("---") {
            blocks.push(TextBlockPrecursor::HorizontalRule);
            text = trim_start_no_newline(text.trim_start_matches('-'));
            text = &text[1.min(text.len())..];
            continue;
        }
        
        // try to parse an unordered list --------------------------------------

        let mut list_items: Vec<&str> = Vec::new();
        while let Some(captures) = UNORDERED_LIST_REGEX.captures(text) {
            let indent_level = count_indent(text) + captures[1].len();
            let (item_text, rest) = split_scope(text, indent_level, false);
            list_items.push(&item_text[captures[0].len()..]);
            text = rest;
        }

        if list_items.len() > 0 { 
            blocks.push( TextBlockPrecursor::UnorderedList {
                items: list_items
                        .into_iter()
                        .flat_map(|s| parse_text_block_precursors(s))
                        .collect()
            } );
            continue;
        }

        // try to parse an ordered list ----------------------------------------

        let mut list_items: Vec<&str> = Vec::new();
        while let Some(captures) = ORDERED_LIST_REGEX.captures(text) {
            let indent_level = count_indent(text) + captures[1].len();
            let (item_text, rest) = split_scope(text, indent_level, false);
            list_items.push(&item_text[captures[0].len()..]);
            text = rest;
        }

        if list_items.len() > 0 { 
            blocks.push( TextBlockPrecursor::OrderedList {
                items: list_items
                        .into_iter()
                        .flat_map(|s| parse_text_block_precursors(s))
                        .collect()
            } );
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
                blocks.push(TextBlockPrecursor::Paragraph {
                    text: paragraph.to_string(),
                });
            }

            text = rest;
        }
    }

    blocks
}





fn chunk_text(text: &str) -> Vec<TextChunk> { chunk_links(text) }


// "foo [bar](baz) quux" -> ["foo ", ("bar", "baz"), " quux"]
fn split_link(text: &str) -> Option<(&str, (&str, &str), &str)> {
    let mut split = text.splitn(2, "[");
    let before = split.next()?;
    let mut split = split.next()?.splitn(2, "](");
    let link_text = split.next()?;
    let mut split = split.next()?.splitn(2, ")");
    let link_url = split.next()?;
    let after = split.next()?;
    Some((before, (link_text, link_url), after))
}

// this calls the next function in the chain on all text it outputs, as do all
// similar style ones. Might consider converting this to a HOF type thing
// (or the defunctionalized equivalent if that's not possible in Rust).

fn chunk_links(mut text: &str) -> Vec<TextChunk> {
    let mut chunks: Vec<TextChunk> = Vec::new();

    while let Some((before, (link_text, link_url), after)) = split_link(text) {
        chunks.extend(chunk_breaks(before));
        chunks.push(TextChunk::Link {
            title: chunk_breaks(link_text),
            url: link_url.to_string(),
        });
        text = after;
    }

    chunks.extend(chunk_breaks(text));

    chunks
}

// "foo<br>bar" -> ["foo", "bar"]
fn split_break(text: &str) -> Option<(&str, &str)> {
    let mut split = text.splitn(2, "<br>");
    Some((split.next()?, split.next()?))
}

fn chunk_breaks(mut text: &str) -> Vec<TextChunk> {
    let mut chunks: Vec<TextChunk> = Vec::new();

    while let Some((before, after)) = split_break(text) {
        chunks.extend(chunk_code(before));
        chunks.push(TextChunk::NewLine);
        text = after;
    }

    chunks.extend(chunk_code(text));

    chunks
}

// "foo `bar` baz" -> ["foo ", "bar", " baz"]
fn split_code(text: &str) -> Option<(&str, &str, &str)> {
    let mut split = text.splitn(2, "`");
    let before = split.next()?;
    let mut split = split.next()?.splitn(2, "`");
    let code = split.next()?;
    let after = split.next()?;
    Some((before, code, after))
}

fn chunk_code(mut text: &str) -> Vec<TextChunk> {
    let mut chunks: Vec<TextChunk> = Vec::new();

    while let Some((before, code, after)) = split_code(text) {
        chunks.extend(chunk_style(before));
        chunks.push(TextChunk::Code {
            text: code.to_string(),
        });
        text = after;
    }

    chunks.extend(chunk_style(text));

    chunks
}

// last bunch of styles don't have a precedence ordering, so I'm ending the
// chain in this single recursive function that'll parse all four of em.

fn chunk_style(text: &str) -> Vec<TextChunk> {

    enum Style { Bold, Italic, Strike, Under }

    // you could definitely do this faster by traversing forwards once with a
    // state machine, instead of scanning with all 4 and choosing the minimum.
    // Maybe change to that later.
    let bold_index = |text: &str| text.find("**").map(|x| (x, Style::Bold));
    let under_index = |text: &str| text.find("__").map(|x| (x, Style::Under));
    let strike_index = |text: &str| text.find("~~").map(|x| (x, Style::Strike));
    let italic_index = |text: &str| { ITALIC_REGEX.captures(&text).map(
            |x| (x.get(1).unwrap().start(), Style::Italic)
    ) };

    // grab the soonest starting style, and recurse on the text before, after, and inside of it.
    if let Some((min_index, min_style)) = [bold_index(text), under_index(text), strike_index(text), italic_index(text)]
                                          .into_iter()
                                          .filter_map(|x| x)
                                          .min_by_key(|x| x.0) {

        // index of where the style ends.
        let end_index = match min_style {
            Style::Bold => bold_index(&text[min_index + 2..]).map(|x| x.0 + min_index + 2),
            Style::Under => under_index(&text[min_index + 2..]).map(|x| x.0 + min_index + 2),
            Style::Strike => strike_index(&text[min_index + 2..]).map(|x| x.0 + min_index + 2),
            Style::Italic => italic_index(&text[min_index + 1..]).map(|x| x.0 + min_index + 1),
        };

        let mut chunks = chunk_style(&text[..min_index]); // THIS**......**....

        if let Some(end_index) = end_index {
            chunks.push(match min_style { // .....**THIS**......
                Style::Bold => TextChunk::Bold { chunks: chunk_style(&text[min_index + 2..end_index]) },
                Style::Italic => TextChunk::Italic { chunks: chunk_style(&text[min_index + 1..end_index]) },
                Style::Under => TextChunk::Underline { chunks: chunk_style(&text[min_index + 2..end_index]) },
                Style::Strike => TextChunk::Strikethrough { chunks: chunk_style(&text[min_index + 2..end_index]) },
            });
            chunks.extend( //.....**......**THIS
                chunk_style(&text[end_index + match min_style {
                        Style::Bold | Style::Under | Style::Strike => 2,
                        Style::Italic => 1,
                }..])
            );
        } else {
            chunks.extend(chunk_style(&text[min_index..])); // .....**THIS (no closing tag)
        }

        chunks
    } else {
        vec![TextChunk::Text(text.to_string())]
    }
}
