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
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
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
        if let screen = NSScreen.main, let window = window {
            let screenRect = screen.visibleFrame
            let windowRect = window.frame
            let x = (screenRect.width - windowRect.width) / 2 + screenRect.origin.x
            let y = (screenRect.height - windowRect.height) / 2 + screenRect.origin.y
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
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
            
            let handled = containerView.handleKeyEvent(event)
            return handled ? nil : event
        }
        
        // Set up mouse monitoring to detect clicks outside the window
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, let window = self.window else { return }
            
            // Check if click is outside the window
            let clickLocation = NSEvent.mouseLocation
            let windowFrame = window.frame
            
            if !windowFrame.contains(clickLocation) {
                // Click is outside the window, close the launcher
                DispatchQueue.main.async {
                    self.launcherManager.isVisible = false
                }
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
        if !handleKeyEvent(event) {
            print("KeyEventContainerView: No handler processed event, calling super")
            super.keyDown(with: event)
        }
    }
    
    @discardableResult
    func handleKeyEvent(_ event: NSEvent) -> Bool {
        print("KeyEventContainerView: handleKeyEvent - key: '\(event.charactersIgnoringModifiers ?? "")', keyCode: \(event.keyCode)")
        
        if let launcherManager = launcherManager,
           let configManager = configManager,
           configManager.hotkeyConfig.matches(event: event) {
            print("KeyEventContainerView: Hotkey detected, toggling launcher")
            launcherManager.toggleLauncher()
            return true
        }
        
        if let keyHandler = findKeyHandler(in: subviews) {
            print("KeyEventContainerView: Found KeyHandlingView, forwarding event")
            keyHandler.keyDown(with: event)
            return true
        }
        
        if event.keyCode == 53 {
            launcherManager?.isVisible = false
            return true
        }
        
        return false
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

