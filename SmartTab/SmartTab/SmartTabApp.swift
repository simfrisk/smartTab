import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarManager: StatusBarManager?
    var launcherManager: LauncherManager?
    var configManager: ButtonConfigManager?
    var openPreferences: (() -> Void)?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 AppDelegate: applicationDidFinishLaunching called")
        // Set up status bar when app finishes launching
        // Use a longer delay to ensure references are set from configureAppDelegate
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("🔧 AppDelegate: Attempting to set up status bar...")
            if let statusBarManager = self.statusBarManager,
               let launcherManager = self.launcherManager,
               let configManager = self.configManager,
               let openPreferences = self.openPreferences {
                print("✅ AppDelegate: All references available, setting up status bar")
                statusBarManager.setup(
                    launcherManager: launcherManager,
                    configManager: configManager,
                    openPreferences: openPreferences
                )
                print("✅ AppDelegate: Status bar setup complete")
            } else {
                print("❌ AppDelegate: Missing references - statusBarManager: \(self.statusBarManager != nil), launcherManager: \(self.launcherManager != nil), configManager: \(self.configManager != nil), openPreferences: \(self.openPreferences != nil)")
                // Retry after another delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if let statusBarManager = self.statusBarManager,
                       let launcherManager = self.launcherManager,
                       let configManager = self.configManager,
                       let openPreferences = self.openPreferences {
                        print("✅ AppDelegate: Retry successful, setting up status bar")
                        statusBarManager.setup(
                            launcherManager: launcherManager,
                            configManager: configManager,
                            openPreferences: openPreferences
                        )
                    }
                }
            }
        }
    }
}

@main
struct SmartTabApp: App {
    @StateObject private var configManager: ButtonConfigManager
    @StateObject private var launcherManager: LauncherManager
    @StateObject private var statusBarManager = StatusBarManager()
    @State private var windowController: LauncherWindowController?
    @State private var preferencesWindow: NSWindow?
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        let configManager = ButtonConfigManager()
        _configManager = StateObject(wrappedValue: configManager)
        _launcherManager = StateObject(wrappedValue: LauncherManager(hotkeyConfig: configManager.hotkeyConfig, secondaryHotkeyConfig: configManager.secondaryHotkeyConfig))

        // Ensure the app is set up as an accessory (background) app
        // This is important for global hotkeys to work
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.accessory)
        }
    }
    
    // This will be called when the app body is evaluated
    // We'll use this to set up references early
    private func configureAppDelegate() {
        // Set up references immediately when this is called
        // Use a small delay to ensure StateObjects are ready
        DispatchQueue.main.async {
            self.appDelegate.statusBarManager = self.statusBarManager
            self.appDelegate.launcherManager = self.launcherManager
            self.appDelegate.configManager = self.configManager
            self.appDelegate.openPreferences = self.openPreferences
            print("✅ AppDelegate references set from configureAppDelegate")
            
            // Also set up status bar directly here as a backup
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.statusBarManager.setup(
                    launcherManager: self.launcherManager,
                    configManager: self.configManager,
                    openPreferences: self.openPreferences
                )
                print("✅ Status bar setup from configureAppDelegate")
            }
        }
    }
    
    // Helper to set up status bar after app is ready
    private func setupStatusBar() {
        statusBarManager.setup(
            launcherManager: launcherManager,
            configManager: configManager,
            openPreferences: openPreferences
        )
    }
    
    var body: some Scene {
        // Configure app delegate and set up status bar when body is evaluated
        let _ = configureAppDelegate()
        
        return Settings {
            EmptyView()
                .task {
                    print("🎬 Settings task started")
                    // Set up app delegate references (backup, should already be set)
                    appDelegate.statusBarManager = statusBarManager
                    appDelegate.launcherManager = launcherManager
                    appDelegate.configManager = configManager
                    appDelegate.openPreferences = openPreferences
                    
                    // Set up status bar directly - this should work
                    statusBarManager.setup(
                        launcherManager: launcherManager,
                        configManager: configManager,
                        openPreferences: openPreferences
                    )
                    print("✅ Status bar setup called from Settings task")
                }
                .onAppear {
                    print("🎬 Settings onAppear")
                    // Backup: also try on appear
                    statusBarManager.setup(
                        launcherManager: launcherManager,
                        configManager: configManager,
                        openPreferences: openPreferences
                    )
                    print("✅ Status bar setup called from Settings onAppear")
                }
        }
        .commands {
            CommandGroup(after: .appSettings) {
                Button("Preferences...") {
                    openPreferences()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        .onChange(of: configManager.hotkeyConfig) { oldValue, newValue in
            launcherManager.updateHotkeyConfig(newValue)
            statusBarManager.updateMenu()
        }
        .onChange(of: configManager.secondaryHotkeyConfig) { oldValue, newValue in
            launcherManager.updateSecondaryHotkeyConfig(newValue)
            statusBarManager.updateMenu()
        }
        .onChange(of: launcherManager.isVisible) { oldValue, newValue in
            // onChange is already called on main thread by SwiftUI
            if newValue {
                if windowController == nil {
                    windowController = LauncherWindowController(launcherManager: launcherManager, configManager: configManager)
                }
                windowController?.show()
            } else {
                windowController?.hide()
            }
            // Update menu to reflect launcher state
            statusBarManager.updateMenu()
        }
    }
    
    func openPreferences() {
        if preferencesWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            
            window.title = "SmartTab Preferences"
            window.contentView = NSHostingView(rootView: PreferencesView(configManager: configManager, launcherManager: launcherManager))
            window.center()
            preferencesWindow = window
        }
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
