import http.server
import json
import sys
import dataclasses

# https://stackoverflow.com/a/51286749/7602154
class encoder(json.JSONEncoder):
    def default(self, o):
        if dataclasses.is_dataclass(o):
            return dataclasses.asdict(o)
        return super().default(o)

@dataclasses.dataclass
class Text:
    text   : str
    x      : float
    y      : float
    width  : float
    height : float

print("serving at http://localhost:3000")

# The counter that will be incremented by the webpage
counter = 0
# The text boxes that will be displayed on the webpage
textBlocks = {
        0: Text('Hello ' * 50, -300, 0, 600, 100), 
        1: Text('World ' * 30, 100, 300, 100, 100)
    }

# The handler for the webpage
class MyHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        match self.path:
            case '/':
                # Send the HTML code for the webpage
                self.send_response(200)
                self.send_header('Content-type', 'text/html')
                self.end_headers()
                # file located at index.html
                with open('build/index.html', 'rb') as f:
                    self.wfile.write(f.read())


            case '/fetch':
                # Send the textboxes
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps(textBlocks, cls=encoder).encode('utf-8'))

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

