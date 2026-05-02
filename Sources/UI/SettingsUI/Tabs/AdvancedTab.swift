import Core
import ServicesSettings
import SwiftUI

@MainActor
struct AdvancedTab: View {
    @State private var logLevel: SettingBinding<String>
    @State private var logRingBufferSize: SettingBinding<Int>
    @State private var conflictPolicy: SettingBinding<String>
    @State private var transferConcurrencyCap: SettingBinding<Int>

    init(store: any SettingsStore) {
        _logLevel = State(wrappedValue: SettingBinding(setting: Settings.logLevel, store: store))
        _logRingBufferSize = State(wrappedValue: SettingBinding(
            setting: Settings.logRingBufferSize, store: store
        ))
        _conflictPolicy = State(wrappedValue: SettingBinding(setting: Settings.conflictPolicy, store: store))
        _transferConcurrencyCap = State(wrappedValue: SettingBinding(
            setting: Settings.transferConcurrencyCap, store: store
        ))
    }

    var body: some View {
        Form {
            Section("Logging") {
                Picker("Log Level", selection: self.logLevel.binding) {
                    Text("Debug").tag("debug")
                    Text("Info").tag("info")
                    Text("Warning").tag("warning")
                    Text("Error").tag("error")
                }
                Stepper(
                    "Log Buffer Size: \(self.logRingBufferSize.value)",
                    value: self.logRingBufferSize.binding,
                    in: 100 ... 5000,
                    step: 100
                )
            }
            Section("Transfers") {
                Picker("Conflict Policy", selection: self.conflictPolicy.binding) {
                    Text("Ask").tag("ask")
                    Text("Replace").tag("replace")
                    Text("Skip").tag("skip")
                    Text("Rename").tag("rename")
                }
                Stepper(
                    "Max Concurrent Transfers: \(self.transferConcurrencyCap.value)",
                    value: self.transferConcurrencyCap.binding,
                    in: 1 ... 16
                )
            }
        }
        .formStyle(.grouped)
        .task {
            self.logLevel.start()
            self.logRingBufferSize.start()
            self.conflictPolicy.start()
            self.transferConcurrencyCap.start()
        }
        .onDisappear {
            self.logLevel.stop()
            self.logRingBufferSize.stop()
            self.conflictPolicy.stop()
            self.transferConcurrencyCap.stop()
        }
    }
}
