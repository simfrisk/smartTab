# Quick Start Guide

## Option 1: Using Xcode (Recommended - 2 minutes)

1. **Open Xcode** (press ⌘Space and type "Xcode")

2. **Create New Project**:
   - Click "Create a new Xcode project"
   - Select **macOS** tab
   - Choose **App** template
   - Click **Next**

3. **Configure Project**:
   - Product Name: `SmartTab`
   - Team: (your team or "None")
   - Organization Identifier: `com.yourname` (or anything)
   - Interface: **SwiftUI** ✅
   - Language: **Swift** ✅
   - Lifecycle: **SwiftUI App** ✅
   - Storage: None
   - Click **Next**

4. **Save Location**:
   - Navigate to: `/Users/simon/Documents/Pograming/smarttab`
   - **IMPORTANT**: Uncheck "Create Git repository" (or keep it if you want)
   - Click **Create**

5. **Add Files**:
   - In Xcode, you'll see `SmartTabApp.swift` and `ContentView.swift` in the file list
   - **Delete** `ContentView.swift` (right-click → Delete → Move to Trash)
   - **Delete** `App.swift` if it exists
   - **Drag and drop** these files from Finder into Xcode's file list:
     - `SmartTabApp.swift`
     - `LauncherManager.swift`
     - `LauncherView.swift`
     - `LauncherWindow.swift`
   - When prompted, make sure "Copy items if needed" is **checked**
   - Click **Finish**

6. **Build Settings**:
   - Click on "SmartTab" (blue icon) in the left sidebar
   - Under "Deployment Info", set **Minimum Deployments** to **macOS 12.0**

7. **Run**:
   - Press **⌘R** (or click the Play button)
   - The app will build and launch

8. **Grant Permissions**:
   - macOS will ask for Accessibility permissions
   - Go to **System Settings** → **Privacy & Security** → **Accessibility**
   - Find **SmartTab** and enable it
   - Restart the app

9. **Use It**:
   - Press **⌘`** (Command + backtick) to open the launcher
   - Press number keys (1-0) to switch tabs
   - Press letter keys to activate buttons

## Option 2: Command Line (Advanced)

If you have Xcode Command Line Tools installed:

```bash
# This might not work for SwiftUI apps, but you can try:
swift build
```

For SwiftUI apps, Xcode is really the best option.

## Troubleshooting

**Hotkey doesn't work?**
- Make sure Accessibility permissions are granted
- Restart the app after granting permissions
- Try pressing ⌘` when the app is in the foreground first

**Build errors?**
- Make sure all 4 Swift files are added to the project
- Check that deployment target is macOS 12.0 or later
- Clean build folder: Product → Clean Build Folder (⇧⌘K)

**App doesn't appear?**
- Check the menu bar for the app icon
- Look in Activity Monitor to see if it's running
- The app runs in the background (no dock icon by default)

