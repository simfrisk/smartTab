#!/bin/bash

# SmartTab Installation Script
# Builds and installs SmartTab to /Applications

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🔨 Building SmartTab..."
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

echo "📦 Installing to /Applications..."
echo ""

# Remove old version if it exists
if [ -d "/Applications/SmartTab.app" ]; then
    echo "⚠️  Removing existing installation..."
    rm -rf "/Applications/SmartTab.app"
fi

# Copy to Applications
cp -R "$BUILT_APP" /Applications/

echo "✅ SmartTab installed to /Applications!"
echo ""
echo "📋 Next steps:"
echo "   1. Open /Applications/SmartTab.app"
echo "   2. Grant Accessibility permissions when prompted"
echo "   3. Go to System Settings → Privacy & Security → Accessibility"
echo "   4. Enable SmartTab if it's not already enabled"
echo "   5. Restart the app"
echo ""
echo "🎉 Installation complete! Press ⌘` to open the launcher."

