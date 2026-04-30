@testable import Core
import Foundation
import XCTest

final class CodableRoundTripTests: XCTestCase {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private func roundTrip<Value: Codable & Equatable>(_ value: Value) throws -> Value {
        let data = try self.encoder.encode(value)
        return try self.decoder.decode(Value.self, from: data)
    }

    func testFilePathRoundTrips() throws {
        let original = FilePath(scheme: .sftp, posix: "/var/www/index.html")
        XCTAssertEqual(try self.roundTrip(original), original)
    }

    func testFileItemRoundTrips() throws {
        let attributes = FileAttributes(
            sizeInBytes: 1024,
            modificationDate: Date(timeIntervalSince1970: 1_700_000_000),
            permissions: PosixPermissions(rawMode: 0o644),
            isHidden: false
        )
        let item = FileItem(
            path: FilePath(scheme: .local, posix: "/tmp/note.txt"),
            kind: .regularFile,
            attributes: attributes
        )
        XCTAssertEqual(try self.roundTrip(item), item)
    }

    func testRemoteHostDescriptorRoundTrips() throws {
        let descriptor = RemoteHostDescriptor(
            displayName: "example",
            scheme: .sftp,
            host: "example.com",
            port: 22,
            username: "user",
            initialPath: FilePath(scheme: .sftp, posix: "/home/user")
        )
        XCTAssertEqual(try self.roundTrip(descriptor), descriptor)
    }

    func testOperationKindRoundTripsForArchive() throws {
        let kind = OperationKind.archive(format: .tarGzip)
        XCTAssertEqual(try self.roundTrip(kind), kind)
    }

    func testOperationKindRoundTripsForSimpleCases() throws {
        for kind in [
            OperationKind.copy,
            .move,
            .delete,
            .rename,
            .mkdir,
            .symlink,
            .extract,
            .trash,
        ] {
            XCTAssertEqual(try self.roundTrip(kind), kind)
        }
    }

    func testOperationDescriptorRoundTrips() throws {
        let descriptor = OperationDescriptor(
            kind: .copy,
            sources: [FilePath(scheme: .local, posix: "/a")],
            destination: FilePath(scheme: .local, posix: "/b"),
            conflictPolicy: .overwrite,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        XCTAssertEqual(try self.roundTrip(descriptor), descriptor)
    }

    func testWorkspaceRoundTrips() throws {
        let tab = Tab(path: FilePath(scheme: .local, posix: "/Users"))
        let pane = WorkspacePane(tabs: [tab], activeTabID: tab.id)
        let workspace = Workspace(leftPane: pane, rightPane: pane)
        XCTAssertEqual(try self.roundTrip(workspace), workspace)
    }

    func testBookmarkRoundTrips() throws {
        let bookmark = Bookmark(
            displayName: "Home",
            path: FilePath(scheme: .local, posix: "/Users/me"),
            symbolName: "house"
        )
        XCTAssertEqual(try self.roundTrip(bookmark), bookmark)
    }

    func testCredentialPasswordRoundTrips() throws {
        let credential = Credential(username: "user", material: .password("hunter2"))
        XCTAssertEqual(try self.roundTrip(credential), credential)
    }

    func testCredentialPrivateKeyRoundTrips() throws {
        let credential = Credential(
            username: "user",
            material: .privateKey(pem: "-----BEGIN-----", passphrase: "passphrase")
        )
        XCTAssertEqual(try self.roundTrip(credential), credential)
    }

    func testProgressRoundTrips() throws {
        let progress = Progress(bytesDone: 256, bytesTotal: 1024, phase: .transferring)
        XCTAssertEqual(try self.roundTrip(progress), progress)
    }

    func testGitFileStatusRoundTrips() throws {
        let status = GitFileStatus(
            path: FilePath(scheme: .local, posix: "/repo/file.swift"),
            indexState: .modified,
            worktreeState: .unmodified
        )
        XCTAssertEqual(try self.roundTrip(status), status)
    }
}
