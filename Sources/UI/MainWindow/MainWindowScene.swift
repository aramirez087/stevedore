import SwiftUI

/// The application's primary window scene.
///
/// Declares a `WindowGroup` with menu bar commands (Session 27 stub) and hosts
/// `MainWindowView` which composes the full dual-pane layout.
public struct MainWindowScene: Scene {
    private let model: MainWindowModel

    public init(model: MainWindowModel) {
        self.model = model
    }

    public var body: some Scene {
        WindowGroup("Stevedore", id: "main") {
            MainWindowView(model: model)
        }
        .commands { AppCommands() }
        .defaultSize(width: 1200, height: 750)
    }
}
