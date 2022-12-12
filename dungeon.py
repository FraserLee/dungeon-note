# host a webpage on port 3000. The webpage will have a button that, when
# clicked, will send a request to the server to increment a counter.
# The server will then send back the new value of the counter, which will
# be displayed on the webpage.

import http.server
import json
import sys

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
    </script>
</head>
<body>
    <h1>Counter</h1>
    <p id="counter">0</p>
    <button onclick="increment()">Increment</button>
</body>
</html>
"""

# The counter that will be incremented by the webpage
counter = 0

# The handler for the webpage
class MyHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        # Serve the webpage
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        self.wfile.write(html.encode())

    def do_POST(self):
        # Increment the counter
        global counter
        counter += 1
        print('Counter:', counter)
        # Send the new value of the counter back to the webpage
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps({'counter': counter}).encode())

# Start the server, and quit when Ctrl+C is pressed
try:
    httpd = http.server.HTTPServer(('', 3000), MyHandler)
    httpd.serve_forever()
except KeyboardInterrupt:
    sys.exit(0)

