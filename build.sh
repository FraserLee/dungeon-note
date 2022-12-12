#!/usr/bin/env bash
cd front || exit
elm make src/Main.elm --output=../build/index.html --optimize
