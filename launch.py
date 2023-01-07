#!/usr/bin/env python3

import os
import sys

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

def build(optimize = False):
    # create folder
    if not os.path.exists('build'): os.mkdir('build')

    # copy index.html
    os.system('cp index.html build/index.html')

    # build elm stuff
    os.chdir('front')
    os.system('elm make src/Main.elm --output=../build/elm.js' + (' --optimize' if optimize else ''))
    os.chdir(pwd)

    # build rust stuff
    os.chdir('back')
    os.system('cargo build' + (' --release' if optimize else ''))
    os.chdir(pwd)

def clean():
    os.system('rm -rf build')

# if we're either in debug more, or there isn't an existing build, build the project.
if debug_mode or not os.path.exists('build/index.html'):
    print('Building...')
    build()

# run the server
os.chdir('back')
os.system(f'cargo run -- "{file_path}"')
os.chdir(pwd)


