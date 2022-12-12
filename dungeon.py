import http.server
import json
import sys
import dataclasses

@dataclasses.dataclass
class Text:
    text   : str
    x      : int
    y      : int
    width  : int
    height : int

# The Html and Javascript code for the webpage that will be served
html = """
<!DOCTYPE html>
<html>
<head>
    <title>Counter</title>
    <script>
        function increment() {
            // Send a request to the server to increment the counter
            fetch('/increment', {method: 'POST'})
            .then(response => response.json())
            .then(data => {
                // Update the counter on the webpage
                document.getElementById('counter').innerHTML = data.counter;
            });
        }

        function refreshTextBoxes() {
            fetch('/text', {method: 'GET'})
            .then(response => response.json())
            .then(data => {
                // Create a bunch of <p> elements with each text box
                let textRoot = document.getElementById('text');

                // clear existing text boxes
                textRoot.innerHTML = '';
                for (let i = 0; i < data.text.length; i++) {
                    let text = data.text[i];
                    let p = document.createElement('p');
                    p.innerHTML = text.text;
                    textRoot.appendChild(p);
                }
            });
        }

        // after the page loads, call refreshTextBoxes() to get the initial setup
        window.onload = refreshTextBoxes;

    </script>
</head>
<body>
    <h1>Counter</h1>
    <p id="counter">0</p>
    <button onclick="increment()">Increment</button>
    <h1>Text</h1>
    <div id="text"></div>
</body>
</html>
"""

print("serving at http://localhost:3000")

# The counter that will be incremented by the webpage
counter = 0
# The text boxes that will be displayed on the webpage
text = [Text('Hello', 0, 0, 100, 100), Text('World', 100, 100, 100, 100)]

# The handler for the webpage
class MyHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        match self.path:
            case '/':
                # Send the HTML code for the webpage
                self.send_response(200)
                self.send_header('Content-type', 'text/html')
                self.end_headers()
                self.wfile.write(html.encode())

            case '/text':
                # Send the textboxes
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({'text': [dataclasses.asdict(t) for t in text]}).encode())

    def do_POST(self):
        match self.path:
            case '/increment':
                # Increment the counter
                global counter
                counter += 1
                print('Counter:', counter)
                # Send the new value back to the webpage
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({'counter': counter}).encode())

            case _:
                # Send an error message back to the webpage
                self.send_response(404)
                self.send_header('Content-type', 'text/plain')
                self.end_headers()
                self.wfile.write('Not found'.encode())

# Start the server, and quit when Ctrl+C is pressed
try:
    httpd = http.server.HTTPServer(('', 3000), MyHandler)
    httpd.serve_forever()
except KeyboardInterrupt:
    sys.exit(0)

