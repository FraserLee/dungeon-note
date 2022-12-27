#!/usr/bin/env bash
cd front || exit

elm make src/Main.elm --output=../build/elm.js
cp ../index.html ../build/index.html
