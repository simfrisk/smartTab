import SwiftUI
import AppKit
import Combine
import ApplicationServices
import Carbon

class LauncherManager: ObservableObject {
    @Published var isVisible = false
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyEventHandler: EventHandlerRef?
    private var hotkeyConfig: HotkeyConfig
    private var hotkeyConfigCancellable: AnyCancellable?
    
    private static let hotKeySignature: FourCharCode = 0x534D5442 // 'SMTB'
    private static let hotKeyIdentifier: UInt32 = 1
    
    init(hotkeyConfig: HotkeyConfig = HotkeyConfig()) {
        self.hotkeyConfig = hotkeyConfig
        setupGlobalHotkey()
    }
    
    func updateHotkeyConfig(_ config: HotkeyConfig) {
        hotkeyConfig = config
        setupGlobalHotkey()
    }
    
    private func removeMonitors() {
        unregisterCarbonHotKey()
        
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
    
    func setupGlobalHotkey() {
        removeMonitors()
        installHotKeyHandlerIfNeeded()
        
        if registerCarbonHotKey() {
            print("✅ Carbon hotkey registered. Press \(hotkeyConfig.displayString()) to open launcher.")
        } else {
            print("⚠️ Unable to register Carbon hotkey. Falling back to Accessibility-based event monitors.")
            registerAccessibilityFallback()
        }
    }
    
    // Function to re-check permissions and re-setup hotkey (call after granting permissions)
    func recheckPermissionsAndSetup() {
        print("🔄 Re-checking hotkey registration and resetting global shortcut...")
        setupGlobalHotkey()
    }
    
    func toggleLauncher() {
        // Ensure we're on the main thread for @Published property updates
        if Thread.isMainThread {
            isVisible.toggle()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.isVisible.toggle()
            }
        }
    }
    
    deinit {
        removeMonitors()
        removeHotKeyEventHandler()
    }
}

// MARK: - Carbon Hotkey Support

private extension LauncherManager {
    func installHotKeyHandlerIfNeeded() {
        guard hotKeyEventHandler == nil else { return }
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let launcherManager = Unmanaged<LauncherManager>.fromOpaque(userData).takeUnretainedValue()
            launcherManager.handleCarbonHotKey()
            return noErr
        }, 1, &eventType, userData, &hotKeyEventHandler)
        
        if status != noErr {
            print("❌ Failed to install hotkey event handler. OSStatus: \(status)")
        }
    }
    
    func removeHotKeyEventHandler() {
        if let handler = hotKeyEventHandler {
            RemoveEventHandler(handler)
            hotKeyEventHandler = nil
        }
    }
    
    func registerCarbonHotKey() -> Bool {
        unregisterCarbonHotKey()
        
        var hotKeyID = EventHotKeyID(signature: Self.hotKeySignature, id: Self.hotKeyIdentifier)
        let modifiers = carbonModifiers(for: hotkeyConfig)
        let status = RegisterEventHotKey(UInt32(hotkeyConfig.keyCode), modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        
        if status != noErr {
            print("❌ RegisterEventHotKey failed with status \(status)")
            hotKeyRef = nil
            return false
        }
        
        print("✅ Registered Carbon hotkey: \(hotkeyConfig.displayString())")
        return true
    }
    
    func unregisterCarbonHotKey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }
    
    func handleCarbonHotKey() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("🌐 Carbon global hotkey detected: \(self.hotkeyConfig.displayString())")
            NSApp.activate(ignoringOtherApps: true)
            self.isVisible.toggle()
        }
    }
    
    func carbonModifiers(for config: HotkeyConfig) -> UInt32 {
        var modifiers: UInt32 = 0
        if config.command { modifiers |= UInt32(cmdKey) }
        if config.shift { modifiers |= UInt32(shiftKey) }
        if config.option { modifiers |= UInt32(optionKey) }
        if config.control { modifiers |= UInt32(controlKey) }
        return modifiers
    }
    
    func registerAccessibilityFallback() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !accessEnabled {
            print("⚠️ Accessibility permissions not granted. Global hotkey may not work.")
            print("Please enable SmartTab in System Settings → Privacy & Security → Accessibility")
            print("After enabling, quit and restart the app.")
        } else {
            print("✅ Accessibility permissions granted. Global hotkey is active.")
        }
        
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            
            if self.hotkeyConfig.matches(event: event) {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    print("🌐 Global hotkey detected via fallback monitor: \(self.hotkeyConfig.displayString())")
                    NSApp.activate(ignoringOtherApps: true)
                    self.isVisible.toggle()
                }
            }
        }
        
        if globalMonitor == nil {
            print("❌ Failed to create fallback global event monitor. Accessibility permissions may be required.")
            print("   Make sure SmartTab is enabled in System Settings → Privacy & Security → Accessibility")
            print("   Then quit and restart the app completely.")
        } else {
            print("✅ Fallback global event monitor created successfully")
            print("   Hotkey configured: \(hotkeyConfig.displayString())")
            print("   Waiting for hotkey press...")
        }
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            if self.hotkeyConfig.matches(event: event) {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    print("⌨️ Local hotkey detected via fallback monitor: \(self.hotkeyConfig.displayString())")
                    self.isVisible.toggle()
                }
                return nil
            }
            return event
        }
        
        print("✅ Hotkey fallback setup complete. Press \(hotkeyConfig.displayString()) to open launcher.")
    }
}

