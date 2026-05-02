// swift-tools-version: 6.0
import PackageDescription

// MARK: - Shared swift settings

/// Swift settings applied uniformly to every target. Strict concurrency is the
/// project default; `ExistentialAny` warns where `any` is omitted on existential
/// types. Downstream sessions may extend this list, never weaken it.
let baseSwiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
    .enableExperimentalFeature("StrictConcurrency"),
]

// MARK: - Module catalog

/// One entry per library module: the target name, its source path under
/// `Sources/`, and any extra dependencies beyond `Core`. The order here mirrors
/// the dependency DAG (leaves first).
struct LibraryModule {
    let name: String
    let path: String
    let extraDependencies: [Target.Dependency]
}

let libraryModules: [LibraryModule] = [
    // Foundation
    LibraryModule(name: "Core", path: "Sources/Core", extraDependencies: []),

    // FileSystem providers
    LibraryModule(name: "FileSystemLocal", path: "Sources/FileSystem/Local", extraDependencies: []),
    LibraryModule(
        name: "FileSystemRemote",
        path: "Sources/FileSystem/Remote",
        extraDependencies: [
            .product(name: "Citadel", package: "Citadel"),
            .product(name: "SotoS3", package: "soto"),
        ]
    ),
    LibraryModule(
        name: "FileSystemArchive",
        path: "Sources/FileSystem/Archive",
        extraDependencies: [
            .product(name: "ZIPFoundation", package: "ZIPFoundation"),
        ]
    ),

    // Services
    LibraryModule(name: "ServicesCredentials", path: "Sources/Services/Credentials", extraDependencies: []),
    LibraryModule(name: "ServicesSettings", path: "Sources/Services/Settings", extraDependencies: []),
    LibraryModule(
        name: "ServicesLogging",
        path: "Sources/Services/Logging",
        extraDependencies: [
            .product(name: "Logging", package: "swift-log"),
        ]
    ),

    // Feature engines
    LibraryModule(name: "FeaturesOperations", path: "Sources/Features/Operations", extraDependencies: []),
    LibraryModule(name: "FeaturesSync", path: "Sources/Features/Sync", extraDependencies: []),
    LibraryModule(name: "FeaturesRename", path: "Sources/Features/Rename", extraDependencies: []),
    LibraryModule(name: "FeaturesPreview", path: "Sources/Features/Preview", extraDependencies: []),
    LibraryModule(name: "FeaturesGit", path: "Sources/Features/Git", extraDependencies: []),
    LibraryModule(name: "FeaturesUninstaller", path: "Sources/Features/Uninstaller", extraDependencies: []),

    // UI
    LibraryModule(name: "DesignSystem", path: "Sources/UI/DesignSystem", extraDependencies: []),
    LibraryModule(name: "UIPane", path: "Sources/UI/Pane", extraDependencies: []),
    LibraryModule(name: "UITabs", path: "Sources/UI/Tabs", extraDependencies: []),
    LibraryModule(
        name: "UISidebar",
        path: "Sources/UI/Sidebar",
        extraDependencies: [.target(name: "DesignSystem")]
    ),
    LibraryModule(name: "UIToolbar", path: "Sources/UI/Toolbar", extraDependencies: []),
    LibraryModule(name: "UITransfers", path: "Sources/UI/Transfers", extraDependencies: []),
    LibraryModule(name: "UISyncDialog", path: "Sources/UI/SyncDialog", extraDependencies: []),
    LibraryModule(name: "UIRenameDialog", path: "Sources/UI/RenameDialog", extraDependencies: []),
    LibraryModule(name: "UIConnectDialog", path: "Sources/UI/ConnectDialog", extraDependencies: []),
    LibraryModule(name: "UISettingsUI", path: "Sources/UI/SettingsUI", extraDependencies: [
        .target(name: "DesignSystem"),
        .target(name: "ServicesSettings"),
    ]),
    LibraryModule(name: "UIUninstallerUI", path: "Sources/UI/UninstallerUI", extraDependencies: []),
    LibraryModule(name: "UIMenus", path: "Sources/UI/Menus", extraDependencies: []),
    LibraryModule(name: "MainWindow", path: "Sources/UI/MainWindow", extraDependencies: []),
]

// MARK: - Helpers

func libraryProduct(_ name: String) -> Product {
    .library(name: name, targets: [name])
}

func libraryTarget(_ module: LibraryModule) -> Target {
    var dependencies: [Target.Dependency] = module.extraDependencies
    if module.name != "Core" {
        dependencies.insert(.target(name: "Core"), at: 0)
    }
    return .target(
        name: module.name,
        dependencies: dependencies,
        path: module.path,
        swiftSettings: baseSwiftSettings
    )
}

// MARK: - Test targets

struct TestTargetSpec {
    let name: String
    let path: String
    let dependencies: [Target.Dependency]
}

let testTargetSpecs: [TestTargetSpec] = [
    TestTargetSpec(
        name: "CoreTests",
        path: "Tests/CoreTests",
        dependencies: [.target(name: "Core")]
    ),
    TestTargetSpec(
        name: "FileSystemTests",
        path: "Tests/FileSystemTests",
        dependencies: [
            .target(name: "Core"),
            .target(name: "FileSystemLocal"),
            .target(name: "FileSystemRemote"),
            .target(name: "FileSystemArchive"),
        ]
    ),
    TestTargetSpec(
        name: "ServicesTests",
        path: "Tests/ServicesTests",
        dependencies: [
            .target(name: "Core"),
            .target(name: "ServicesCredentials"),
            .target(name: "ServicesSettings"),
            .target(name: "ServicesLogging"),
        ]
    ),
    TestTargetSpec(
        name: "FeaturesTests",
        path: "Tests/FeaturesTests",
        dependencies: [
            .target(name: "Core"),
            .target(name: "FeaturesOperations"),
            .target(name: "FeaturesSync"),
            .target(name: "FeaturesRename"),
            .target(name: "FeaturesPreview"),
            .target(name: "FeaturesGit"),
            .target(name: "FeaturesUninstaller"),
        ]
    ),
    TestTargetSpec(
        name: "UITests",
        path: "Tests/UITests",
        dependencies: [
            .target(name: "Core"),
            .target(name: "DesignSystem"),
            .target(name: "UIPane"),
            .target(name: "UITabs"),
            .target(name: "UISidebar"),
            .target(name: "UIToolbar"),
            .target(name: "UITransfers"),
            .target(name: "UISyncDialog"),
            .target(name: "UIRenameDialog"),
            .target(name: "UIConnectDialog"),
            .target(name: "UISettingsUI"),
            .target(name: "UIUninstallerUI"),
            .target(name: "UIMenus"),
            .target(name: "MainWindow"),
        ]
    ),
]

func testTarget(_ spec: TestTargetSpec) -> Target {
    .testTarget(
        name: spec.name,
        dependencies: spec.dependencies,
        path: spec.path,
        swiftSettings: baseSwiftSettings
    )
}

// MARK: - Package

let package = Package(
    name: "Stevedore",
    platforms: [.macOS(.v14)],
    products:
    libraryModules.map { libraryProduct($0.name) }
        + [.executable(name: "Stevedore", targets: ["Stevedore"])],
    dependencies: [
        .package(url: "https://github.com/orlandos-nl/Citadel.git", .upToNextMajor(from: "0.7.0")),
        .package(url: "https://github.com/soto-project/soto.git", .upToNextMajor(from: "7.0.0")),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", .upToNextMajor(from: "0.9.19")),
        .package(url: "https://github.com/apple/swift-log.git", .upToNextMajor(from: "1.6.0")),
    ],
    targets:
    libraryModules.map { libraryTarget($0) }
        + [
            .executableTarget(
                name: "Stevedore",
                dependencies: [
                    .target(name: "Core"),
                    .target(name: "MainWindow"),
                ],
                path: "App/Stevedore",
                swiftSettings: baseSwiftSettings
            ),
        ]
        + testTargetSpecs.map { testTarget($0) },
    swiftLanguageModes: [.v6]
)
