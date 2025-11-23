import SwiftUI

struct StatusBarSetupView: View {
    let statusBarManager: StatusBarManager
    let launcherManager: LauncherManager
    let configManager: ButtonConfigManager
    let openPreferences: () -> Void
    
    var body: some View {
        EmptyView()
            .task {
                // Set up status bar when this view appears
                // This should run when the Settings scene initializes
                statusBarManager.setup(
                    launcherManager: launcherManager,
                    configManager: configManager,
                    openPreferences: openPreferences
                )
                print("Status bar setup called")
            }
            .onAppear {
                // Backup: also try on appear
                statusBarManager.setup(
                    launcherManager: launcherManager,
                    configManager: configManager,
                    openPreferences: openPreferences
                )
                print("Status bar setup called (onAppear)")
            }
    }
}

