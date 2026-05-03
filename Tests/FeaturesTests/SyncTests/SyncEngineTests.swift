import Core
import FeaturesSync
import Foundation
import XCTest

// MARK: - SyncEngineTests

final class SyncEngineTests: XCTestCase {
    private let leftRoot = FilePath(scheme: .local, posix: "/left")
    private let rightRoot = FilePath(scheme: .local, posix: "/right")
    private let relPath = FilePath(scheme: .local, posix: "foo.txt")

    private var leftItem: FileItem {
        FileItem(
            path: FilePath(scheme: .local, posix: "/left/foo.txt"),
            kind: .regularFile,
            attributes: FileAttributes(sizeInBytes: 100)
        )
    }

    private var rightItem: FileItem {
        FileItem(
            path: FilePath(scheme: .local, posix: "/right/foo.txt"),
            kind: .regularFile,
            attributes: FileAttributes(sizeInBytes: 100)
        )
    }

    private func makeEngine(recorder: RecordingSyncExecutor) -> SyncEngine {
        let left = InMemorySyncProvider(scheme: .local)
        let right = InMemorySyncProvider(scheme: .local)
        return SyncEngine(leftProvider: left, rightProvider: right, executor: recorder)
    }

    // MARK: - Empty plan

    func testExecuteEmptyPlan() async throws {
        let recorder = RecordingSyncExecutor()
        let engine = self.makeEngine(recorder: recorder)
        let plan = SyncPlan(differences: [], steps: [])
        try await engine.execute(plan: plan, leftRoot: self.leftRoot, rightRoot: self.rightRoot)
        let copies = await recorder.copies
        let deletes = await recorder.deletes
        XCTAssertTrue(copies.isEmpty)
        XCTAssertTrue(deletes.isEmpty)
    }

    // MARK: - Copy steps

    func testExecuteCopyToRight() async throws {
        let recorder = RecordingSyncExecutor()
        let engine = self.makeEngine(recorder: recorder)
        let diff = Difference(relativePath: self.relPath, status: .leftOnly, leftItem: self.leftItem, rightItem: nil)
        let plan = SyncPlan(differences: [diff], steps: [.copyToRight(relativePath: self.relPath, left: self.leftItem)])
        try await engine.execute(plan: plan, leftRoot: self.leftRoot, rightRoot: self.rightRoot)
        let copies = await recorder.copies
        XCTAssertEqual(copies.count, 1)
        XCTAssertEqual(copies[0].source, self.leftItem.path)
        XCTAssertEqual(copies[0].destination, self.rightRoot.appending(self.relPath.components))
    }

    // MARK: - Delete steps

    func testExecuteDeleteFromRight() async throws {
        let recorder = RecordingSyncExecutor()
        let engine = self.makeEngine(recorder: recorder)
        let diff = Difference(relativePath: self.relPath, status: .rightOnly, leftItem: nil, rightItem: self.rightItem)
        let plan = SyncPlan(differences: [diff], steps: [.deleteFromRight(relativePath: self.relPath)])
        try await engine.execute(plan: plan, leftRoot: self.leftRoot, rightRoot: self.rightRoot)
        let deletes = await recorder.deletes
        XCTAssertEqual(deletes.count, 1)
        XCTAssertEqual(deletes[0], self.rightRoot.appending(self.relPath.components))
    }

    // MARK: - Replace step

    func testExecuteReplaceRight() async throws {
        let recorder = RecordingSyncExecutor()
        let engine = self.makeEngine(recorder: recorder)
        let diff = Difference(
            relativePath: self.relPath,
            status: .modified,
            leftItem: self.leftItem,
            rightItem: self.rightItem
        )
        let plan = SyncPlan(
            differences: [diff],
            steps: [.replaceRight(relativePath: self.relPath, left: self.leftItem)]
        )
        try await engine.execute(plan: plan, leftRoot: self.leftRoot, rightRoot: self.rightRoot)
        let copies = await recorder.copies
        XCTAssertEqual(copies.count, 1)
        XCTAssertEqual(copies[0].source, self.leftItem.path)
        XCTAssertEqual(copies[0].destination, self.rightRoot.appending(self.relPath.components))
    }

    // MARK: - Manual conflict

    func testExecuteManualConflict() async throws {
        let recorder = RecordingSyncExecutor()
        let engine = self.makeEngine(recorder: recorder)
        let leftItem = self.leftItem
        let rightItem = self.rightItem
        let relPath = self.relPath
        let leftRoot = self.leftRoot
        let rightRoot = self.rightRoot
        let diff = Difference(
            relativePath: relPath,
            status: .modified,
            leftItem: leftItem,
            rightItem: rightItem
        )
        let plan = SyncPlan(
            differences: [diff],
            steps: [.conflict(relativePath: relPath, left: leftItem, right: rightItem)]
        )

        let task = Task<Void, any Error> {
            try await engine.execute(plan: plan, leftRoot: leftRoot, rightRoot: rightRoot)
        }

        // Give the engine time to reach the conflict suspension.
        try await Task.sleep(nanoseconds: 20_000_000) // 20 ms
        await engine.resolveConflict(at: relPath, with: .keepLeft)
        try await task.value

        let copies = await recorder.copies
        XCTAssertEqual(copies.count, 1)
        XCTAssertEqual(copies[0].source, leftItem.path)
    }

    // MARK: - Progress reporting

    func testProgressReporting() async throws {
        let recorder = RecordingSyncExecutor()
        let left = InMemorySyncProvider(scheme: .local)
        let right = InMemorySyncProvider(scheme: .local)
        let tracker = SyncProgressTracker()
        let engine = SyncEngine(
            leftProvider: left,
            rightProvider: right,
            executor: recorder,
            progressTracker: tracker
        )

        let diff = Difference(relativePath: self.relPath, status: .leftOnly, leftItem: self.leftItem, rightItem: nil)
        let plan = SyncPlan(differences: [diff], steps: [.copyToRight(relativePath: self.relPath, left: self.leftItem)])

        try await engine.execute(plan: plan, leftRoot: self.leftRoot, rightRoot: self.rightRoot)

        let progress = await tracker.current
        XCTAssertEqual(progress.rowsDone, 1)
        XCTAssertEqual(progress.rowsPending, 0)
    }
}
