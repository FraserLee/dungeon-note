pub fn parse(input: String) -> String {
    const HTML_START: &str = r#"
    <!DOCTYPE html>
    <html lang="en">
        <head><title>Dungeon Note 3</title></head>
        <body>"#;
    const HTML_END: &str = r#"
        </body>
    </html>"#;
    return format!("{}{}{}", HTML_START, input, HTML_END);
}
