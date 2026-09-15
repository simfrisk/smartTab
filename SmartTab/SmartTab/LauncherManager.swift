import SwiftUI
import AppKit
import Combine
import ApplicationServices
import Carbon

class LauncherManager: ObservableObject {
    @Published var isVisible = false {
        didSet {
            // The window is reused between showings, so always reopen on the apps layer
            if !isVisible {
                currentLayer = .apps
            }
        }
    }
    @Published var currentLayer: AppLayer = .apps
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var hotKeyRef: EventHotKeyRef?
    private var secondaryHotKeyRef: EventHotKeyRef?
    private var shortcutsHotKeyRef: EventHotKeyRef?
    private var hotKeyEventHandler: EventHandlerRef?
    private var hotkeyConfig: HotkeyConfig
    private var secondaryHotkeyConfig: HotkeyConfig?
    private var shortcutsHotkeyConfig: HotkeyConfig?
    // PHASE 3: Removed unused hotkeyConfigCancellable variable

    private static let hotKeySignature: FourCharCode = 0x534D5442 // 'SMTB'
    private static let hotKeyIdentifier: UInt32 = 1
    private static let secondaryHotKeyIdentifier: UInt32 = 2
    fileprivate static let shortcutsHotKeyIdentifier: UInt32 = 3

    init(hotkeyConfig: HotkeyConfig = HotkeyConfig(), secondaryHotkeyConfig: HotkeyConfig? = nil, shortcutsHotkeyConfig: HotkeyConfig? = nil) {
        self.hotkeyConfig = hotkeyConfig
        self.secondaryHotkeyConfig = secondaryHotkeyConfig
        self.shortcutsHotkeyConfig = shortcutsHotkeyConfig
        setupGlobalHotkey()
    }

    func updateHotkeyConfig(_ config: HotkeyConfig) {
        hotkeyConfig = config
        setupGlobalHotkey()
    }

    func updateSecondaryHotkeyConfig(_ config: HotkeyConfig?) {
        secondaryHotkeyConfig = config
        setupGlobalHotkey()
    }

    func updateShortcutsHotkeyConfig(_ config: HotkeyConfig?) {
        shortcutsHotkeyConfig = config
        setupGlobalHotkey()
    }

    private func removeMonitors() {
        unregisterCarbonHotKey()
        unregisterSecondaryCarbonHotKey()
        unregisterShortcutsCarbonHotKey()

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

        // Register secondary hotkey if configured
        if let secondaryConfig = secondaryHotkeyConfig {
            if registerSecondaryCarbonHotKey() {
                print("✅ Secondary Carbon hotkey registered. Press \(secondaryConfig.displayString()) to open launcher.")
            } else {
                print("⚠️ Unable to register secondary Carbon hotkey. It will be handled by the fallback monitor.")
            }
        }

        // Register shortcuts-layer hotkey if configured
        if let shortcutsConfig = shortcutsHotkeyConfig {
            if registerShortcutsCarbonHotKey() {
                print("✅ Shortcuts-layer Carbon hotkey registered. Press \(shortcutsConfig.displayString()) to open the shortcuts layer.")
            } else {
                print("⚠️ Unable to register shortcuts-layer Carbon hotkey. It will be handled by the fallback monitor.")
            }
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

    /// Opens the launcher straight on the shortcuts layer, switches to it if the
    /// launcher is already showing the apps layer, and closes if already there.
    func toggleShortcutsLayer() {
        if Thread.isMainThread {
            performShortcutsLayerToggle()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.performShortcutsLayerToggle()
            }
        }
    }

    private func performShortcutsLayerToggle() {
        if !isVisible {
            currentLayer = .shortcuts
            isVisible = true
        } else if currentLayer == .apps {
            currentLayer = .shortcuts
        } else {
            isVisible = false
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
        
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData else { return noErr }
            let launcherManager = Unmanaged<LauncherManager>.fromOpaque(userData).takeUnretainedValue()

            var hotKeyID = EventHotKeyID()
            if let event = event {
                GetEventParameter(event,
                                  EventParamName(kEventParamDirectObject),
                                  EventParamType(typeEventHotKeyID),
                                  nil,
                                  MemoryLayout<EventHotKeyID>.size,
                                  nil,
                                  &hotKeyID)
            }

            launcherManager.handleCarbonHotKey(identifier: hotKeyID.id)
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
        
        let hotKeyID = EventHotKeyID(signature: Self.hotKeySignature, id: Self.hotKeyIdentifier)
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

    func registerSecondaryCarbonHotKey() -> Bool {
        unregisterSecondaryCarbonHotKey()

        guard let config = secondaryHotkeyConfig else {
            return false
        }

        let hotKeyID = EventHotKeyID(signature: Self.hotKeySignature, id: Self.secondaryHotKeyIdentifier)
        let modifiers = carbonModifiers(for: config)
        let status = RegisterEventHotKey(UInt32(config.keyCode), modifiers, hotKeyID, GetApplicationEventTarget(), 0, &secondaryHotKeyRef)

        if status != noErr {
            print("❌ RegisterEventHotKey (secondary) failed with status \(status)")
            secondaryHotKeyRef = nil
            return false
        }

        print("✅ Registered secondary Carbon hotkey: \(config.displayString())")
        return true
    }

    func unregisterSecondaryCarbonHotKey() {
        if let hotKeyRef = secondaryHotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.secondaryHotKeyRef = nil
        }
    }

    func registerShortcutsCarbonHotKey() -> Bool {
        unregisterShortcutsCarbonHotKey()

        guard let config = shortcutsHotkeyConfig else {
            return false
        }

        let hotKeyID = EventHotKeyID(signature: Self.hotKeySignature, id: Self.shortcutsHotKeyIdentifier)
        let modifiers = carbonModifiers(for: config)
        let status = RegisterEventHotKey(UInt32(config.keyCode), modifiers, hotKeyID, GetApplicationEventTarget(), 0, &shortcutsHotKeyRef)

        if status != noErr {
            print("❌ RegisterEventHotKey (shortcuts layer) failed with status \(status)")
            shortcutsHotKeyRef = nil
            return false
        }

        print("✅ Registered shortcuts-layer Carbon hotkey: \(config.displayString())")
        return true
    }

    func unregisterShortcutsCarbonHotKey() {
        if let hotKeyRef = shortcutsHotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.shortcutsHotKeyRef = nil
        }
    }

    func handleCarbonHotKey(identifier: UInt32) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            NSApp.activate(ignoringOtherApps: true)

            if identifier == Self.shortcutsHotKeyIdentifier {
                print("🌐 Carbon shortcuts-layer hotkey detected")
                self.performShortcutsLayerToggle()
            } else {
                print("🌐 Carbon global hotkey detected: \(self.hotkeyConfig.displayString())")
                self.isVisible.toggle()
            }
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
            } else if let secondaryConfig = self.secondaryHotkeyConfig,
                      secondaryConfig.matches(event: event) {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    print("🌐 Secondary global hotkey detected via fallback monitor: \(secondaryConfig.displayString())")
                    NSApp.activate(ignoringOtherApps: true)
                    self.isVisible.toggle()
                }
            } else if let shortcutsConfig = self.shortcutsHotkeyConfig,
                      shortcutsConfig.matches(event: event) {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    print("🌐 Shortcuts-layer global hotkey detected via fallback monitor: \(shortcutsConfig.displayString())")
                    NSApp.activate(ignoringOtherApps: true)
                    self.toggleShortcutsLayer()
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
            } else if let secondaryConfig = self.secondaryHotkeyConfig,
                      secondaryConfig.matches(event: event) {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    print("⌨️ Local secondary hotkey detected via fallback monitor: \(secondaryConfig.displayString())")
                    self.isVisible.toggle()
                }
                return nil
            } else if let shortcutsConfig = self.shortcutsHotkeyConfig,
                      shortcutsConfig.matches(event: event) {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    print("⌨️ Local shortcuts-layer hotkey detected via fallback monitor: \(shortcutsConfig.displayString())")
                    self.toggleShortcutsLayer()
                }
                return nil
            }
            return event
        }
        
        print("✅ Hotkey fallback setup complete. Press \(hotkeyConfig.displayString()) to open launcher.")
    }
}

