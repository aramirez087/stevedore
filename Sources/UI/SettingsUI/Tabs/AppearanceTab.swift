import Core
import ServicesSettings
import SwiftUI

@MainActor
struct AppearanceTab: View {
    @State private var theme: SettingBinding<String>
    @State private var accentColor: SettingBinding<String>
    @State private var density: SettingBinding<String>

    init(store: any SettingsStore) {
        _theme = State(wrappedValue: SettingBinding(setting: Settings.theme, store: store))
        _accentColor = State(wrappedValue: SettingBinding(setting: Settings.accentColor, store: store))
        _density = State(wrappedValue: SettingBinding(setting: Settings.density, store: store))
    }

    var body: some View {
        Form {
            Section("Theme") {
                Picker("Appearance", selection: self.theme.binding) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                Picker("Accent Color", selection: self.accentColor.binding) {
                    Text("System").tag("system")
                    Text("Blue").tag("blue")
                    Text("Purple").tag("purple")
                    Text("Pink").tag("pink")
                    Text("Red").tag("red")
                    Text("Orange").tag("orange")
                    Text("Yellow").tag("yellow")
                    Text("Green").tag("green")
                    Text("Graphite").tag("graphite")
                }
            }
            Section("Layout Density") {
                Picker("Density", selection: self.density.binding) {
                    Text("Compact").tag("compact")
                    Text("Regular").tag("regular")
                }
            }
        }
        .formStyle(.grouped)
        .task {
            self.theme.start()
            self.accentColor.start()
            self.density.start()
        }
        .onDisappear {
            self.theme.stop()
            self.accentColor.stop()
            self.density.stop()
        }
    }
}
