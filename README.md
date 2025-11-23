# SmartTab - Mac Launcher

A fast and simple tabbed launcher for macOS, inspired by MaxLauncher.

## Features

- **Hotkey Activation**: Press `CMD+` (backtick) to show/hide the launcher
- **Tabbed Interface**: Switch between tabs using number keys (1-0)
- **Keyboard Navigation**: Press any key to activate the corresponding button
- **Quick Launch**: Launch applications and open Finder windows with just a few keystrokes
- **Beautiful UI**: Modern SwiftUI interface with smooth animations

## Building

### Using Xcode (Recommended)

1. Open Xcode
2. Create a new macOS App project:
   - Choose "App" template
   - Language: Swift
   - Interface: SwiftUI
   - Lifecycle: SwiftUI App
3. Delete the default `ContentView.swift` and `App.swift` files
4. Add all the Swift files from this directory to your project:
   - `SmartTabApp.swift`
   - `LauncherManager.swift`
   - `LauncherView.swift`
   - `LauncherWindow.swift`
5. In Project Settings:
   - Set deployment target to macOS 12.0 or later
   - Under "Signing & Capabilities", ensure the app is signed
6. Build and run (⌘R)

### Hotkey Permissions

SmartTab now registers its global shortcut through the system hotkey API, so the launcher can be toggled even while the app is unfocused without granting Accessibility permissions in most cases.

If you pick a shortcut that macOS refuses to register (for example, if another app already uses it), SmartTab will fall back to the older Accessibility-based event tap. When that happens, you'll see a warning in the log and you should:

1. Go to **System Preferences** → **Security & Privacy** → **Privacy** → **Accessibility**
2. Add SmartTab to the list and enable it
3. Restart the app if it's already running

## Usage

1. Launch the app (it will run in the background as a menu bar app)
2. Press `CMD+` (Command + backtick) to open the launcher
3. Press number keys (1-0) to switch between tabs
4. Press letter keys to activate buttons and launch apps/open folders
5. Press ESC to close the launcher
6. Click outside the window to close it

## UI Structure

- **Tabs**: Up to 10 tabs (numbered 1-0) at the top
- **Buttons**: Each tab contains buttons mapped to keyboard keys (Q-P, A-L, Z-M, etc.)
- **Layout**: 5-column grid of buttons
- **Styling**: Modern design with hover effects and accent colors

## Example Actions

The launcher comes with some pre-configured actions:
- **Q**: Open Home folder
- **T**: Launch Terminal
- **U**: Open Utilities folder
- **P**: Open System Preferences
- **A**: Open Applications folder
- **S**: Launch Safari
- **D**: Open Downloads folder
- **F**: Launch Finder
- **H**: Open Home folder
- **C**: Launch Calculator
- **N**: Launch Notes
- **M**: Launch Mail

## Customization

Edit `LauncherView.swift` to customize:
- Button labels and actions (in the `buttons` array)
- Number of tabs
- Button layout (modify the `columns` array)
- Colors and styling (modify `LauncherButtonView`)

### Adding Your Own Actions

To add a custom action, modify the button in the `buttons` array:

```swift
LauncherButton(key: "Q", label: "My App", action: .launchApp(path: "/Applications/MyApp.app"))
```

Or to open a folder:
```swift
LauncherButton(key: "D", label: "Documents", action: .openFolder(path: NSHomeDirectory() + "/Documents"))
```

## Files

- `SmartTabApp.swift` - Main app entry point
- `LauncherManager.swift` - Manages global hotkey and window visibility
- `LauncherView.swift` - Main UI with tabs and buttons
- `LauncherWindow.swift` - Window controller and keyboard handling

