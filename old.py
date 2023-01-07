#!/usr/bin/env python3

import os
import sys
import time
import json
import dataclasses
import http.server
from watchdog.events import FileSystemEventHandler
from watchdog.observers import Observer




# todo: turn this into the real thing.
def load_document(path):
    global document
    with open(path, 'r') as f:
        document = {0: Text(f.read(), -350, 30, 700)}

def save_document(path):
    global document
    with open(path, 'w') as f:
        f.write(document[0].text)



# ------------------------------ watch for changes -----------------------------


class TargetWatch(FileSystemEventHandler):
    # when the target file is modified, reload it into the document by calling
    # load_document, then send a websocket message to tell the client to reload.

    last_time = -1000

    @staticmethod
    def on_any_event(_):
        if time.time() - TargetWatch.last_time < 0.1: return # rudimentary debounce

        print('reloading document...', end='')
        load_document(file_path)
        # send_reload_command() ------------------------------------------------
        print('done')

        TargetWatch.last_time = time.time()

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


# watch for changes in the target file
target_event_handler = TargetWatch()
target_observer = Observer()
target_observer.schedule(target_event_handler, dir_path, recursive=True)
target_event_handler.on_any_event(None) # trigger an initial load of the document
target_observer.start()

# watch for changes in the development files if in debug mode
if debug_mode:
    self_event_handler = SelfWatch()
    self_observer = Observer()
    self_observer.schedule(self_event_handler, pwd, recursive=True)
    self_event_handler.on_any_event(None) # trigger an initial build
    self_observer.start()

