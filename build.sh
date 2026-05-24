#!/bin/bash
set -e

cd "$(dirname "$0")"

APP="BlankSlate.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp Info.plist "$APP/Contents/Info.plist"
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

swiftc -O -o "$APP/Contents/MacOS/BlankSlate" BlankSlateApp.swift \
    -framework SwiftUI \
    -framework AppKit \
    -parse-as-library

echo "Built $APP"
echo "Run: open $APP"
