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
    @StateObject private var secondaryHotkeyRecorder = HotkeyRecorder()
    @State private var selectedTab = 0
    @State private var selectedButton: ButtonConfig?
    @State private var showingFilePicker = false
    @State private var filePickerType: ButtonConfig.ActionType = .launchApp
    @State private var showingImportError = false
    @State private var showingExportSuccess = false
    @State private var showingImportSuccess = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("SmartTab Preferences")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                HStack(spacing: 8) {
                    Button("Export Config") {
                        if let url = configManager.exportConfigToFile() {
                            showingExportSuccess = true
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Import Config") {
                        if configManager.importConfigFromFile() {
                            showingImportSuccess = true
                        } else {
                            errorMessage = "Failed to import configuration. Please ensure the file is a valid SmartTab configuration."
                            showingImportError = true
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Done") {
                        NSApplication.shared.keyWindow?.close()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .alert("Export Successful", isPresented: $showingExportSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Configuration exported successfully!")
            }
            .alert("Import Successful", isPresented: $showingImportSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Configuration imported successfully! The launcher will use the new settings.")
            }
            .alert("Import Failed", isPresented: $showingImportError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            
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

            // Secondary Hotkey Settings Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Secondary Hotkey (Optional)")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 12)

                HStack {
                    Text("Current hotkey:")
                        .foregroundColor(.secondary)

                    if let secondaryConfig = configManager.secondaryHotkeyConfig {
                        Text(secondaryConfig.displayString())
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(4)
                    } else {
                        Text("Not set")
                            .foregroundColor(.secondary)
                            .italic()
                    }

                    Spacer()

                    if configManager.secondaryHotkeyConfig != nil {
                        Button("Clear") {
                            configManager.clearSecondaryHotkey()
                        }
                        .buttonStyle(.bordered)
                    }

                    if secondaryHotkeyRecorder.isRecording {
                        Button("Cancel") {
                            secondaryHotkeyRecorder.stopRecording()
                        }
                        .buttonStyle(.bordered)

                        Text("Press new hotkey...")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    } else {
                        Button(configManager.secondaryHotkeyConfig == nil ? "Set Shortcut" : "Reassign") {
                            secondaryHotkeyRecorder.startRecording()
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
                // Left side - visual keyboard
                VStack(alignment: .leading, spacing: 0) {
                    Text("Keyboard Layout")
                        .font(.headline)
                        .padding()
                    
                    ScrollView {
                        KeyboardLayoutView(
                            configManager: configManager,
                            selectedButton: $selectedButton
                        )
                        .padding()
                    }
                }
                .frame(width: 850)
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Right side - editor
                VStack {
                    if let button = selectedButton {
                        ButtonEditorView(
                            button: button,
                            configManager: configManager,
                            onSave: { updatedButton in
                                configManager.updateButton(config: updatedButton)
                                selectedButton = updatedButton
                            }
                        )
                    } else {
                        Text("Click on a key to configure it")
                            .foregroundColor(.secondary)
                    }
                }
                .frame(minWidth: 500, maxWidth: 500)
                .frame(maxHeight: .infinity)
            }
        }
        .frame(minWidth: 1400, minHeight: 700)
        .onChange(of: hotkeyRecorder.recordedHotkey) { oldValue, newValue in
            if let newValue = newValue {
                configManager.hotkeyConfig = newValue
            }
        }
        .onChange(of: secondaryHotkeyRecorder.recordedHotkey) { oldValue, newValue in
            if let newValue = newValue {
                configManager.secondaryHotkeyConfig = newValue
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
                        VStack(alignment: .leading, spacing: 8) {
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
        .onChange(of: button.id) { oldValue, newValue in
            // Update state when button changes
            label = button.label
            actionType = button.actionType
            path = button.path
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

struct KeyboardLayoutView: View {
    @ObservedObject var configManager: ButtonConfigManager
    @Binding var selectedButton: ButtonConfig?
    
    // Flatten all buttons from all tabs into a single array
    var allButtons: [ButtonConfig] {
        configManager.buttons.flatMap { $0 }
    }
    
    var body: some View {
        VStack(spacing: 10) {
            // Row 1: Q-P (10 buttons) - gap between T and Y
            HStack(spacing: 6) {
                ForEach(Array(allButtons.prefix(5).enumerated()), id: \.element.id) { index, button in
                    KeyboardKeyView(
                        button: button,
                        isSelected: selectedButton?.id == button.id,
                        onTap: {
                            selectedButton = button
                        }
                    )
                }
                Spacer().frame(width: 24) // Gap for split keyboard
                ForEach(Array(allButtons.dropFirst(5).prefix(5)), id: \.id) { button in
                    KeyboardKeyView(
                        button: button,
                        isSelected: selectedButton?.id == button.id,
                        onTap: {
                            selectedButton = button
                        }
                    )
                }
            }
            
            // Row 2: A-L, ; (10 buttons) - gap between G and H
            HStack(spacing: 6) {
                ForEach(Array(allButtons.dropFirst(10).prefix(5).enumerated()), id: \.element.id) { index, button in
                    KeyboardKeyView(
                        button: button,
                        isSelected: selectedButton?.id == button.id,
                        onTap: {
                            selectedButton = button
                        }
                    )
                }
                Spacer().frame(width: 24) // Gap for split keyboard
                ForEach(Array(allButtons.dropFirst(15).prefix(5)), id: \.id) { button in
                    KeyboardKeyView(
                        button: button,
                        isSelected: selectedButton?.id == button.id,
                        onTap: {
                            selectedButton = button
                        }
                    )
                }
            }
            
            // Row 3: Z-M, comma, period, dash (10 buttons) - gap between B and N
            HStack(spacing: 6) {
                ForEach(Array(allButtons.dropFirst(20).prefix(5).enumerated()), id: \.element.id) { index, button in
                    KeyboardKeyView(
                        button: button,
                        isSelected: selectedButton?.id == button.id,
                        onTap: {
                            selectedButton = button
                        }
                    )
                }
                Spacer().frame(width: 24) // Gap for split keyboard
                ForEach(Array(allButtons.dropFirst(25).prefix(5)), id: \.id) { button in
                    KeyboardKeyView(
                        button: button,
                        isSelected: selectedButton?.id == button.id,
                        onTap: {
                            selectedButton = button
                        }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }
}

struct KeyboardKeyView: View {
    let button: ButtonConfig
    let isSelected: Bool
    let onTap: () -> Void
    @State private var isHovered = false
    @State private var appIcon: NSImage?
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                // Key letter at top
                Text(button.key)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                
                // Icon or label in center
                if let icon = appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)
                } else if button.actionType != .none {
                    // Show action type icon if no app icon
                    Image(systemName: button.actionType == .launchApp ? "app" : "folder")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                } else {
                    // Empty space for unassigned
                    Spacer().frame(height: 18)
                }
                
                // Label at bottom
                if !button.label.isEmpty && button.label != button.key {
                    Text(button.label)
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity)
                } else {
                    Spacer().frame(height: 10)
                }
            }
            .frame(width: 55, height: 75)
            .padding(5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.3) : 
                          (isHovered ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor : Color.accentColor.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear {
            loadAppIcon()
        }
        .onChange(of: button.path) { oldValue, newValue in
            loadAppIcon()
        }
        .onChange(of: button.actionType) { oldValue, newValue in
            loadAppIcon()
        }
    }
    
    func loadAppIcon() {
        // Extract app path from action
        if button.actionType == .launchApp {
            // Check if file exists before getting icon
            if FileManager.default.fileExists(atPath: button.path) {
                appIcon = NSWorkspace.shared.icon(forFile: button.path)
            } else {
                appIcon = nil
            }
        } else {
            appIcon = nil
        }
    }
}

