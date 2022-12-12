#!/usr/bin/env bash
cd front || exit
# elm make src/Main.elm --output=../build/index.html --optimize
elm make src/Main.elm --output=../build/index.html
