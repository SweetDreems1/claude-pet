#!/bin/zsh
# Собирает Pixel Pet и ставит его в «Программы».
set -e
cd "$(dirname "$0")"
APP="Pixel Pet.app"
mkdir -p "$APP/Contents/MacOS"
swiftc -O -swift-version 5 main.swift WindowFinder.swift House.swift Recorder.swift Night.swift BadgeWatcher.swift \
  -o "$APP/Contents/MacOS/PixelPet"
codesign --force -s - "$APP"
pkill -x PixelPet || true
sleep 1
ditto "$APP" "/Applications/$APP"
open -g "/Applications/$APP"
echo "Pixel Pet собран и запущен."
