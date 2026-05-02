import Foundation

public enum SearchPaths {
    public static var userPaths: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let library = home.appending(path: "Library", directoryHint: .isDirectory)
        return [
            "Application Support",
            "Caches",
            "Containers",
            "Group Containers",
            "Preferences",
            "Saved Application State",
            "LaunchAgents",
            "Logs",
            "HTTPStorages",
            "WebKit",
        ].map { library.appending(path: $0, directoryHint: .isDirectory) }
    }

    public static var systemPaths: [URL] {
        let system = URL(filePath: "/Library", directoryHint: .isDirectory)
        return [
            "Application Support",
            "Caches",
            "LaunchAgents",
            "LaunchDaemons",
            "Preferences",
        ].map { system.appending(path: $0, directoryHint: .isDirectory) }
    }

    public static func isSystemOwned(_ url: URL) -> Bool {
        url.path(percentEncoded: false).hasPrefix("/Library/")
    }
}
