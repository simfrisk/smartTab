import AppKit
import SwiftUI
import Combine

class StatusBarManager: ObservableObject {
    private var statusItem: NSStatusItem?
    private var launcherManager: LauncherManager?
    private var configManager: ButtonConfigManager?
    private var openPreferences: (() -> Void)?
    private var statusMenu: NSMenu?
    
    func setup(launcherManager: LauncherManager, configManager: ButtonConfigManager, openPreferences: @escaping () -> Void) {
        // Prevent duplicate setup
        if statusItem != nil {
            print("⚠️ StatusBarManager.setup() already called, skipping duplicate setup")
            return
        }
        
        print("🔧 StatusBarManager.setup() called")
        self.launcherManager = launcherManager
        self.configManager = configManager
        self.openPreferences = openPreferences
        
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        print("📊 Status item created: \(statusItem != nil ? "SUCCESS" : "FAILED")")
        
        // Set up the button
        if let button = statusItem?.button {
            print("🔘 Status bar button found, setting up...")
            // Try to load custom menubar icon
            if let customIcon = NSImage(named: "MenubarIcon") {
                button.image = customIcon
                print("✅ Custom menubar icon loaded")
            } else if #available(macOS 11.0, *) {
                button.image = NSImage(systemSymbolName: "command.square", accessibilityDescription: "SmartTab")
                print("✅ System symbol icon set (fallback)")
            } else {
                // Fallback for older macOS versions - create a simple text-based icon
                let image = NSImage(size: NSSize(width: 18, height: 18))
                image.lockFocus()
                NSColor.labelColor.set()
                let rect = NSRect(x: 0, y: 0, width: 18, height: 18)
                let path = NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3)
                path.fill()
                image.unlockFocus()
                button.image = image
                print("✅ Fallback icon created")
            }
            button.image?.isTemplate = true
            button.toolTip = "SmartTab"
            button.action = #selector(statusBarButtonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
            print("✅ Button configured")
        } else {
            print("❌ Status bar button is nil!")
        }
        
        // Create menu
        let menu = NSMenu()
        
        // Show Launcher menu item
        let showLauncherItem = NSMenuItem(
            title: "Show Launcher",
            action: #selector(showLauncher),
            keyEquivalent: ""
        )
        showLauncherItem.target = self
        menu.addItem(showLauncherItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Re-check Permissions menu item
        let recheckItem = NSMenuItem(
            title: "Re-check Accessibility Permissions",
            action: #selector(recheckPermissions),
            keyEquivalent: ""
        )
        recheckItem.target = self
        menu.addItem(recheckItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Preferences menu item
        let preferencesItem = NSMenuItem(
            title: "Preferences...",
            action: #selector(showPreferences),
            keyEquivalent: ","
        )
        preferencesItem.target = self
        menu.addItem(preferencesItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit menu item
        let quitItem = NSMenuItem(
            title: "Quit SmartTab",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusMenu = menu
        // Keep menu property as nil by default - we'll show it manually on right-click
        statusItem?.menu = nil
        print("✅ Status bar menu configured. Status bar should now be visible!")
    }
    
    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            launcherManager?.toggleLauncher()
            return
        }
        
        let isRightClick = event.type == .rightMouseUp || event.modifierFlags.contains(.control)
        if isRightClick, let menu = statusMenu {
            // Modern API: use menu.popUp to show menu at current mouse location
            let location = NSEvent.mouseLocation
            menu.popUp(positioning: nil, at: location, in: nil)
        } else {
            launcherManager?.toggleLauncher()
        }
    }
    
    @objc private func showLauncher() {
        launcherManager?.toggleLauncher()
    }
    
    @objc private func showPreferences() {
        openPreferences?()
    }
    
    @objc private func recheckPermissions() {
        print("🔄 User requested to re-check permissions")
        launcherManager?.recheckPermissionsAndSetup()
        
        // Show alert
        let alert = NSAlert()
        alert.messageText = "Permissions Re-checked"
        alert.informativeText = "The app has re-checked accessibility permissions. Check the console for details. If permissions were just granted, you may need to quit and restart the app."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    func updateMenu() {
        // Update menu items if needed (e.g., show current hotkey)
        guard let menu = statusMenu,
              let hotkeyConfig = configManager?.hotkeyConfig else { return }
        
        // Update the menu item title to show current hotkey
        if let showLauncherItem = menu.item(at: 0) {
            let isVisible = launcherManager?.isVisible ?? false
            if isVisible {
                showLauncherItem.title = "Hide Launcher (\(hotkeyConfig.displayString()))"
            } else {
                showLauncherItem.title = "Show Launcher (\(hotkeyConfig.displayString()))"
            }
        }
    }
}

