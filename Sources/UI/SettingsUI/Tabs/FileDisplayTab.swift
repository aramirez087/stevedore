import Core
import ServicesSettings
import SwiftUI

@MainActor
struct FileDisplayTab: View {
    @State private var showHiddenFiles: SettingBinding<Bool>
    @State private var byteSizeMode: SettingBinding<String>
    @State private var dateFormat: SettingBinding<String>
    @State private var sortOrder: SettingBinding<String>
    @State private var sortAscending: SettingBinding<Bool>

    init(store: any SettingsStore) {
        _showHiddenFiles = State(wrappedValue: SettingBinding(
            setting: Settings.showHiddenFiles, store: store
        ))
        _byteSizeMode = State(wrappedValue: SettingBinding(
            setting: Settings.byteSizeMode, store: store
        ))
        _dateFormat = State(wrappedValue: SettingBinding(
            setting: Settings.dateFormat, store: store
        ))
        _sortOrder = State(wrappedValue: SettingBinding(
            setting: Settings.sortOrder, store: store
        ))
        _sortAscending = State(wrappedValue: SettingBinding(
            setting: Settings.sortAscending, store: store
        ))
    }

    var body: some View {
        Form {
            Section("Visibility") {
                Toggle("Show Hidden Files", isOn: self.showHiddenFiles.binding)
            }
            Section("Formatting") {
                Picker("File Size Display", selection: self.byteSizeMode.binding) {
                    Text("Binary (KiB, MiB)").tag("binary")
                    Text("Decimal (KB, MB)").tag("decimal")
                }
                Picker("Date Format", selection: self.dateFormat.binding) {
                    Text("Relative").tag("relative")
                    Text("Absolute").tag("absolute")
                }
            }
            Section("Default Sort") {
                Picker("Sort By", selection: self.sortOrder.binding) {
                    Text("Name").tag("name")
                    Text("Size").tag("size")
                    Text("Date Modified").tag("modified")
                    Text("Kind").tag("kind")
                    Text("Extension").tag("extension")
                }
                Toggle("Ascending", isOn: self.sortAscending.binding)
            }
        }
        .formStyle(.grouped)
        .task {
            self.showHiddenFiles.start()
            self.byteSizeMode.start()
            self.dateFormat.start()
            self.sortOrder.start()
            self.sortAscending.start()
        }
        .onDisappear {
            self.showHiddenFiles.stop()
            self.byteSizeMode.stop()
            self.dateFormat.stop()
            self.sortOrder.stop()
            self.sortAscending.stop()
        }
    }
}
