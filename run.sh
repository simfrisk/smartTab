#!/bin/bash

# Quick run script for SmartTab
# This creates a minimal Xcode project and runs it

echo "Creating Xcode project..."

# Create project directory structure
mkdir -p SmartTab.xcodeproj

# Create project.pbxproj file (simplified)
cat > SmartTab.xcodeproj/project.pbxproj << 'EOF'
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 56;
	objects = {
		/* Begin PBXBuildFile section */
		/* End PBXBuildFile section */
		/* Begin PBXFileReference section */
		/* End PBXFileReference section */
		/* Begin PBXGroup section */
		/* End PBXGroup section */
		/* Begin PBXNativeTarget section */
		/* End PBXNativeTarget section */
		/* Begin PBXProject section */
		/* End PBXProject section */
		/* Begin XCBuildConfiguration section */
		/* End XCBuildConfiguration section */
		/* Begin XCConfigurationList section */
		/* End XCConfigurationList section */
	};
	rootObject = /* Project object */;
}
EOF

echo ""
echo "=========================================="
echo "To run SmartTab, please use Xcode:"
echo ""
echo "1. Open Xcode"
echo "2. Choose 'File' > 'New' > 'Project'"
echo "3. Select 'macOS' > 'App'"
echo "4. Fill in:"
echo "   - Product Name: SmartTab"
echo "   - Interface: SwiftUI"
echo "   - Language: Swift"
echo "   - Lifecycle: SwiftUI App"
echo "5. Save in: $(pwd)"
echo "6. Delete the default ContentView.swift and App.swift files"
echo "7. Drag all .swift files into the project"
echo "8. Press ⌘R to build and run"
echo ""
echo "OR use the quick method below:"
echo "=========================================="
echo ""

# Try to compile directly with swiftc (may not work for SwiftUI apps)
echo "Attempting direct compilation..."
swiftc -o SmartTab \
    SmartTabApp.swift \
    LauncherManager.swift \
    LauncherView.swift \
    LauncherWindow.swift \
    -sdk $(xcrun --show-sdk-path --sdk macosx) \
    -target arm64-apple-macosx12.0 \
    -framework SwiftUI \
    -framework AppKit \
    -framework Combine 2>&1

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Build successful!"
    echo "Run with: ./SmartTab"
    echo ""
    echo "Note: Hotkeys normally work without Accessibility permissions."
    echo "If macOS can't register your shortcut, enable Accessibility and retry."
else
    echo ""
    echo "❌ Direct compilation failed (SwiftUI apps need Xcode project)"
    echo "Please use the Xcode method above instead."
fi

