import Core
import DesignSystem
import ServicesSettings
import SwiftUI

/// Content view for the macOS Preferences (`SwiftUI.Settings`) scene.
///
/// Inject from the app's composition root:
/// ```swift
/// Settings {
///     SettingsScene(store: appSettingsStore)
/// }
/// ```
public struct SettingsScene: View {
    private let store: any SettingsStore

    public init(store: any SettingsStore) {
        self.store = store
    }

    public var body: some View {
        TabView {
            GeneralTab(store: self.store)
                .tabItem { Label("General", systemImage: "gearshape") }
            AppearanceTab(store: self.store)
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            FileDisplayTab(store: self.store)
                .tabItem { Label("File Display", systemImage: "doc.text.magnifyingglass") }
            AdvancedTab(store: self.store)
                .tabItem { Label("Advanced", systemImage: "wrench.and.screwdriver") }
        }
        .frame(minWidth: 480, minHeight: 320)
    }
}
