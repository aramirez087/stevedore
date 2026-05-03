import Core

/// Canonical registry of every app-level `Setting`.
///
/// All `Setting` instances must be declared here as `static let` properties.
/// Adding a setting anywhere else bypasses the uniqueness guarantee enforced
/// by `SettingsCatalogTests`.
public enum Settings {
    // MARK: - Appearance

    public static let theme = Setting<String>(key: "stevedore.theme", defaultValue: "system")

    // MARK: - Layout

    public static let dualPaneEnabled = Setting<Bool>(key: "stevedore.dualPaneEnabled", defaultValue: true)
    public static let sidebarWidth = Setting<Double>(key: "stevedore.sidebarWidth", defaultValue: 200.0)
    public static let splitRatio = Setting<Double>(key: "stevedore.splitRatio", defaultValue: 0.5)

    // MARK: - File display

    public static let showHiddenFiles = Setting<Bool>(key: "stevedore.showHiddenFiles", defaultValue: false)
    public static let showFileExtensions = Setting<Bool>(key: "stevedore.showFileExtensions", defaultValue: true)
    public static let byteSizeMode = Setting<String>(key: "stevedore.byteSizeMode", defaultValue: "decimal")
    public static let sortOrder = Setting<String>(key: "stevedore.sortOrder", defaultValue: "name")
    public static let sortAscending = Setting<Bool>(key: "stevedore.sortAscending", defaultValue: true)

    // MARK: - UI chrome

    public static let tabBarVisible = Setting<Bool>(key: "stevedore.tabBarVisible", defaultValue: true)
    public static let previewPanelVisible = Setting<Bool>(key: "stevedore.previewPanelVisible", defaultValue: false)
    public static let showStatusBar = Setting<Bool>(key: "stevedore.showStatusBar", defaultValue: true)

    // MARK: - Integrations

    public static let gitStatusEnabled = Setting<Bool>(key: "stevedore.gitStatusEnabled", defaultValue: true)
    public static let gitStatusBranch = Setting<Bool>(key: "stevedore.gitStatusBranch", defaultValue: true)
    public static let defaultEditorCommand = Setting<String>(key: "stevedore.defaultEditorCommand", defaultValue: "")

    // MARK: - Startup

    public static let startupBehavior = Setting<String>(
        key: "stevedore.startupBehavior",
        defaultValue: "lastWorkspace"
    )

    public static let defaultTerminalApp = Setting<String>(
        key: "stevedore.defaultTerminalApp",
        defaultValue: ""
    )

    // MARK: - Appearance (extended)

    public static let accentColor = Setting<String>(
        key: "stevedore.accentColor",
        defaultValue: "system"
    )

    public static let density = Setting<String>(
        key: "stevedore.density",
        defaultValue: "regular"
    )

    // MARK: - File display (extended)

    public static let dateFormat = Setting<String>(
        key: "stevedore.dateFormat",
        defaultValue: "relative"
    )

    // MARK: - Advanced

    public static let logLevel = Setting<String>(
        key: "stevedore.logLevel",
        defaultValue: "info"
    )

    public static let logRingBufferSize = Setting<Int>(
        key: "stevedore.logRingBufferSize",
        defaultValue: 500
    )

    public static let conflictPolicy = Setting<String>(
        key: "stevedore.conflictPolicy",
        defaultValue: "ask"
    )

    public static let transferConcurrencyCap = Setting<Int>(
        key: "stevedore.transferConcurrencyCap",
        defaultValue: 4
    )

    // MARK: - Key index (used by SettingsCatalogTests)

    /// All setting keys in declaration order. Used to assert uniqueness at test time.
    public static let allKeys: [String] = [
        theme.key,
        dualPaneEnabled.key,
        sidebarWidth.key,
        splitRatio.key,
        showHiddenFiles.key,
        showFileExtensions.key,
        byteSizeMode.key,
        sortOrder.key,
        sortAscending.key,
        tabBarVisible.key,
        previewPanelVisible.key,
        showStatusBar.key,
        gitStatusEnabled.key,
        gitStatusBranch.key,
        defaultEditorCommand.key,
        startupBehavior.key,
        defaultTerminalApp.key,
        accentColor.key,
        density.key,
        dateFormat.key,
        logLevel.key,
        logRingBufferSize.key,
        conflictPolicy.key,
        transferConcurrencyCap.key,
    ]
}
