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

def build_elm(optimize = False):
    # create folder
    if not os.path.exists('build'): os.mkdir('build')

    # copy index.html
    os.system('cp html/index.html build/index.html')

    # build elm stuff
    os.chdir('elm')
    os.system('elm make src/Main.elm --output=../build/elm.js' + (' --optimize' if optimize else ''))
    os.chdir(pwd)


def build_rust(optimize = False):
    os.chdir('rust')
    os.system(f'cargo build {"--release" if optimize else ""}')
    os.chdir(pwd)

def build_shared():
    os.chdir('rust')
    os.system('cargo run -- --rebuild_shared_types')
    os.chdir(pwd)

def build_and_run_rust(optimize = False):
    os.chdir('rust')
    os.system(f'cargo run {"--release" if optimize else ""} -- "{file_path}" "{pwd}/build"')
    os.chdir(pwd)

def clean():
    os.system('rm -rf build')

# if we're either in debug mode, or there isn't an existing shared-types file, build it.
if debug_mode or not os.path.exists('elm/src/Bindings.elm'):
    build_shared()

# if we're either in debug more, or there isn't an existing build, build the front-end
if debug_mode or not os.path.exists('build/index.html'):
    clean()
    build_elm(not debug_mode)


# run
build_and_run_rust(not debug_mode)



