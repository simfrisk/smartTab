#!/bin/bash

# Build script for SmartTab macOS Launcher

echo "Building SmartTab..."

# Create build directory
mkdir -p build

# Compile Swift files
swiftc -o build/SmartTab \
    -target x86_64-apple-macosx12.0 \
    -import-objc-header \
    SmartTabApp.swift \
    LauncherManager.swift \
    LauncherView.swift \
    LauncherWindow.swift \
    -framework SwiftUI \
    -framework AppKit \
    -framework Combine

if [ $? -eq 0 ]; then
    echo "Build successful! Run with: ./build/SmartTab"
else
    echo "Build failed!"
    exit 1
fi

