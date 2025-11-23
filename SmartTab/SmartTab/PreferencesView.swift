import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine

class HotkeyRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var recordedHotkey: HotkeyConfig?
    private var monitor: Any?
    
    func startRecording() {
        isRecording = true
        recordedHotkey = nil
        
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isRecording else { return event }
            
            let keyCode = event.keyCode
            let flags = event.modifierFlags
            
            // Don't allow just modifier keys (54-57 are modifier key codes)
            if keyCode >= 54 && keyCode <= 57 {
                return event
            }
            
            let newConfig = HotkeyConfig(
                keyCode: keyCode,
                command: flags.contains(.command),
                shift: flags.contains(.shift),
                option: flags.contains(.option),
                control: flags.contains(.control)
            )
            
            // Require at least one modifier
            if newConfig.command || newConfig.shift || newConfig.option || newConfig.control {
                DispatchQueue.main.async {
                    self.recordedHotkey = newConfig
                    self.isRecording = false
                }
                self.stopRecording()
                return nil // Consume the event
            }
            
            return event
        }
    }
    
    func stopRecording() {
        isRecording = false
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
    
    deinit {
        stopRecording()
    }
}

struct PreferencesView: View {
    @ObservedObject var configManager: ButtonConfigManager
    @ObservedObject var launcherManager: LauncherManager
    @StateObject private var hotkeyRecorder = HotkeyRecorder()
    @State private var selectedTab = 0
    @State private var selectedButton: ButtonConfig?
    @State private var showingFilePicker = false
    @State private var filePickerType: ButtonConfig.ActionType = .launchApp
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("SmartTab Preferences")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Done") {
                    NSApplication.shared.keyWindow?.close()
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Hotkey Settings Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Global Hotkey")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 12)
                
                HStack {
                    Text("Current hotkey:")
                        .foregroundColor(.secondary)
                    Text(configManager.hotkeyConfig.displayString())
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    if hotkeyRecorder.isRecording {
                        Button("Cancel") {
                            hotkeyRecorder.stopRecording()
                        }
                        .buttonStyle(.bordered)
                        
                        Text("Press new hotkey...")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    } else {
                        Button("Reassign") {
                            hotkeyRecorder.startRecording()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            HStack(spacing: 0) {
                // Left sidebar - button list
                VStack(alignment: .leading, spacing: 0) {
                    Text("Buttons")
                        .font(.headline)
                        .padding()
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            // Show all buttons from all tabs
                            ForEach(configManager.buttons.flatMap { $0 }) { button in
                                Button(action: {
                                    selectedButton = button
                                }) {
                                    HStack {
                                        Text(button.key)
                                            .font(.system(.body, design: .monospaced))
                                            .frame(width: 30)
                                        Text(button.label)
                                        Spacer()
                                        if button.actionType != .none {
                                            Image(systemName: button.actionType == .launchApp ? "app" : "folder")
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(selectedButton?.id == button.id ? Color.accentColor.opacity(0.2) : Color.clear)
                                    .cornerRadius(4)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                }
                .frame(width: 250)
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Right side - editor
                if let button = selectedButton {
                    ButtonEditorView(
                        button: button,
                        configManager: configManager,
                        onSave: { updatedButton in
                            configManager.updateButton(config: updatedButton)
                            selectedButton = updatedButton
                        }
                    )
                    .frame(maxWidth: .infinity)
                } else {
                    VStack {
                        Text("Select a button to edit")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(width: 700, height: 500)
        .onChange(of: hotkeyRecorder.recordedHotkey) { oldValue, newValue in
            if let newValue = newValue {
                configManager.hotkeyConfig = newValue
            }
        }
    }
    
    func findTabIndex(for button: ButtonConfig) -> Int? {
        for (index, tab) in configManager.buttons.enumerated() {
            if tab.contains(where: { $0.id == button.id }) {
                return index
            }
        }
        return nil
    }
    
    func findButtonIndex(for button: ButtonConfig, in tabIndex: Int) -> Int? {
        return configManager.buttons[tabIndex].firstIndex(where: { $0.id == button.id })
    }
}

struct ButtonEditorView: View {
    let button: ButtonConfig
    @ObservedObject var configManager: ButtonConfigManager
    let onSave: (ButtonConfig) -> Void
    
    @State private var label: String
    @State private var actionType: ButtonConfig.ActionType
    @State private var path: String
    @State private var showingFilePicker = false
    
    init(button: ButtonConfig, configManager: ButtonConfigManager, onSave: @escaping (ButtonConfig) -> Void) {
        self.button = button
        self.configManager = configManager
        self.onSave = onSave
        _label = State(initialValue: button.label)
        _actionType = State(initialValue: button.actionType)
        _path = State(initialValue: button.path)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Edit Button: \(button.key)")
                .font(.title3)
                .fontWeight(.semibold)
                .padding()
            
            Form {
                Section {
                    TextField("Label", text: $label)
                } header: {
                    Text("Display Label")
                }
                
                Section {
                    Picker("Action", selection: $actionType) {
                        Text("None").tag(ButtonConfig.ActionType.none)
                        Text("Launch App").tag(ButtonConfig.ActionType.launchApp)
                        Text("Open Folder").tag(ButtonConfig.ActionType.openFolder)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Action Type")
                }
                
                if actionType != .none {
                    Section {
                        HStack {
                            TextField("Path", text: $path)
                            Button("Browse...") {
                                showingFilePicker = true
                            }
                        }
                    } header: {
                        Text(actionType == .launchApp ? "Application Path" : "Folder Path")
                    }
                }
            }
            .padding()
            
            HStack {
                Spacer()
                Button("Save") {
                    let updatedButton = ButtonConfig(
                        id: button.id,
                        key: button.key,
                        label: label,
                        actionType: actionType,
                        path: path
                    )
                    onSave(updatedButton)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .sheet(isPresented: $showingFilePicker) {
            FilePickerView(
                actionType: actionType,
                selectedPath: $path
            )
        }
    }
}

struct FilePickerView: View {
    let actionType: ButtonConfig.ActionType
    @Binding var selectedPath: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        if actionType == .launchApp {
            AppPickerView(selectedPath: $selectedPath, dismiss: dismiss)
        } else {
            FolderPickerView(selectedPath: $selectedPath, dismiss: dismiss)
        }
    }
}

struct AppPickerView: View {
    @Binding var selectedPath: String
    let dismiss: DismissAction
    
    var body: some View {
        VStack {
            Text("Select Application")
                .font(.headline)
                .padding()
            
            Button("Choose Application...") {
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                panel.canChooseFiles = true
                panel.allowedContentTypes = [.application]
                panel.directoryURL = URL(fileURLWithPath: "/Applications")
                
                if panel.runModal() == .OK {
                    if let url = panel.url {
                        selectedPath = url.path
                        dismiss()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .frame(width: 400, height: 200)
    }
}

struct FolderPickerView: View {
    @Binding var selectedPath: String
    let dismiss: DismissAction
    
    var body: some View {
        VStack {
            Text("Select Folder")
                .font(.headline)
                .padding()
            
            Button("Choose Folder...") {
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory())
                
                if panel.runModal() == .OK {
                    if let url = panel.url {
                        selectedPath = url.path
                        dismiss()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .frame(width: 400, height: 200)
    }
}

