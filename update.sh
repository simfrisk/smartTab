#!/bin/bash

# SmartTab Update Script
# Builds the latest version and updates the installed app

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🔄 Updating SmartTab..."
echo ""

# Check if app is running and quit it
if pgrep -f "SmartTab" > /dev/null; then
    echo "⚠️  SmartTab is running. Quitting..."
    killall SmartTab 2>/dev/null || true
    sleep 1
    echo "✅ App quit"
    echo ""
fi

echo "🔨 Building latest version..."
echo ""

# Build using xcodebuild
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
    -project SmartTab/SmartTab.xcodeproj \
    -scheme SmartTab \
    -configuration Release \
    -derivedDataPath ./build \
    -quiet

if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi

echo "✅ Build successful!"
echo ""

# Find the built app
BUILT_APP="./build/Build/Products/Release/SmartTab.app"

if [ ! -d "$BUILT_APP" ]; then
    echo "❌ Could not find built app at $BUILT_APP"
    exit 1
fi

# Check if app is already installed
if [ -d "/Applications/SmartTab.app" ]; then
    echo "📦 Updating existing installation..."
    rm -rf "/Applications/SmartTab.app"
else
    echo "📦 Installing to /Applications..."
fi

# Copy to Applications
cp -R "$BUILT_APP" /Applications/

echo "✅ SmartTab updated in /Applications!"
echo ""

# Ask if user wants to launch it
read -p "🚀 Launch SmartTab now? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open "/Applications/SmartTab.app"
    echo "✅ SmartTab launched!"
else
    echo "ℹ️  You can launch it manually from Applications or Spotlight"
fi

echo ""
echo "🎉 Update complete!"

