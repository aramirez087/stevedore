import MainWindow
import SwiftUI

@main
struct StevedoreApp: App {
    @State private var env = AppEnvironment()

    var body: some Scene {
        MainWindowScene(model: env.mainWindowModel)
    }
}
