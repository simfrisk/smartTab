import SwiftUI
import AppKit

@main
struct SmartTabApp: App {
    @StateObject private var launcherManager = LauncherManager()
    @State private var windowController: LauncherWindowController?
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
        .onChange(of: launcherManager.isVisible) { isVisible in
            if isVisible {
                if windowController == nil {
                    windowController = LauncherWindowController(launcherManager: launcherManager)
                }
                windowController?.show()
            } else {
                windowController?.hide()
            }
        }
    }
}

