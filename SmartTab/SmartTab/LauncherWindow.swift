import SwiftUI
import AppKit

class LauncherWindowController: NSWindowController, NSWindowDelegate {
    let launcherManager: LauncherManager
    let configManager: ButtonConfigManager
    
    init(launcherManager: LauncherManager, configManager: ButtonConfigManager) {
        self.launcherManager = launcherManager
        self.configManager = configManager
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1150, height: 400),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.fullScreenAuxiliary]
        window.isMovableByWindowBackground = false
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true
        window.makeFirstResponder(nil)
        
        let contentView = LauncherView(launcherManager: launcherManager, configManager: configManager)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create a container view that can accept first responder
        let containerView = KeyEventContainerView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(hostingView)
        
        window.contentView = containerView
        
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // Store reference to launcher view for key handling
        containerView.launcherView = contentView
        containerView.launcherManager = launcherManager
        containerView.configManager = configManager
        
        super.init(window: window)
        window.delegate = self
        
        // Center the window on screen
        centerWindow()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func centerWindow() {
        guard let window = window else { return }
        
        // Get the screen where the cursor is located
        let mouseLocation = NSEvent.mouseLocation
        var targetScreen: NSScreen? = nil
        
        // Find the screen that contains the mouse cursor
        for screen in NSScreen.screens {
            let screenFrame = screen.frame
            // NSEvent.mouseLocation uses bottom-left origin, same as screen.frame
            if screenFrame.contains(mouseLocation) {
                targetScreen = screen
                break
            }
        }
        
        // Fallback to main screen if cursor not found on any screen
        if targetScreen == nil {
            targetScreen = NSScreen.main
        }
        
        guard let screen = targetScreen else { return }
        
        let screenRect = screen.visibleFrame
        let windowRect = window.frame
        let x = (screenRect.width - windowRect.width) / 2 + screenRect.origin.x
        let y = (screenRect.height - windowRect.height) / 2 + screenRect.origin.y
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    private var keyboardMonitor: Any?
    private var mouseMonitor: Any?
    
    func show() {
        centerWindow()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Set up keyboard monitoring using local event monitor
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self,
                  let containerView = self.window?.contentView as? KeyEventContainerView else {
                return event
            }
            
            // Check for hotkey first before handling other events
            if let launcherManager = containerView.launcherManager,
               let configManager = containerView.configManager {
                if configManager.hotkeyConfig.matches(event: event) {
                    print("LauncherWindow: Hotkey detected in keyboardMonitor, toggling launcher")
                    DispatchQueue.main.async { [weak launcherManager] in
                        launcherManager?.toggleLauncher()
                    }
                    return nil // Consume the event
                } else if let secondaryConfig = configManager.secondaryHotkeyConfig,
                          secondaryConfig.matches(event: event) {
                    print("LauncherWindow: Secondary hotkey detected in keyboardMonitor, toggling launcher")
                    DispatchQueue.main.async { [weak launcherManager] in
                        launcherManager?.toggleLauncher()
                    }
                    return nil // Consume the event
                }
            }
            
            containerView.handleKeyEvent(event)
            return nil // Consume the event
        }
        
        // Set up mouse monitoring to detect clicks outside the window
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let window = self.window else { return }
            
            // Check if click is outside the window
            let clickLocation = NSEvent.mouseLocation
            let windowFrame = window.frame
            
            if !windowFrame.contains(clickLocation) {
                // Click is outside the window, close the launcher
                self.launcherManager.isVisible = false
            }
        }
        
        // Give the window time to appear, then set first responder
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let containerView = self.window?.contentView as? KeyEventContainerView {
                self.window?.makeFirstResponder(containerView)
                print("LauncherWindow: Set KeyEventContainerView as first responder")
            } else {
                print("LauncherWindow: Could not find KeyEventContainerView")
            }
        }
    }
    
    func hide() {
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardMonitor = nil
        }
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
        window?.orderOut(nil)
    }
    
    
    func windowDidResignKey(_ notification: Notification) {
        // Close when window loses focus (user clicks away)
        launcherManager.isVisible = false
    }
}

class KeyEventContainerView: NSView {
    var launcherView: LauncherView?
    var launcherManager: LauncherManager?
    var configManager: ButtonConfigManager?

    // Drag-and-drop state
    private var dragHoverTimer: Timer?
    private var currentHoveredButtonIndex: Int?
    private let dragHoverDelay: TimeInterval = 0.7 // Match Dock behavior
    
    override var acceptsFirstResponder: Bool { true }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupDarkBackground()
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            setupDarkBackground()
        }
    }
    
    private func setupDarkBackground() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.3).cgColor

        // Register for drag-and-drop
        registerForDraggedTypes([.fileURL, .string, .URL, .tiff, .png, .pdf])
    }
    
    override func draw(_ dirtyRect: NSRect) {
        // Draw dark semi-transparent background
        NSColor.black.withAlphaComponent(0.3).setFill()
        dirtyRect.fill()
        super.draw(dirtyRect)
    }
    
    override func keyDown(with event: NSEvent) {
        print("KeyEventContainerView: keyDown received - key: '\(event.charactersIgnoringModifiers ?? "")', keyCode: \(event.keyCode)")
        
        // First check if this is the hotkey - if so, toggle the launcher
        if let launcherManager = launcherManager,
           let configManager = configManager {
            if configManager.hotkeyConfig.matches(event: event) {
                print("KeyEventContainerView: Hotkey detected in keyDown, toggling launcher")
                launcherManager.toggleLauncher()
                return
            } else if let secondaryConfig = configManager.secondaryHotkeyConfig,
                      secondaryConfig.matches(event: event) {
                print("KeyEventContainerView: Secondary hotkey detected in keyDown, toggling launcher")
                launcherManager.toggleLauncher()
                return
            }
        }
        
        // Try to find and use the KeyHandlingView first
        if let keyHandler = findKeyHandler(in: subviews) {
            print("KeyEventContainerView: Found KeyHandlingView, forwarding event")
            keyHandler.keyDown(with: event)
            return
        }
        
        // Fallback: handle directly if we have the launcher view
        if let launcherView = launcherView {
            print("KeyEventContainerView: Using launcher view directly")
            handleKeyEvent(event, in: launcherView)
        } else {
            print("KeyEventContainerView: No handler found, calling super")
            super.keyDown(with: event)
        }
    }
    
    func handleKeyEvent(_ event: NSEvent) {
        print("KeyEventContainerView: handleKeyEvent - key: '\(event.charactersIgnoringModifiers ?? "")', keyCode: \(event.keyCode)")

        // First check if this is the hotkey - if so, toggle the launcher
        if let launcherManager = launcherManager,
           let configManager = configManager {
            if configManager.hotkeyConfig.matches(event: event) {
                print("KeyEventContainerView: Hotkey detected, toggling launcher")
                launcherManager.toggleLauncher()
                return
            } else if let secondaryConfig = configManager.secondaryHotkeyConfig,
                      secondaryConfig.matches(event: event) {
                print("KeyEventContainerView: Secondary hotkey detected, toggling launcher")
                launcherManager.toggleLauncher()
                return
            }
        }
        
        // Try to find and use the KeyHandlingView first
        if let keyHandler = findKeyHandler(in: subviews) {
            print("KeyEventContainerView: Found KeyHandlingView, forwarding event")
            keyHandler.keyDown(with: event)
            return
        }
        
        // ESC to close
        if event.keyCode == 53 {
            launcherManager?.isVisible = false
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent, in launcherView: LauncherView) {
        // First check if this is the hotkey - if so, toggle the launcher
        if let launcherManager = launcherManager,
           let configManager = configManager {
            if configManager.hotkeyConfig.matches(event: event) {
                print("KeyEventContainerView: Hotkey detected in fallback handler, toggling launcher")
                launcherManager.toggleLauncher()
                return
            } else if let secondaryConfig = configManager.secondaryHotkeyConfig,
                      secondaryConfig.matches(event: event) {
                print("KeyEventContainerView: Secondary hotkey detected in fallback handler, toggling launcher")
                launcherManager.toggleLauncher()
                return
            }
        }
        
        // This is a fallback - the KeyHandlingView should handle this normally
        // ESC to close
        if event.keyCode == 53 {
            launcherManager?.isVisible = false
        }
    }
    
    private func findKeyHandler(in views: [NSView]) -> KeyHandlingView? {
        for view in views {
            if let handler = view as? KeyHandlingView {
                return handler
            }
            if let handler = findKeyHandler(in: view.subviews) {
                return handler
            }
        }
        return nil
    }

    // MARK: - NSDraggingDestination Methods

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        print("Drag entered SmartTab window")
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let locationInWindow = sender.draggingLocation
        let locationInView = convert(locationInWindow, from: nil)

        // Calculate which button is being hovered
        if let buttonIndex = calculateButtonIndex(at: locationInView) {
            // Button hover detected
            if currentHoveredButtonIndex != buttonIndex {
                // Hovering over a different button - reset timer
                cancelHoverTimer()
                currentHoveredButtonIndex = buttonIndex
                startHoverTimer(for: buttonIndex)
            }
            // If same button, timer is already running
        } else {
            // Not hovering over any button - cancel timer
            cancelHoverTimer()
            currentHoveredButtonIndex = nil
        }

        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        print("Drag exited SmartTab window")
        cancelHoverTimer()
        currentHoveredButtonIndex = nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        // We don't want to handle the drop - just let the activated app receive it
        // Return false to let the system deliver the drop to the activated app
        cancelHoverTimer()
        currentHoveredButtonIndex = nil
        return false
    }

    // MARK: - Drag Helper Methods

    private func calculateButtonIndex(at point: NSPoint) -> Int? {
        // Constants matching LauncherView layout
        let windowWidth: CGFloat = 1150
        let windowHeight: CGFloat = 400
        let padding: CGFloat = 16
        let buttonWidth: CGFloat = 100
        let buttonHeight: CGFloat = 100
        let buttonSpacing: CGFloat = 8
        let gapBetweenHalves: CGFloat = 24
        let rowSpacing: CGFloat = 12

        // Calculate content area
        let contentX = padding
        let contentY = padding
        let contentWidth = windowWidth - (padding * 2)
        let contentHeight = windowHeight - (padding * 2)

        // Check if point is within content area
        guard point.x >= contentX && point.x <= contentX + contentWidth &&
              point.y >= contentY && point.y <= contentY + contentHeight else {
            return nil
        }

        // Calculate relative position from bottom-left of content area
        // Note: NSView uses bottom-left origin, SwiftUI uses top-left
        let relativeX = point.x - contentX
        let relativeY = contentHeight - (point.y - contentY) // Flip Y for SwiftUI

        // Determine row (0 = top row, 1 = middle, 2 = bottom)
        let row: Int
        if relativeY < buttonHeight {
            row = 0
        } else if relativeY < buttonHeight + rowSpacing + buttonHeight {
            row = 1
        } else if relativeY < buttonHeight + rowSpacing + buttonHeight + rowSpacing + buttonHeight {
            row = 2
        } else {
            return nil // Below all rows
        }

        // Each row has 5 buttons, gap, 5 buttons
        let halfWidth = (buttonWidth * 5) + (buttonSpacing * 4)
        let firstHalfEnd = halfWidth
        let secondHalfStart = firstHalfEnd + gapBetweenHalves

        // Determine column within row
        let column: Int
        if relativeX < firstHalfEnd {
            // First half (buttons 0-4)
            let posInHalf = relativeX
            let buttonIndex = Int(posInHalf / (buttonWidth + buttonSpacing))
            column = min(buttonIndex, 4) // Clamp to 0-4
        } else if relativeX >= secondHalfStart {
            // Second half (buttons 5-9)
            let posInHalf = relativeX - secondHalfStart
            let buttonIndex = Int(posInHalf / (buttonWidth + buttonSpacing))
            column = 5 + min(buttonIndex, 4) // Offset by 5, clamp to 5-9
        } else {
            // In the gap between halves
            return nil
        }

        // Calculate final button index (0-29)
        let buttonIndex = (row * 10) + column

        // Validate button exists and has an action
        guard let launcherView = launcherView else { return nil }
        let buttons = launcherView.allButtons
        guard buttonIndex < buttons.count else { return nil }

        // Only return index if button has an action
        if case .none = buttons[buttonIndex].action {
            return nil
        }

        return buttonIndex
    }

    private func startHoverTimer(for buttonIndex: Int) {
        dragHoverTimer = Timer.scheduledTimer(withTimeInterval: dragHoverDelay, repeats: false) { [weak self] _ in
            self?.activateButtonAtIndex(buttonIndex)
        }
    }

    private func cancelHoverTimer() {
        dragHoverTimer?.invalidate()
        dragHoverTimer = nil
    }

    private func activateButtonAtIndex(_ index: Int) {
        guard let launcherView = launcherView else {
            print("KeyEventContainerView: No launcherView available for drag activation")
            return
        }

        let buttons = launcherView.allButtons
        guard index < buttons.count else {
            print("KeyEventContainerView: Invalid button index \(index)")
            return
        }

        let button = buttons[index]
        print("KeyEventContainerView: Activating app via drag: \(button.label) at index \(index)")

        // Use existing executeAction logic from LauncherView
        // Hide the launcher after switching so user can see where to drop the file
        switch button.action {
        case .none:
            break
        case .launchApp(let path):
            launchApp(at: path, keepLauncherVisible: false)
        case .openFolder(let path):
            openFolder(at: path, keepLauncherVisible: false)
        }
    }

    private func launchApp(at path: String, keepLauncherVisible: Bool) {
        print("KeyEventContainerView: Launching app for drag: \(path)")
        let url = URL(fileURLWithPath: path)

        let success = NSWorkspace.shared.open(url)
        if !success {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { (app, error) in
                if let error = error {
                    print("Error launching app at \(path): \(error.localizedDescription)")
                } else if let app = app {
                    // Don't move cursor during drag - it interferes with the drag operation
                    print("App launched successfully for drag-and-drop: \(app.localizedName ?? "unknown")")
                }
            }
        } else {
            print("App launched successfully for drag-and-drop")
        }

        // Don't hide launcher if we're keeping it visible for drag
        if !keepLauncherVisible {
            launcherManager?.isVisible = false
        }
    }

    private func openFolder(at path: String, keepLauncherVisible: Bool) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path))

        if !keepLauncherVisible {
            launcherManager?.isVisible = false
        }
    }
}

