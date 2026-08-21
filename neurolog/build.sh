#!/bin/zsh
# Compile NeuroLog.app (menu-bar quick logger) into the directory given as $1.
set -eu
SRC="${0:A:h}"
DEST="${1:-$SRC}"
APP="$DEST/NeuroLog.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$SRC/Info.plist" "$APP/Contents/Info.plist"
cp "$SRC/MenuIcon.png" "$APP/Contents/Resources/MenuIcon.png"
swiftc -O "$SRC/main.swift" -o "$APP/Contents/MacOS/NeuroLog"
codesign --force --sign - "$APP" 2>/dev/null || true
echo "built $APP"
