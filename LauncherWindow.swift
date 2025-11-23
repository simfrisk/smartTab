import SwiftUI
import AppKit

class LauncherWindowController: NSWindowController, NSWindowDelegate {
    let launcherManager: LauncherManager
    
    init(launcherManager: LauncherManager) {
        self.launcherManager = launcherManager
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 480),
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
        
        let contentView = LauncherView(launcherManager: launcherManager)
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
    
    func show() {
        centerWindow()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if let containerView = window?.contentView as? KeyEventContainerView {
            window?.makeFirstResponder(containerView)
        }
    }
    
    func hide() {
        window?.orderOut(nil)
    }
    
    func windowDidResignKey(_ notification: Notification) {
        // Close when window loses focus (user clicks away)
        launcherManager.isVisible = false
    }
}

class KeyEventContainerView: NSView {
    var launcherView: LauncherView?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        // Forward to launcher view's key handler
        if let keyHandler = findKeyHandler(in: subviews) {
            keyHandler.keyDown(with: event)
        } else {
            super.keyDown(with: event)
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

