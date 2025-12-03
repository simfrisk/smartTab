import Foundation
import Combine
import AppKit

struct HotkeyConfig: Codable, Equatable {
    var keyCode: UInt16
    var command: Bool
    var shift: Bool
    var option: Bool
    var control: Bool
    
    init(keyCode: UInt16 = 16, command: Bool = true, shift: Bool = true, option: Bool = false, control: Bool = false) {
        self.keyCode = keyCode
        self.command = command
        self.shift = shift
        self.option = option
        self.control = control
    }
    
    func matches(event: NSEvent) -> Bool {
        // First check if the key code matches
        guard event.keyCode == keyCode else {
            return false
        }
        
        // Get modifier flags and filter to only the ones we care about
        let flags = event.modifierFlags
        let hasCommand = flags.contains(.command)
        let hasShift = flags.contains(.shift)
        let hasOption = flags.contains(.option)
        let hasControl = flags.contains(.control)
        
        // Check if the modifier flags match exactly what we expect
        return hasCommand == command && 
               hasShift == shift && 
               hasOption == option && 
               hasControl == control
    }
    
    func displayString() -> String {
        var parts: [String] = []
        if command { parts.append("⌘") }
        if shift { parts.append("⇧") }
        if option { parts.append("⌥") }
        if control { parts.append("⌃") }
        
        // Convert keyCode to character
        let keyString = keyCodeToString(keyCode)
        parts.append(keyString)
        
        return parts.joined(separator: "+")
    }
    
    private func keyCodeToString(_ keyCode: UInt16) -> String {
        // Common key codes
        let keyMap: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
            11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 31: "O", 32: "U",
            34: "I", 35: "P", 37: "L", 38: "J", 40: "K", 45: "N", 46: "M",
            50: "`", 36: "Return", 48: "Tab", 51: "Delete", 53: "Esc",
            123: "←", 124: "→", 125: "↓", 126: "↑",
            49: "Space", 24: "=", 27: "-", 33: "[", 30: "]", 41: ";", 43: ",", 47: ".", 44: "/"
        ]
        return keyMap[keyCode] ?? "Key(\(keyCode))"
    }
}

struct ButtonConfig: Codable, Identifiable {
    let id: UUID
    let key: String
    var label: String
    var actionType: ActionType
    var path: String
    
    // Custom init for creating mutable copies
    init(id: UUID? = nil, key: String, label: String, actionType: ActionType = .none, path: String = "") {
        self.id = id ?? UUID()
        self.key = key
        self.label = label
        self.actionType = actionType
        self.path = path
    }
    
    enum ActionType: String, Codable {
        case none
        case launchApp
        case openFolder
    }
    
    init(key: String, label: String, actionType: ActionType = .none, path: String = "") {
        self.id = UUID()
        self.key = key
        self.label = label
        self.actionType = actionType
        self.path = path
    }
    
    func toLauncherAction() -> LauncherAction {
        switch actionType {
        case .none:
            return .none
        case .launchApp:
            return .launchApp(path: path)
        case .openFolder:
            return .openFolder(path: path)
        }
    }
}

class ButtonConfigManager: ObservableObject {
    @Published var buttons: [[ButtonConfig]] = []
    @Published var hotkeyConfig: HotkeyConfig {
        didSet {
            saveHotkeyConfig()
        }
    }
    private let defaults = UserDefaults.standard
    private let buttonsKey = "SmartTabButtonConfigs"
    private let hotkeyKey = "SmartTabHotkeyConfig"
    
    init() {
        if let data = defaults.data(forKey: hotkeyKey),
           let decoded = try? JSONDecoder().decode(HotkeyConfig.self, from: data) {
            hotkeyConfig = decoded
        } else {
            hotkeyConfig = HotkeyConfig(keyCode: 16, command: true, shift: true, option: false, control: false)
        }
        
        loadConfigurations()
        if buttons.isEmpty {
            createDefaultConfigurations()
        } else {
            migrateLayoutIfNeeded()
        }
    }
    
    func saveConfigurations() {
        if let encoded = try? JSONEncoder().encode(buttons) {
            defaults.set(encoded, forKey: buttonsKey)
            print("Saved button configurations")
        }
    }
    
    func loadConfigurations() {
        if let data = defaults.data(forKey: buttonsKey),
           let decoded = try? JSONDecoder().decode([[ButtonConfig]].self, from: data) {
            buttons = decoded
            print("Loaded button configurations")
        }
    }
    
    func createDefaultConfigurations() {
        buttons = Self.defaultLayout.map { row in
            row.map { definition in
                makeButton(from: definition)
            }
        }
        saveConfigurations()
    }
    
    private func migrateLayoutIfNeeded() {
        var updatedButtons = buttons
        var mutated = false
        
        if updatedButtons.count < Self.defaultLayout.count {
            for index in updatedButtons.count..<Self.defaultLayout.count {
                updatedButtons.append(Self.defaultLayout[index].map { makeButton(from: $0) })
            }
            mutated = true
        }
        
        for rowIndex in 0..<min(updatedButtons.count, Self.defaultLayout.count) {
            let row = updatedButtons[rowIndex]
            let defaults = Self.defaultLayout[rowIndex]
            
            var buttonsByKey = [String: ButtonConfig]()
            for button in row {
                buttonsByKey[button.key.uppercased()] = button
            }
            
            for definition in defaults {
                let key = definition.key.uppercased()
                if buttonsByKey[key] == nil {
                    buttonsByKey[key] = makeButton(from: definition)
                    mutated = true
                }
            }
            
            let orderedRow = defaults.compactMap { buttonsByKey[$0.key.uppercased()] }
            let defaultKeys = Set(defaults.map { $0.key.uppercased() })
            let extras = row.filter { !defaultKeys.contains($0.key.uppercased()) }
            let newRow = orderedRow + extras
            
            if row.map(\.id) != newRow.map(\.id) {
                mutated = true
            }
            
            updatedButtons[rowIndex] = newRow
        }
        
        if mutated {
            buttons = updatedButtons
            saveConfigurations()
            print("Migrated configuration to 10-10-9 layout")
        } else {
            buttons = updatedButtons
        }
    }
    
    func updateButton(at tabIndex: Int, buttonIndex: Int, label: String, actionType: ButtonConfig.ActionType, path: String) {
        guard tabIndex < buttons.count, buttonIndex < buttons[tabIndex].count else { return }
        let oldConfig = buttons[tabIndex][buttonIndex]
        buttons[tabIndex][buttonIndex] = ButtonConfig(
            id: oldConfig.id,
            key: oldConfig.key,
            label: label,
            actionType: actionType,
            path: path
        )
        saveConfigurations()
    }
    
    func updateButton(config: ButtonConfig) {
        for (tabIndex, tab) in buttons.enumerated() {
            if let buttonIndex = tab.firstIndex(where: { $0.id == config.id }) {
                buttons[tabIndex][buttonIndex] = config
                saveConfigurations()
                return
            }
        }
    }
    
    func saveHotkeyConfig() {
        if let encoded = try? JSONEncoder().encode(hotkeyConfig) {
            defaults.set(encoded, forKey: hotkeyKey)
            print("Saved hotkey configuration: \(hotkeyConfig.displayString())")
        }
    }
    
    private func makeButton(from definition: DefaultButtonDefinition) -> ButtonConfig {
        ButtonConfig(
            key: definition.key,
            label: definition.label,
            actionType: definition.actionType,
            path: definition.path
        )
    }
}

private extension ButtonConfigManager {
    struct DefaultButtonDefinition {
        let key: String
        let label: String
        let actionType: ButtonConfig.ActionType
        let path: String
    }
    
    static let defaultLayout: [[DefaultButtonDefinition]] = [
        [
            DefaultButtonDefinition(key: "Q", label: "Quick", actionType: .openFolder, path: NSHomeDirectory()),
            DefaultButtonDefinition(key: "W", label: "Web", actionType: .none, path: ""),
            DefaultButtonDefinition(key: "E", label: "Edit", actionType: .none, path: ""),
            DefaultButtonDefinition(key: "R", label: "Run", actionType: .none, path: ""),
            DefaultButtonDefinition(key: "T", label: "Terminal", actionType: .launchApp, path: "/System/Applications/Utilities/Terminal.app"),
            DefaultButtonDefinition(key: "Y", label: "Y", actionType: .none, path: ""),
            DefaultButtonDefinition(key: "U", label: "Utilities", actionType: .openFolder, path: "/System/Applications/Utilities"),
            DefaultButtonDefinition(key: "I", label: "Info", actionType: .none, path: ""),
            DefaultButtonDefinition(key: "O", label: "Open", actionType: .none, path: ""),
            DefaultButtonDefinition(key: "P", label: "Preferences", actionType: .launchApp, path: "/System/Applications/System Settings.app")
        ],
        [
            DefaultButtonDefinition(key: "A", label: "Apps", actionType: .openFolder, path: "/Applications"),
            DefaultButtonDefinition(key: "S", label: "Safari", actionType: .launchApp, path: "/Applications/Safari.app"),
            DefaultButtonDefinition(key: "D", label: "Downloads", actionType: .openFolder, path: NSHomeDirectory() + "/Downloads"),
            DefaultButtonDefinition(key: "F", label: "Chrome", actionType: .launchApp, path: "/Applications/Google Chrome.app"),
            DefaultButtonDefinition(key: "G", label: "G", actionType: .none, path: ""),
            DefaultButtonDefinition(key: "H", label: "Home", actionType: .openFolder, path: NSHomeDirectory()),
            DefaultButtonDefinition(key: "J", label: "J", actionType: .none, path: ""),
            DefaultButtonDefinition(key: "K", label: "K", actionType: .none, path: ""),
            DefaultButtonDefinition(key: "L", label: "Launch", actionType: .none, path: ""),
            DefaultButtonDefinition(key: ";", label: ";", actionType: .none, path: "")
        ],
        [
            DefaultButtonDefinition(key: "Z", label: "Z", actionType: .none, path: ""),
            DefaultButtonDefinition(key: "X", label: "X", actionType: .none, path: ""),
            DefaultButtonDefinition(key: "C", label: "Calculator", actionType: .launchApp, path: "/System/Applications/Calculator.app"),
            DefaultButtonDefinition(key: "V", label: "V", actionType: .none, path: ""),
            DefaultButtonDefinition(key: "B", label: "B", actionType: .none, path: ""),
            DefaultButtonDefinition(key: "N", label: "Notes", actionType: .launchApp, path: "/System/Applications/Notes.app"),
            DefaultButtonDefinition(key: "M", label: "Mail", actionType: .launchApp, path: "/System/Applications/Mail.app"),
            DefaultButtonDefinition(key: ",", label: ",", actionType: .none, path: ""),
            DefaultButtonDefinition(key: ".", label: ".", actionType: .none, path: ""),
            DefaultButtonDefinition(key: "-", label: "-", actionType: .none, path: "")
        ]
    ]
}

