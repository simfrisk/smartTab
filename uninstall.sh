#!/bin/bash

# SmartTab Uninstall Script

echo "🗑️  Uninstalling SmartTab..."
echo ""

# Check if app is running and quit it
if pgrep -f "SmartTab" > /dev/null; then
    echo "⚠️  SmartTab is running. Quitting..."
    killall SmartTab 2>/dev/null || true
    sleep 1
fi

# Remove from Applications
if [ -d "/Applications/SmartTab.app" ]; then
    echo "📦 Removing SmartTab.app from /Applications..."
    rm -rf "/Applications/SmartTab.app"
    echo "✅ Removed from Applications"
else
    echo "ℹ️  SmartTab.app not found in /Applications"
fi

echo ""
echo "✅ Uninstall complete!"
echo ""
echo "📋 Manual cleanup (if needed):"
echo "   1. Remove from Login Items:"
echo "      System Settings → General → Login Items"
echo "      Remove SmartTab if it's listed"
echo ""
echo "   2. Remove Accessibility permission (optional):"
echo "      System Settings → Privacy & Security → Accessibility"
echo "      Remove SmartTab from the list"
echo ""

