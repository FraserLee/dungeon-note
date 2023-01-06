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

print("serving at http://localhost:3000")

# The text boxes that will be displayed on the webpage
textBlocks = {
        0: Text('Hello ' * 50, -300, 0, 600), 
        1: Text('World ' * 30, 100, 300, 300)
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

            case _: super().do_GET()

    def do_POST(self):
        if not self.path.startswith('/update/'): 
            return

        # update one of the textboxes. First grab the id:
        id = self.path.split('/')[2]

        # Then grab the data from the request
        length = int(self.headers['Content-Length'])
        data = json.loads(self.rfile.read(length))

        # Lastly update the textbox
        textBlocks[int(id)] = Text(data['text'], data['x'], data['y'], data['width'])

        # Send back an empty response
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(b'{}')


# Start the server, and quit when Ctrl+C is pressed
try:
    httpd = http.server.HTTPServer(('', 3000), MyHandler)
    httpd.serve_forever()
except KeyboardInterrupt:
    sys.exit(0)

