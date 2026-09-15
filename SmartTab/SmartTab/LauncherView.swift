import SwiftUI
import AppKit
import ApplicationServices
import CoreGraphics

// MARK: - Layers

enum AppLayer {
    case apps
    case shortcuts
}

// MARK: - Media Key Simulation

private let NX_KEYTYPE_SOUND_UP: UInt32 = 0
private let NX_KEYTYPE_SOUND_DOWN: UInt32 = 1
private let NX_KEYTYPE_MUTE: UInt32 = 7
private let NX_KEYTYPE_PLAY: UInt32 = 16
private let NX_KEYTYPE_NEXT: UInt32 = 17
private let NX_KEYTYPE_PREVIOUS: UInt32 = 18

enum MediaKeyType {
    case playPause, next, previous, volumeUp, volumeDown, mute

    var nxKeyCode: UInt32 {
        switch self {
        case .playPause: return NX_KEYTYPE_PLAY
        case .next: return NX_KEYTYPE_NEXT
        case .previous: return NX_KEYTYPE_PREVIOUS
        case .volumeUp: return NX_KEYTYPE_SOUND_UP
        case .volumeDown: return NX_KEYTYPE_SOUND_DOWN
        case .mute: return NX_KEYTYPE_MUTE
        }
    }

    var symbolName: String {
        switch self {
        case .playPause: return "playpause.fill"
        case .next: return "forward.fill"
        case .previous: return "backward.fill"
        case .volumeUp: return "speaker.wave.3.fill"
        case .volumeDown: return "speaker.wave.1.fill"
        case .mute: return "speaker.slash.fill"
        }
    }
}

// MARK: - Screen Capture

enum ScreenCaptureType {
    case region   // ⌘⇧4
    case toolbar  // ⌘⇧5

    var keyCode: CGKeyCode {
        switch self {
        case .region: return 21  // "4"
        case .toolbar: return 23 // "5"
        }
    }

    var symbolName: String {
        switch self {
        case .region: return "camera.viewfinder"
        case .toolbar: return "macwindow.on.rectangle"
        }
    }
}

/// Posts a real ⌘⇧-modified key press so macOS runs its own capture UI.
func sendKeyboardShortcut(keyCode: CGKeyCode, flags: CGEventFlags) {
    let source = CGEventSource(stateID: .hidSystemState)
    guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
          let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else { return }
    keyDown.flags = flags
    keyUp.flags = flags
    keyDown.post(tap: .cghidEventTap)
    keyUp.post(tap: .cghidEventTap)
}

/// Simulates a hardware media key press by posting the same system-defined
/// NSEvent macOS sends for F7-F12 / the Touch Bar media keys. This is the only
/// way to reach apps like Music or Spotify without an app-specific integration.
func sendMediaKeyEvent(_ keyCode: UInt32) {
    func post(down: Bool) {
        let flags = NSEvent.ModifierFlags(rawValue: down ? 0xa00 : 0xb00)
        let data1 = Int((keyCode << 16) | (down ? 0xa00 : 0xb00))
        guard let event = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: flags,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: data1,
            data2: -1
        ) else { return }
        event.cgEvent?.post(tap: .cghidEventTap)
    }
    post(down: true)
    post(down: false)
}

// MARK: - Shared keyboard grid (10-10-9, split down the middle)

struct KeyboardGridView: View {
    let buttons: [LauncherButton]
    let onActivate: (LauncherAction) -> Void

    var body: some View {
        VStack(spacing: 12) {
            row(start: 0)
            row(start: 10)
            row(start: 20)
        }
    }

    @ViewBuilder
    private func row(start: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(Array(buttons.dropFirst(start).prefix(5)), id: \.id) { button in
                Button(action: { onActivate(button.action) }) {
                    LauncherButtonView(button: button)
                }
                .buttonStyle(PlainButtonStyle())
            }
            Rectangle()
                .fill(Color(NSColor.windowBackgroundColor))
                .frame(width: 80) // Gap for split keyboard
            ForEach(Array(buttons.dropFirst(start + 5).prefix(5)), id: \.id) { button in
                Button(action: { onActivate(button.action) }) {
                    LauncherButtonView(button: button)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct LauncherView: View {
    @ObservedObject var launcherManager: LauncherManager
    @ObservedObject var configManager: ButtonConfigManager
    @State private var selectedTab = 0

    // Shortcuts layer: fixed set of buttons, not user-configurable.
    // Laid out on the same 10-10-9 keyboard grid as the apps layer, with
    // unused keys left blank so both layers look and feel identical.
    let shortcutButtons: [LauncherButton] = {
        let row1Keys = ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"]
        let row2Keys = ["A", "S", "D", "F", "G", "H", "J", "K", "L", ";"]
        let row3Keys = ["Z", "X", "C", "V", "B", "N", "M", ",", ".", "-"]

        let assignments: [String: (label: String, action: LauncherAction)] = [
            "E": ("Capture Area", .screenCapture(.region)),
            "R": ("Capture Tools", .screenCapture(.toolbar)),
            "S": ("Previous", .mediaKey(.previous)),
            "D": ("Play/Pause", .mediaKey(.playPause)),
            "F": ("Next", .mediaKey(.next)),
            "J": ("Volume -", .mediaKey(.volumeDown)),
            "K": ("Mute", .mediaKey(.mute)),
            "L": ("Volume +", .mediaKey(.volumeUp)),
        ]

        func makeRow(_ keys: [String]) -> [LauncherButton] {
            keys.map { key in
                if let assignment = assignments[key] {
                    return LauncherButton(key: key, label: assignment.label, action: assignment.action)
                }
                return LauncherButton(key: key, label: "", action: .none)
            }
        }

        return makeRow(row1Keys) + makeRow(row2Keys) + makeRow(row3Keys)
    }()

    // Flatten all buttons from all tabs into a single array
    var allButtons: [LauncherButton] {
        configManager.buttons.flatMap { tab in
            tab.map { config in
                LauncherButton(key: config.key, label: config.label, action: config.toLauncherAction())
            }
        }
    }
    
    // Keyboard layout: 10 columns for top row, 9 for middle, 7 for bottom
    let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Layer toggle bar
            HStack {
                Spacer()
                Button(action: {
                    launcherManager.currentLayer = (launcherManager.currentLayer == .apps) ? .shortcuts : .apps
                }) {
                    Text(launcherManager.currentLayer == .apps ? "🎛 Shortcuts (Tab)" : "⌨️ App Launcher (Tab)")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .background(Color(NSColor.windowBackgroundColor))

            // Button grid arranged in keyboard layout: 10-10-9.
            // Same grid for both layers - just a different button array.
            KeyboardGridView(buttons: launcherManager.currentLayer == .shortcuts ? shortcutButtons : allButtons) { action in
                executeAction(action, launcherManager: launcherManager)
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .cornerRadius(12)
        .shadow(radius: 20)
        .frame(width: 1190, height: 400) // Increased width for larger gap
        .background(
            KeyHandler(launcherManager: launcherManager, configManager: configManager, selectedTab: $selectedTab, shortcutButtons: shortcutButtons)
                .allowsHitTesting(false)
        )
        .focusable()
        .onAppear {
            // Ensure window can receive keyboard events
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if let window = NSApp.keyWindow {
                    window.makeFirstResponder(window.contentView)
                }
            }
        }
    }
    
    
    func executeAction(_ action: LauncherAction, launcherManager: LauncherManager) {
        print("executeAction called with: \(action)")
        switch action {
        case .none:
            print("Action is .none, doing nothing")
            break
        case .launchApp(let path):
            print("Launching app at: \(path)")
            let url = URL(fileURLWithPath: path)
            // Try simple open first
            let success = NSWorkspace.shared.open(url)
            if !success {
                print("Failed to open with simple method, trying openApplication")
                // Fallback to openApplication
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { (app, error) in
                    if let error = error {
                        print("Error launching app at \(path): \(error.localizedDescription)")
                    } else {
                        print("App launched successfully with openApplication")
                        if let app = app {
                            CursorMover.moveCursorToFrontmostWindow(of: app)
                        }
                    }
                }
            } else {
                print("App launched successfully with open")
                // Find the app that was just launched and move cursor to it
                if let appName = url.deletingPathExtension().lastPathComponent as String? {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        if let app = NSWorkspace.shared.runningApplications.first(where: {
                            $0.localizedName == appName || $0.bundleURL == url
                        }) {
                            CursorMover.moveCursorToFrontmostWindow(of: app)
                        }
                    }
                }
            }
            launcherManager.isVisible = false
        case .openFolder(let path):
            print("Opening folder at: \(path)")
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
            // Move cursor to Finder window
            CursorMover.moveCursorToFinderWindow()
            launcherManager.isVisible = false
        case .mediaKey(let type):
            print("Sending media key: \(type)")
            sendMediaKeyEvent(type.nxKeyCode)
            // Stay open and on this layer so repeated presses are easy
        case .screenCapture(let type):
            print("Starting screen capture: \(type)")
            // Close first, otherwise the launcher window lands in the capture
            launcherManager.isVisible = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                sendKeyboardShortcut(keyCode: type.keyCode, flags: [.maskCommand, .maskShift])
            }
        }
    }
}

struct KeyHandler: NSViewRepresentable {
    let launcherManager: LauncherManager
    let configManager: ButtonConfigManager
    @Binding var selectedTab: Int
    let shortcutButtons: [LauncherButton]

    func makeNSView(context: Context) -> KeyHandlingView {
        let view = KeyHandlingView()
        view.launcherManager = launcherManager
        view.configManager = configManager
        view.selectedTab = $selectedTab
        view.shortcutButtons = shortcutButtons
        return view
    }

    func updateNSView(_ nsView: KeyHandlingView, context: Context) {
        nsView.launcherManager = launcherManager
        nsView.configManager = configManager
        nsView.selectedTab = $selectedTab
        nsView.shortcutButtons = shortcutButtons
    }
}

class KeyHandlingView: NSView {
    var launcherManager: LauncherManager?
    var configManager: ButtonConfigManager?
    var selectedTab: Binding<Int>?
    var shortcutButtons: [LauncherButton] = []

    override var acceptsFirstResponder: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Don't intercept mouse events, let them pass through to buttons
        // Return nil so mouse clicks go to buttons, but we're still in responder chain for keyboard
        return nil
    }

    override var canBecomeKeyView: Bool { true }

    override func keyDown(with event: NSEvent) {
        print("KeyHandlingView: keyDown received - key: \(event.charactersIgnoringModifiers ?? ""), keyCode: \(event.keyCode)")

        guard let configManager = configManager else {
            print("KeyHandlingView: Missing configManager")
            return
        }

        // First check if this is the hotkey - if so, toggle the launcher
        if configManager.hotkeyConfig.matches(event: event) {
            print("KeyHandlingView: Hotkey detected, toggling launcher")
            // Ensure we update on main thread
            if Thread.isMainThread {
                launcherManager?.toggleLauncher()
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.launcherManager?.toggleLauncher()
                }
            }
            return
        } else if let secondaryConfig = configManager.secondaryHotkeyConfig,
                  secondaryConfig.matches(event: event) {
            print("KeyHandlingView: Secondary hotkey detected, toggling launcher")
            // Ensure we update on main thread
            if Thread.isMainThread {
                launcherManager?.toggleLauncher()
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.launcherManager?.toggleLauncher()
                }
            }
            return
        }
        
        // Tab toggles between the app launcher layer and the media controls layer
        if event.keyCode == 48 {
            print("KeyHandlingView: Tab pressed, switching layer")
            if Thread.isMainThread {
                toggleLayer()
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.toggleLayer()
                }
            }
            return
        }

        let key = event.charactersIgnoringModifiers?.uppercased() ?? ""
        print("KeyHandlingView: Processing key: '\(key)'")

        if launcherManager?.currentLayer == .shortcuts {
            // Handle shortcut button activation
            if let button = shortcutButtons.first(where: { $0.key.uppercased() == key.uppercased() }) {
                print("KeyHandlingView: Found shortcut button for key '\(key)': \(button.label)")
                executeAction(button.action)
            } else {
                print("KeyHandlingView: No shortcut button found for key '\(key)'")
            }
        } else {
            // Convert config buttons to launcher buttons (flatten all tabs)
            let allButtons = configManager.buttons.flatMap { tab in
                tab.map { config in
                    LauncherButton(key: config.key, label: config.label, action: config.toLauncherAction())
                }
            }

            // Handle button activation (search through all buttons)
            if let button = allButtons.first(where: { $0.key.uppercased() == key.uppercased() }) {
                print("KeyHandlingView: Found button for key '\(key)': \(button.label)")
                executeAction(button.action)
            } else {
                print("KeyHandlingView: No button found for key '\(key)'")
            }
        }

        // ESC to close
        if event.keyCode == 53 {
            print("KeyHandlingView: ESC pressed, closing launcher")
            // Ensure we update on main thread
            if Thread.isMainThread {
                launcherManager?.isVisible = false
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.launcherManager?.isVisible = false
                }
            }
        }
    }
    
    func toggleLayer() {
        guard let launcherManager = launcherManager else { return }
        launcherManager.currentLayer = (launcherManager.currentLayer == .apps) ? .shortcuts : .apps
    }

    func executeAction(_ action: LauncherAction) {
        switch action {
        case .none:
            break
        case .launchApp(let path):
            launchApplication(path: path)
        case .openFolder(let path):
            openFolder(path: path)
        case .mediaKey(let type):
            print("KeyHandlingView: Sending media key: \(type)")
            sendMediaKeyEvent(type.nxKeyCode)
            // Stay open and on this layer so repeated presses are easy
        case .screenCapture(let type):
            print("KeyHandlingView: Starting screen capture: \(type)")
            // Close first, otherwise the launcher window lands in the capture
            launcherManager?.isVisible = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                sendKeyboardShortcut(keyCode: type.keyCode, flags: [.maskCommand, .maskShift])
            }
        }
    }

    func launchApplication(path: String) {
        print("KeyHandlingView: Launching app at: \(path)")
        let url = URL(fileURLWithPath: path)
        // Try simple open first
        let success = NSWorkspace.shared.open(url)
        if !success {
            print("Failed to open with simple method, trying openApplication")
            // Fallback to openApplication
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { (app, error) in
                if let error = error {
                    print("Error launching app at \(path): \(error.localizedDescription)")
                } else {
                    print("App launched successfully with openApplication")
                    if let app = app {
                        CursorMover.moveCursorToFrontmostWindow(of: app)
                    }
                }
            }
        } else {
            print("App launched successfully with open")
            // Find the app that was just launched and move cursor to it
            if let appName = url.deletingPathExtension().lastPathComponent as String? {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    if let app = NSWorkspace.shared.runningApplications.first(where: {
                        $0.localizedName == appName || $0.bundleURL == url
                    }) {
                        CursorMover.moveCursorToFrontmostWindow(of: app)
                    }
                }
            }
        }
        launcherManager?.isVisible = false
    }

    func openFolder(path: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
        // Move cursor to Finder window
        CursorMover.moveCursorToFinderWindow()
        launcherManager?.isVisible = false
    }
    
}

struct LauncherButton: Identifiable {
    let id = UUID()
    let key: String
    let label: String
    var action: LauncherAction
}

enum LauncherAction {
    case none
    case launchApp(path: String)
    case openFolder(path: String)
    case mediaKey(MediaKeyType)
    case screenCapture(ScreenCaptureType)

    /// SF Symbol shown on the tile for actions that have no app icon
    var symbolName: String? {
        switch self {
        case .mediaKey(let type): return type.symbolName
        case .screenCapture(let type): return type.symbolName
        case .none, .launchApp, .openFolder: return nil
        }
    }
}

// MARK: - Cursor Movement Utility
class CursorMover {
    /// Moves the cursor to the center of the frontmost window of the specified application
    static func moveCursorToFrontmostWindow(of app: NSRunningApplication) {
        // Give the app a moment to fully activate and bring its window forward
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
                print("Failed to get window list")
                return
            }

            // Find the frontmost window of this app
            let targetPID = app.processIdentifier

            for window in windows {
                guard let pid = window[kCGWindowOwnerPID as String] as? pid_t,
                      pid == targetPID,
                      let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
                      let x = bounds["X"],
                      let y = bounds["Y"],
                      let width = bounds["Width"],
                      let height = bounds["Height"],
                      let layer = window[kCGWindowLayer as String] as? Int,
                      layer == 0 else { // Layer 0 is normal window layer
                    continue
                }

                // Calculate center point
                let centerX = x + width / 2
                let centerY = y + height / 2

                print("Moving cursor to window center: (\(centerX), \(centerY))")

                // Move cursor to center of window
                let point = CGPoint(x: centerX, y: centerY)
                CGWarpMouseCursorPosition(point)

                // Only move to the first (frontmost) window
                return
            }

            print("No suitable window found for app \(app.localizedName ?? "unknown")")
        }
    }

    /// Moves the cursor to the center of the Finder window showing the specified folder
    static func moveCursorToFinderWindow() {
        // Find Finder process
        let workspace = NSWorkspace.shared
        guard let finder = workspace.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.finder" }) else {
            print("Finder not found")
            return
        }

        moveCursorToFrontmostWindow(of: finder)
    }
}

struct LauncherButtonView: View {
    let button: LauncherButton
    @State private var isHovered = false
    @State private var appIcon: NSImage?
    
    // Check if this is a home row key (F or J)
    private var isHomeRowKey: Bool {
        button.key.uppercased() == "F" || button.key.uppercased() == "J"
    }
    
    // Background color based on key type and hover state
    private var backgroundColor: Color {
        if isHovered {
            return Color.accentColor.opacity(0.2)
        } else if isHomeRowKey {
            return Color.yellow.opacity(0.08)
        } else {
            return Color(NSColor.controlBackgroundColor)
        }
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Main content - icon or letter
            VStack(spacing: 2) {
                if let icon = appIcon {
                    // Large app icon
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 70, height: 70)
                } else if let symbolName = button.action.symbolName {
                    // System action icon (media controls, screen capture)
                    Image(systemName: symbolName)
                        .font(.system(size: 38, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 70, height: 70)
                } else if case .none = button.action {
                    // Blank space when nothing is assigned
                    Spacer().frame(width: 70, height: 70)
                } else {
                    // Large letter when no icon but action is assigned
                    Text(button.key)
                        .font(.system(size: 40, weight: .bold))
                }
                
                // Label at bottom (only show if action is not .none)
                if case .none = button.action {
                    // Blank space for unassigned buttons
                    Spacer().frame(height: 14)
                } else {
                    Text(button.label)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(width: 100, height: 100)
            .padding(.top, 4)
            
            // Key letter in top-left corner (always visible)
            Text(button.key)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .padding(4)
                .background(
                    Circle()
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
                )
                .padding(2)
        }
        .background(backgroundColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear {
            loadAppIcon()
        }
    }
    
    func loadAppIcon() {
        // Extract app path from action
        switch button.action {
        case .launchApp(let path):
            // Check if file exists before getting icon
            if FileManager.default.fileExists(atPath: path) {
                appIcon = NSWorkspace.shared.icon(forFile: path)
            }
        default:
            break
        }
    }
}

