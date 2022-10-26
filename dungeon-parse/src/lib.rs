



pub fn parse(input: String) -> String {
    const HTML: &str = r#"
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>Dungeon Note 3</title></head>
<body>
  <script type="module">

    import { h, Component, render } from 'https://unpkg.com/preact@latest?module';
    import { useState, useEffect, useCallback } from 'https://unpkg.com/preact@latest/hooks/dist/hooks.module.js?module';

    import htm from 'https://unpkg.com/htm?module';
    // Initialize htm with Preact
    const html = htm.bind(h);

    function App (props) {
      const [count, setCount] = useState(0);
      const increment = useCallback(() => {
        setCount(count + 1);
      }, [count]);
      return html`
      <div>
          <h1>Clicked ${count} times</h1>
          <button onClick=${increment}>Click me</button>
      </div>
      <br>
      `;

    }

    render(html`<${App} name="World" />`, document.body);
  </script>
</body>
</html>"#;
    return format!("{}{}", HTML, input[0..400].to_string());
}
