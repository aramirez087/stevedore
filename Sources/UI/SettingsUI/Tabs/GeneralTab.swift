import Core
import DesignSystem
import ServicesSettings
import SwiftUI

@MainActor
struct GeneralTab: View {
    @State private var startupBehavior: SettingBinding<String>
    @State private var defaultEditorCommand: SettingBinding<String>
    @State private var defaultTerminalApp: SettingBinding<String>
    @State private var dualPaneEnabled: SettingBinding<Bool>

    init(store: any SettingsStore) {
        _startupBehavior = State(wrappedValue: SettingBinding(
            setting: Settings.startupBehavior, store: store
        ))
        _defaultEditorCommand = State(wrappedValue: SettingBinding(
            setting: Settings.defaultEditorCommand, store: store
        ))
        _defaultTerminalApp = State(wrappedValue: SettingBinding(
            setting: Settings.defaultTerminalApp, store: store
        ))
        _dualPaneEnabled = State(wrappedValue: SettingBinding(
            setting: Settings.dualPaneEnabled, store: store
        ))
    }

    var body: some View {
        Form {
            Section("Startup") {
                Picker("On Launch", selection: self.startupBehavior.binding) {
                    Text("Restore Last Workspace").tag("lastWorkspace")
                    Text("Open Blank Window").tag("blank")
                }
            }
            Section("Editor & Terminal") {
                SDTextField("Editor Command", text: self.defaultEditorCommand.binding)
                SDTextField("Terminal App", text: self.defaultTerminalApp.binding)
            }
            Section("Layout") {
                Toggle("Enable Dual Pane", isOn: self.dualPaneEnabled.binding)
            }
        }
        .formStyle(.grouped)
        .task {
            self.startupBehavior.start()
            self.defaultEditorCommand.start()
            self.defaultTerminalApp.start()
            self.dualPaneEnabled.start()
        }
        .onDisappear {
            self.startupBehavior.stop()
            self.defaultEditorCommand.stop()
            self.defaultTerminalApp.stop()
            self.dualPaneEnabled.stop()
        }
    }
}
