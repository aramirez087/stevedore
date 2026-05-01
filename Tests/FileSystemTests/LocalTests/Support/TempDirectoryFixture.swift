import Core
import FileSystemLocal
import Foundation
import XCTest

/// Per-test temporary directory.
///
/// Call `setUp()` at the start of a test to create an isolated scratch area.
/// Call `tearDown()` to restore permissions and remove the entire tree.
final class TempDirectoryFixture {
    private(set) var url: URL
    private(set) var path: FilePath

    init() {
        self.url = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        self.path = FilePath(scheme: .local, posix: self.url.path)
    }

    func setUp() throws {
        try FileManager().createDirectory(at: self.url, withIntermediateDirectories: true, attributes: nil)
    }

    func tearDown() {
        self.restorePermissions(self.url)
        try? FileManager().removeItem(at: self.url)
    }

    // MARK: - Helpers

    func makeFile(name: String, content: String = "x") throws -> URL {
        let fileURL = self.url.appendingPathComponent(name)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    func makeSubdirectory(name: String) throws -> URL {
        let dirURL = self.url.appendingPathComponent(name, isDirectory: true)
        try FileManager().createDirectory(at: dirURL, withIntermediateDirectories: true, attributes: nil)
        return dirURL
    }

    /// Recursively restores permissions to 0o755 so `tearDown` can delete the tree
    /// even when a test leaves behind 0o000 directories.
    private func restorePermissions(_ root: URL) {
        let fm = FileManager()
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: root.path)
        for case let child as URL in enumerator {
            try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: child.path)
        }
    }
}
