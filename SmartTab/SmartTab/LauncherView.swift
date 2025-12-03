import SwiftUI
import AppKit
import ApplicationServices

struct LauncherView: View {
    @ObservedObject var launcherManager: LauncherManager
    @ObservedObject var configManager: ButtonConfigManager
    @State private var selectedTab = 0
    
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
            // Button grid arranged in keyboard layout: 10-10-9
            VStack(spacing: 12) {
                // Row 1: Q-P (10 buttons) - gap between T and Y
                HStack(spacing: 8) {
                    ForEach(Array(allButtons.prefix(5).enumerated()), id: \.element.id) { index, button in
                        Button(action: {
                            executeAction(button.action, launcherManager: launcherManager)
                        }) {
                            LauncherButtonView(button: button)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    Spacer().frame(width: 24) // Gap for split keyboard
                    ForEach(Array(allButtons.dropFirst(5).prefix(5)), id: \.id) { button in
                        Button(action: {
                            executeAction(button.action, launcherManager: launcherManager)
                        }) {
                            LauncherButtonView(button: button)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                // Row 2: A-L, ; (10 buttons) - gap between G and H
                HStack(spacing: 8) {
                    ForEach(Array(allButtons.dropFirst(10).prefix(5).enumerated()), id: \.element.id) { index, button in
                        Button(action: {
                            executeAction(button.action, launcherManager: launcherManager)
                        }) {
                            LauncherButtonView(button: button)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    Spacer().frame(width: 24) // Gap for split keyboard
                    ForEach(Array(allButtons.dropFirst(15).prefix(5)), id: \.id) { button in
                        Button(action: {
                            executeAction(button.action, launcherManager: launcherManager)
                        }) {
                            LauncherButtonView(button: button)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                // Row 3: Z-M, comma, period, dash (10 buttons) - gap between B and N
                HStack(spacing: 8) {
                    ForEach(Array(allButtons.dropFirst(20).prefix(5).enumerated()), id: \.element.id) { index, button in
                        Button(action: {
                            executeAction(button.action, launcherManager: launcherManager)
                        }) {
                            LauncherButtonView(button: button)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    Spacer().frame(width: 24) // Gap for split keyboard
                    ForEach(Array(allButtons.dropFirst(25).prefix(5)), id: \.id) { button in
                        Button(action: {
                            executeAction(button.action, launcherManager: launcherManager)
                        }) {
                            LauncherButtonView(button: button)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(16)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 20)
        .frame(width: 1150, height: 400)
        .background(
            KeyHandler(launcherManager: launcherManager, configManager: configManager, selectedTab: $selectedTab)
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
        }
    }
}

struct KeyHandler: NSViewRepresentable {
    let launcherManager: LauncherManager
    let configManager: ButtonConfigManager
    @Binding var selectedTab: Int
    
    func makeNSView(context: Context) -> KeyHandlingView {
        let view = KeyHandlingView()
        view.launcherManager = launcherManager
        view.configManager = configManager
        view.selectedTab = $selectedTab
        return view
    }
    
    func updateNSView(_ nsView: KeyHandlingView, context: Context) {
        nsView.launcherManager = launcherManager
        nsView.configManager = configManager
        nsView.selectedTab = $selectedTab
    }
}

class KeyHandlingView: NSView {
    var launcherManager: LauncherManager?
    var configManager: ButtonConfigManager?
    var selectedTab: Binding<Int>?
    
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
        }
        
        // Convert config buttons to launcher buttons (flatten all tabs)
        let allButtons = configManager.buttons.flatMap { tab in
            tab.map { config in
                LauncherButton(key: config.key, label: config.label, action: config.toLauncherAction())
            }
        }
        
        let key = event.charactersIgnoringModifiers?.uppercased() ?? ""
        print("KeyHandlingView: Processing key: '\(key)'")
        
        // Handle button activation (search through all buttons)
        if let button = allButtons.first(where: { $0.key.uppercased() == key.uppercased() }) {
            print("KeyHandlingView: Found button for key '\(key)': \(button.label)")
            executeAction(button.action)
        } else {
            print("KeyHandlingView: No button found for key '\(key)'")
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
    
    func executeAction(_ action: LauncherAction) {
        switch action {
        case .none:
            break
        case .launchApp(let path):
            launchApplication(path: path)
        case .openFolder(let path):
            openFolder(path: path)
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
        .background(isHovered ? Color.accentColor.opacity(0.2) : Color(NSColor.controlBackgroundColor))
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

