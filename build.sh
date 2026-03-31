#!/bin/bash
set -e
cd "$(dirname "$0")"

APP_NAME="Claude Clipboard Cleaner"
BUNDLE_ID="ClaudeClipboardCleaner"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

rm -rf "$BUILD_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

echo "🔨 Compiling..."
cat CleanLogic.swift ClaudeClipboardCleaner.swift > "$BUILD_DIR/main.swift"
swiftc -O \
    -target arm64-apple-macosx13.0 \
    -framework AppKit \
    -framework ServiceManagement \
    -o "$APP_BUNDLE/Contents/MacOS/$BUNDLE_ID" \
    "$BUILD_DIR/main.swift"

cp Info.plist "$APP_BUNDLE/Contents/"

# Icon (generate if missing)
if [ ! -f build/AppIcon.icns ]; then
    echo "🎨 Generating icon..."
    swiftc -O -target arm64-apple-macosx13.0 -framework AppKit \
        -o build/generate_icon scripts/generate_icon.swift
    ./build/generate_icon
fi
cp build/AppIcon.icns "$APP_BUNDLE/Contents/Resources/"

# Menubar icon (generate if missing)
if [ ! -f build/menubar_icon.png ]; then
    echo "🎨 Generating menubar icon..."
    swiftc -O -target arm64-apple-macosx13.0 -framework AppKit \
        -o build/generate_menubar scripts/generate_menubar_icon.swift
    ./build/generate_menubar
fi
cp build/menubar_icon.png "$APP_BUNDLE/Contents/Resources/"

echo "✅ Built: $APP_BUNDLE"
echo "   Run: open \"$APP_BUNDLE\""
