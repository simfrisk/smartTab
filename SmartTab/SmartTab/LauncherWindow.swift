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
               let configManager = containerView.configManager,
               configManager.hotkeyConfig.matches(event: event) {
                print("LauncherWindow: Hotkey detected in keyboardMonitor, toggling launcher")
                DispatchQueue.main.async { [weak launcherManager] in
                    launcherManager?.toggleLauncher()
                }
                return nil // Consume the event
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
           let configManager = configManager,
           configManager.hotkeyConfig.matches(event: event) {
            print("KeyEventContainerView: Hotkey detected in keyDown, toggling launcher")
            launcherManager.toggleLauncher()
            return
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
           let configManager = configManager,
           configManager.hotkeyConfig.matches(event: event) {
            print("KeyEventContainerView: Hotkey detected, toggling launcher")
            launcherManager.toggleLauncher()
            return
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
           let configManager = configManager,
           configManager.hotkeyConfig.matches(event: event) {
            print("KeyEventContainerView: Hotkey detected in fallback handler, toggling launcher")
            launcherManager.toggleLauncher()
            return
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
}

