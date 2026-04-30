import Core

/// Marker namespace for the `ServicesSettings` module. Replaced once the
/// `UserDefaults`-backed `SettingsStore` lands in a downstream settings
/// session.
public enum ServicesSettingsModule {
    public static let moduleName: String = "ServicesSettings"
}
