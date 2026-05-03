import Core
import Foundation
import ServicesSettings
import XCTest

final class WorkspacesRepositoryTests: XCTestCase {
    private var testDirectory: URL!
    private var store: JSONFileStore!
    private var repo: WorkspacesRepository!

    override func setUp() async throws {
        try await super.setUp()
        self.testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WorkspacesRepoTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: self.testDirectory, withIntermediateDirectories: true)
        self.store = try JSONFileStore(directory: self.testDirectory, filename: "workspaces")
        self.repo = WorkspacesRepository(store: self.store)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: self.testDirectory)
        try await super.tearDown()
    }

    private func makeWorkspace() -> Workspace {
        Workspace(
            leftPane: WorkspacePane(tabs: [], activeTabID: nil),
            rightPane: WorkspacePane(tabs: [], activeTabID: nil)
        )
    }

    // MARK: - Tests

    func testAllReturnsEmptyWhenFileAbsent() async {
        let items = await self.repo.all()
        XCTAssertTrue(items.isEmpty)
    }

    func testSaveAndFetchRoundTrip() async throws {
        let workspaces = [makeWorkspace(), makeWorkspace()]
        try await self.repo.save(workspaces)
        let fetched = await self.repo.all()
        XCTAssertEqual(fetched, workspaces)
    }

    func testObserveEmitsCurrentOnSubscribe() async {
        let stream = self.repo.observe()
        var iterator = stream.makeAsyncIterator()
        let initial = await iterator.next()
        XCTAssertEqual(initial, [])
    }

    func testObserveEmitsAfterSave() async throws {
        let stream = self.repo.observe()
        var iterator = stream.makeAsyncIterator()

        let initial = await iterator.next()
        XCTAssertEqual(initial, [])

        try await self.repo.save([self.makeWorkspace()])

        let updated = await iterator.next()
        XCTAssertEqual(updated?.count, 1)
    }
}
