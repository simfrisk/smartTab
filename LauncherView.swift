import SwiftUI

struct LauncherView: View {
    @ObservedObject var launcherManager: LauncherManager
    @State private var selectedTab = 0
    @State private var buttons: [[LauncherButton]] = [
        // Tab 1 - Default tab with letters Q-P
        [
            LauncherButton(key: "Q", label: "Quick", action: .openFolder(path: NSHomeDirectory())),
            LauncherButton(key: "W", label: "Web", action: .none),
            LauncherButton(key: "E", label: "Edit", action: .none),
            LauncherButton(key: "R", label: "Run", action: .none),
            LauncherButton(key: "T", label: "Terminal", action: .launchApp(path: "/System/Applications/Utilities/Terminal.app")),
            LauncherButton(key: "Y", label: "Y", action: .none),
            LauncherButton(key: "U", label: "Utilities", action: .openFolder(path: "/System/Applications/Utilities")),
            LauncherButton(key: "I", label: "Info", action: .none),
            LauncherButton(key: "O", label: "Open", action: .none),
            LauncherButton(key: "P", label: "Preferences", action: .launchApp(path: "/System/Applications/System Preferences.app")),
        ],
        // Tab 2 - Letters A-L
        [
            LauncherButton(key: "A", label: "Apps", action: .openFolder(path: "/Applications")),
            LauncherButton(key: "S", label: "Safari", action: .launchApp(path: "/Applications/Safari.app")),
            LauncherButton(key: "D", label: "Downloads", action: .openFolder(path: NSHomeDirectory() + "/Downloads")),
            LauncherButton(key: "F", label: "Finder", action: .launchApp(path: "/System/Library/CoreServices/Finder.app")),
            LauncherButton(key: "G", label: "G", action: .none),
            LauncherButton(key: "H", label: "Home", action: .openFolder(path: NSHomeDirectory())),
            LauncherButton(key: "J", label: "J", action: .none),
            LauncherButton(key: "K", label: "K", action: .none),
            LauncherButton(key: "L", label: "Launch", action: .none),
            LauncherButton(key: ";", label: ";", action: .none),
        ],
        // Tab 3 - Letters Z-M
        [
            LauncherButton(key: "Z", label: "Z", action: .none),
            LauncherButton(key: "X", label: "X", action: .none),
            LauncherButton(key: "C", label: "Calculator", action: .launchApp(path: "/System/Applications/Calculator.app")),
            LauncherButton(key: "V", label: "V", action: .none),
            LauncherButton(key: "B", label: "B", action: .none),
            LauncherButton(key: "N", label: "Notes", action: .launchApp(path: "/System/Applications/Notes.app")),
            LauncherButton(key: "M", label: "Mail", action: .launchApp(path: "/System/Applications/Mail.app")),
            LauncherButton(key: ",", label: ",", action: .none),
            LauncherButton(key: ".", label: ".", action: .none),
            LauncherButton(key: "/", label: "/", action: .none),
        ]
    ]
    
    let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            HStack(spacing: 0) {
                ForEach(0..<min(buttons.count, 10)) { index in
                    Button(action: {
                        selectedTab = index
                    }) {
                        Text("\(index + 1)")
                            .font(.system(size: 14, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(selectedTab == index ? Color.accentColor : Color.clear)
                            .foregroundColor(selectedTab == index ? .white : .primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Button grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(buttons[selectedTab]) { button in
                        LauncherButtonView(button: button)
                            .onTapGesture {
                                executeAction(button.action)
                            }
                    }
                }
                .padding(16)
            }
            .frame(width: 500, height: 400)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 20)
        .frame(width: 500, height: 480)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
        }
        .background(
            KeyHandler(launcherManager: launcherManager, selectedTab: $selectedTab, buttons: $buttons)
                .frame(width: 0, height: 0)
        )
    }
}

struct KeyHandler: NSViewRepresentable {
    let launcherManager: LauncherManager
    @Binding var selectedTab: Int
    @Binding var buttons: [[LauncherButton]]
    
    func makeNSView(context: Context) -> KeyHandlingView {
        let view = KeyHandlingView()
        view.launcherManager = launcherManager
        view.selectedTab = $selectedTab
        view.buttons = $buttons
        return view
    }
    
    func updateNSView(_ nsView: KeyHandlingView, context: Context) {
        nsView.launcherManager = launcherManager
        nsView.selectedTab = $selectedTab
        nsView.buttons = $buttons
    }
}

class KeyHandlingView: NSView {
    var launcherManager: LauncherManager?
    var selectedTab: Binding<Int>?
    var buttons: Binding<[[LauncherButton]]>?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        guard let selectedTab = selectedTab?.wrappedValue,
              let buttons = buttons?.wrappedValue else { return }
        
        let key = event.charactersIgnoringModifiers?.uppercased() ?? ""
        
        // Handle tab switching with numbers 1-0
        if let number = Int(key), number >= 1 && number <= 10 {
            if number <= buttons.count {
                self.selectedTab?.wrappedValue = number - 1
                return
            }
        }
        
        // Handle button activation
        if let button = buttons[selectedTab].first(where: { $0.key.uppercased() == key.uppercased() }) {
            executeAction(button.action)
        }
        
        // ESC to close
        if event.keyCode == 53 {
            launcherManager?.isVisible = false
        }
    }
    
    func executeAction(_ action: LauncherAction) {
        switch action {
        case .none:
            break
        case .launchApp(let path):
            launchApplication(path: path)
        case .openFolder(let path):
            openFolder(path: path)
        }
    }
    
    func launchApplication(path: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
        launcherManager?.isVisible = false
    }
    
    func openFolder(path: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
        launcherManager?.isVisible = false
    }
    
}

struct LauncherButton: Identifiable {
    let id = UUID()
    let key: String
    let label: String
    var action: LauncherAction
}

enum LauncherAction {
    case none
    case launchApp(path: String)
    case openFolder(path: String)
}

struct LauncherButtonView: View {
    let button: LauncherButton
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 4) {
            Text(button.key)
                .font(.system(size: 24, weight: .bold))
            Text(button.label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(width: 80, height: 80)
        .background(isHovered ? Color.accentColor.opacity(0.2) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

