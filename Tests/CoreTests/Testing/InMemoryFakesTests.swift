@testable import Core
import XCTest

final class InMemoryFakesTests: XCTestCase {
    func testRecordingLoggerCapturesEvents() async {
        let logger = RecordingLogger()
        await logger.log(.info, "hello", category: .app, metadata: nil, file: #file, line: #line)
        let events = await logger.events
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.message, "hello")
        XCTAssertEqual(events.first?.category, .app)
    }

    func testInMemoryCredentialStoreRoundTrip() async throws {
        let store = InMemoryCredentialStore()
        let hostID = UUID()
        let credential = Credential(username: "alice", material: .password("p4ss"))
        try await store.store(credential, for: hostID)
        let retrieved = try await store.credential(for: hostID)
        XCTAssertEqual(retrieved, credential)
        let listed = try await store.list()
        XCTAssertEqual(listed, [hostID])
        try await store.remove(for: hostID)
        let removed = try await store.credential(for: hostID)
        XCTAssertNil(removed)
    }

    func testInMemorySettingsStoreReadsDefaultThenWrittenValue() async {
        let store = InMemorySettingsStore()
        let setting = Setting<Int>(key: "test.threshold", defaultValue: 7)
        let initial = await store.value(for: setting)
        XCTAssertEqual(initial, 7)
        await store.set(42, for: setting)
        let updated = await store.value(for: setting)
        XCTAssertEqual(updated, 42)
    }

    func testInMemoryFileSystemProviderEnumeratesSeededTree() async throws {
        let root = FilePath(scheme: .local, posix: "/root")
        let fileA = FileItem(path: root.appending("a.txt"), kind: .regularFile)
        let fileB = FileItem(path: root.appending("b.txt"), kind: .regularFile)
        let provider = InMemoryFileSystemProvider(items: [
            FileItem(path: root, kind: .directory),
            fileA,
            fileB,
        ])
        var collected: [FileItem] = []
        let enumeration = provider.enumerate(at: root, options: .default)
        for try await item in enumeration {
            collected.append(item)
        }
        XCTAssertEqual(collected.map(\.displayName), ["a.txt", "b.txt"])
    }

    func testInMemoryFileSystemProviderMkdirOperationCreatesItem() async throws {
        let provider = InMemoryFileSystemProvider()
        let target = FilePath(scheme: .local, posix: "/created")
        let descriptor = OperationDescriptor(kind: .mkdir, sources: [target])
        let result = try await provider.execute(descriptor, progress: nil)
        XCTAssertEqual(result.status, .completed)
        let attributes = try await provider.attributes(at: target)
        XCTAssertEqual(attributes, .empty)
    }
}
