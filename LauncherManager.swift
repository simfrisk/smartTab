import SwiftUI
import AppKit

class LauncherManager: ObservableObject {
    @Published var isVisible = false
    private var globalMonitor: Any?
    private var localMonitor: Any?
    
    init() {
        setupGlobalHotkey()
    }
    
    func setupGlobalHotkey() {
        // Use NSEvent to monitor for CMD+` globally
        // Note: This requires Accessibility permissions in System Preferences
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Check for CMD+` (backtick key, keyCode 50)
            if event.modifierFlags.contains(.command) && event.keyCode == 50 {
                DispatchQueue.main.async {
                    self?.toggleLauncher()
                }
            }
        }
        
        // Also monitor locally when app is active
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.command) && event.keyCode == 50 {
                DispatchQueue.main.async {
                    self?.toggleLauncher()
                }
                return nil // Consume the event
            }
            return event
        }
    }
    
    func toggleLauncher() {
        isVisible.toggle()
    }
    
    deinit {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

