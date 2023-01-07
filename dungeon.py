#!/usr/bin/env python3

import os
import sys
import time
import dataclasses
import http.server

from watchdog.events import FileSystemEventHandler
from watchdog.observers import Observer
from hachiko.hachiko import AIOWatchdog, AIOEventHandler



# -------------------------------- document data -------------------------------


@dataclasses.dataclass
class Text:
    text   : str
    x      : float
    y      : float
    width  : float

# The text boxes that will be displayed on the webpage
document = {
        0: Text('Hello ' * 50, -300, 0, 600), 
        1: Text('World ' * 30, 100, 300, 300)
    }

# todo: turn this into the real thing.
def load_document(path):
    global document
    with open(path, 'r') as f:
        document = {0: Text(f.read(), -350, 30, 700)}

def save_document(path):
    global document
    with open(path, 'w') as f:
        f.write(document[0].text)



# ------------------------------------ setup -----------------------------------

args, flags = [], set()
for arg in sys.argv[1:]:
    if arg.startswith('-'):
        flags.add(arg.lstrip('-')[0])
    else:
        args.append(arg)


if len(args) != 1:
    print('usage: dungeon.py [--debug | -d] <file_path>')
    exit(1)

# file and directory to watch
file_path = os.path.abspath(sys.argv[-1])
dir_path = os.path.dirname(file_path)
debug_mode = 'd' in flags

# cd to the directory of this script
pwd = os.path.dirname(os.path.abspath(__file__))
os.chdir(pwd)

print(f'Watching {dir_path}\n- press ctrl+c to exit\n')

def build_frontend(optimize = False):
    # create folder
    if not os.path.exists('build'): os.mkdir('build')

    # copy index.html
    os.system('cp index.html build/index.html')

    # build elm stuff
    os.chdir('front')
    os.system('elm make src/Main.elm --output=../build/elm.js' + (' --optimize' if optimize else ''))

    # move back to place
    os.chdir(pwd)


def clean_frontend():
    os.system('rm -rf build')


# if not in debug mode and if there isn't an existing frontend build, build it.
if not debug_mode and not os.path.exists('build/index.html'):
    print('Building frontend...')
    build_frontend()

# ------------------------------ watch for changes -----------------------------


class TargetWatch(AIOEventHandler):
    # when the target file is modified, reload it into the document by calling
    # load_document, then send a websocket message to tell the client to reload.

    async def on_any_event(self, _):
        print('reloading document...', end='')
        load_document(file_path)
        # send reload command here
        print('done')

class SelfWatch(FileSystemEventHandler):

    last_time = -1000

    @staticmethod
    def on_any_event(_):
        if time.time() - SelfWatch.last_time < 0.1: return # rudimentary debounce

        print('rebuilding frontend...', end='')
        clean_frontend()
        build_frontend()
        print('done')

        SelfWatch.last_time = time.time()
        












class Handler(sse.Handler):
    @asyncio.coroutine
    def handle_request(self):
        while True:
            yield from asyncio.sleep(2)
            self.send('foo')
            yield from asyncio.sleep(2)
            self.send('bar', event='wakeup')

start_server = sse.serve(Handler, 'localhost', 8888)
asyncio.get_event_loop().run_until_complete(start_server)
asyncio.get_event_loop().run_forever()

















watch for changes in the target file
async def watch_target():
    async with websockets.connect("ws://localhost:443") as websocket:
        target_event_handler = TargetWatch()
        await target_event_handler.on_any_event(None) # trigger an initial load of the document
        watch = AIOWatchdog(dir_path, event_handler=target_event_handler, recursive=True)
        watch.start()
        while True:
            await asyncio.sleep(0.1)

asyncio.new_event_loop().run_until_complete(watch_target())

# watch for changes in the development files if in debug mode
if debug_mode:
    self_event_handler = SelfWatch()
    self_observer = Observer()
    self_observer.schedule(self_event_handler, pwd, recursive=True)
    self_event_handler.on_any_event(None) # trigger an initial build
    self_observer.start()

# --------------------------------- run server ---------------------------------

print("serving at http://localhost:3000")

# https://stackoverflow.com/a/51286749/7602154
class encoder(json.JSONEncoder):
    def default(self, o):
        if dataclasses.is_dataclass(o):
            return dataclasses.asdict(o)
        return super().default(o)


# The handler for the webpage
class MyHandler(http.server.SimpleHTTPRequestHandler):

    def log_message(self, *_): pass # disable logging

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
                self.wfile.write(json.dumps(document, cls=encoder).encode('utf-8'))

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
        document[int(id)] = Text(data['text'], data['x'], data['y'], data['width'])

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

