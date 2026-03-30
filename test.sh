#!/bin/bash
set -e
cd "$(dirname "$0")"

mkdir -p build

echo "🧪 Compiling tests..."
# Concatenate into single file (Swift only allows top-level code in one file)
cat CleanLogic.swift Tests/CleanerTests.swift > build/test_main.swift
swiftc -O \
    -target arm64-apple-macosx13.0 \
    -o build/test_runner \
    build/test_main.swift

echo "🧪 Running tests..."
echo ""
./build/test_runner
