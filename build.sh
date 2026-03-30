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

echo "✅ Built: $APP_BUNDLE"
echo "   Run: open \"$APP_BUNDLE\""
