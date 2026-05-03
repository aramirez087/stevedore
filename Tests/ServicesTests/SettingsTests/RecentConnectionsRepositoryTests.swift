import Core
import Foundation
import ServicesSettings
import XCTest

final class RecentConnectionsRepositoryTests: XCTestCase {
    private var testDirectory: URL!
    private var store: JSONFileStore!
    private var repo: RecentConnectionsRepository!

    override func setUp() async throws {
        try await super.setUp()
        self.testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RecentConnectionsRepoTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: self.testDirectory, withIntermediateDirectories: true)
        self.store = try JSONFileStore(directory: self.testDirectory, filename: "recent-connections")
        self.repo = RecentConnectionsRepository(store: self.store)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: self.testDirectory)
        try await super.tearDown()
    }

    private func makeDescriptor(name: String = "Server") -> RemoteHostDescriptor {
        RemoteHostDescriptor(displayName: name, scheme: .sftp, host: "\(name.lowercased()).example.com")
    }

    // MARK: - Tests

    func testAllReturnsEmptyWhenFileAbsent() async {
        let items = await self.repo.all()
        XCTAssertTrue(items.isEmpty)
    }

    func testPrependAddsToFront() async throws {
        let first = self.makeDescriptor(name: "A")
        let second = self.makeDescriptor(name: "B")
        try await self.repo.prepend(first)
        try await self.repo.prepend(second)

        let items = await self.repo.all()
        XCTAssertEqual(items.first?.displayName, "B")
        XCTAssertEqual(items.last?.displayName, "A")
    }

    func testPrependDeduplicatesById() async throws {
        let descriptor = self.makeDescriptor(name: "X")
        try await self.repo.prepend(descriptor)
        try await self.repo.prepend(descriptor)

        let items = await self.repo.all()
        XCTAssertEqual(items.count, 1)
    }

    func testPrependCapAtMaxCount() async throws {
        for i in 0 ..< RecentConnectionsRepository.maxCount + 5 {
            try await self.repo.prepend(self.makeDescriptor(name: "Server\(i)"))
        }
        let items = await self.repo.all()
        XCTAssertEqual(items.count, RecentConnectionsRepository.maxCount)
    }

    func testObserveEmitsAfterPrepend() async throws {
        let stream = self.repo.observe()
        var iterator = stream.makeAsyncIterator()

        let initial = await iterator.next()
        XCTAssertEqual(initial, [])

        try await self.repo.prepend(self.makeDescriptor())

        let updated = await iterator.next()
        XCTAssertEqual(updated?.count, 1)
    }
}
