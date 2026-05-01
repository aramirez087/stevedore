import Core
import FeaturesRename
import XCTest

final class RenameExecutorTests: XCTestCase {
    private let dir = FilePath(scheme: .local, posix: "/files")

    private func okOutcome(name: String, target: String) -> RenameOutcome {
        RenameOutcome(item: makeItem(name: name, dir: self.dir), targetName: target, status: .ok)
    }

    // MARK: - Basic execution

    func testExecuteAllOkOutcomes() async throws {
        let provider = RecordingRenameProvider()
        let items = ["a.txt", "b.txt", "c.txt"].map { makeItem(name: $0, dir: self.dir) }
        await provider.seed(items)

        let outcomes = [
            self.okOutcome(name: "a.txt", target: "aa.txt"),
            self.okOutcome(name: "b.txt", target: "bb.txt"),
            self.okOutcome(name: "c.txt", target: "cc.txt"),
        ]
        let executor = RenameExecutor()
        try await executor.execute(outcomes: outcomes, in: self.dir, using: provider)

        let renames = await provider.renames
        XCTAssertEqual(renames.count, 3)
    }

    func testSkipsCollisionAndInvalid() async throws {
        let provider = RecordingRenameProvider()
        let items = ["a.txt", "b.txt", "c.txt"].map { makeItem(name: $0, dir: self.dir) }
        await provider.seed(items)

        let outcomes = [
            self.okOutcome(name: "a.txt", target: "aa.txt"),
            RenameOutcome(item: makeItem(name: "b.txt", dir: self.dir), targetName: "bb.txt", status: .collision),
            RenameOutcome(
                item: makeItem(name: "c.txt", dir: self.dir),
                targetName: "cc.txt",
                status: .invalid(reason: "bad pattern")
            ),
        ]
        let executor = RenameExecutor()
        try await executor.execute(outcomes: outcomes, in: self.dir, using: provider)

        let renames = await provider.renames
        XCTAssertEqual(renames.count, 1)
        XCTAssertEqual(renames[0].from, self.dir.appending("a.txt"))
    }

    func testJournalPopulatedOnSuccess() async throws {
        let provider = RecordingRenameProvider()
        let items = ["x.txt", "y.txt"].map { makeItem(name: $0, dir: self.dir) }
        await provider.seed(items)

        let outcomes = [
            self.okOutcome(name: "x.txt", target: "x_new.txt"),
            self.okOutcome(name: "y.txt", target: "y_new.txt"),
        ]
        let executor = RenameExecutor()
        try await executor.execute(outcomes: outcomes, in: self.dir, using: provider)

        let journal = await executor.journal
        XCTAssertEqual(journal.count, 2)
        XCTAssertEqual(journal[0].originalPath, self.dir.appending("x.txt"))
        XCTAssertEqual(journal[0].renamedPath, self.dir.appending("x_new.txt"))
    }

    // MARK: - Rollback (exit criterion)

    func testRollbackOnFifthFailure() async throws {
        let provider = RecordingRenameProvider()
        let names = ["a.txt", "b.txt", "c.txt", "d.txt", "e.txt", "f.txt", "g.txt", "h.txt", "i.txt", "j.txt"]
        let items = names.map { makeItem(name: $0, dir: self.dir) }
        await provider.seed(items)
        await provider.setFailAtRenameIndices([5])

        let outcomes = names.map {
            self.okOutcome(name: $0, target: $0.replacingOccurrences(of: ".txt", with: "_new.txt"))
        }
        let executor = RenameExecutor()
        do {
            try await executor.execute(outcomes: outcomes, in: self.dir, using: provider)
            XCTFail("Expected execute to throw")
        } catch {
            // expected
        }

        // Only 4 forward renames happened before the 5th failed
        let hasA = await provider.hasNode(at: self.dir.appending("a.txt"))
        let hasANew = await provider.hasNode(at: self.dir.appending("a_new.txt"))
        let hasE = await provider.hasNode(at: self.dir.appending("e.txt"))
        let hasENew = await provider.hasNode(at: self.dir.appending("e_new.txt"))

        XCTAssertTrue(hasA, "a.txt should be rolled back to original path")
        XCTAssertFalse(hasANew, "a_new.txt should not exist after rollback")
        XCTAssertTrue(hasE, "e.txt was never renamed, should still exist")
        XCTAssertFalse(hasENew, "e_new.txt was never created")
    }

    func testRollbackRestoresPaths() async throws {
        let provider = RecordingRenameProvider()
        let names = ["p.txt", "q.txt", "r.txt", "s.txt", "t.txt"]
        let items = names.map { makeItem(name: $0, dir: self.dir) }
        await provider.seed(items)
        await provider.setFailAtRenameIndices([5])

        let outcomes = names.map {
            self.okOutcome(name: $0, target: $0.replacingOccurrences(of: ".txt", with: "_v2.txt"))
        }
        let executor = RenameExecutor()
        do {
            try await executor.execute(outcomes: outcomes, in: self.dir, using: provider)
            XCTFail("Expected execute to throw")
        } catch { /* expected */ }

        for name in ["p.txt", "q.txt", "r.txt", "s.txt"] {
            let hasOriginal = await provider.hasNode(at: self.dir.appending(name))
            XCTAssertTrue(hasOriginal, "\(name) should be restored after rollback")
            let renamedName = name.replacingOccurrences(of: ".txt", with: "_v2.txt")
            let hasRenamed = await provider.hasNode(at: self.dir.appending(renamedName))
            XCTAssertFalse(hasRenamed, "\(name) renamed version should not exist after rollback")
        }
    }

    // MARK: - Reset

    func testResetClearsJournal() async throws {
        let provider = RecordingRenameProvider()
        let items = [makeItem(name: "z.txt", dir: self.dir)]
        await provider.seed(items)

        let outcomes = [self.okOutcome(name: "z.txt", target: "z_new.txt")]
        let executor = RenameExecutor()
        try await executor.execute(outcomes: outcomes, in: self.dir, using: provider)

        var journal = await executor.journal
        XCTAssertEqual(journal.count, 1)

        await executor.reset()
        journal = await executor.journal
        XCTAssertTrue(journal.isEmpty)
    }

    // MARK: - Edge cases

    func testEmptyOutcomesSucceeds() async throws {
        let provider = RecordingRenameProvider()
        let executor = RenameExecutor()
        try await executor.execute(outcomes: [], in: self.dir, using: provider)
        let renames = await provider.renames
        XCTAssertTrue(renames.isEmpty)
    }

    func testDirectoryAppended() async throws {
        let provider = RecordingRenameProvider()
        let item = makeItem(name: "orig.txt", dir: FilePath(scheme: .local, posix: "/other"))
        await provider.seed([item])

        let outcomes = [RenameOutcome(item: item, targetName: "dest.txt", status: .ok)]
        let executor = RenameExecutor()
        try await executor.execute(outcomes: outcomes, in: self.dir, using: provider)

        let renames = await provider.renames
        XCTAssertEqual(renames[0].to, self.dir.appending("dest.txt"))
    }

    func testProviderErrorPropagated() async throws {
        let provider = RecordingRenameProvider()
        let items = ["a.txt"].map { makeItem(name: $0, dir: self.dir) }
        await provider.seed(items)
        await provider.setFailAtRenameIndices([1])

        let outcomes = [self.okOutcome(name: "a.txt", target: "a_new.txt")]
        let executor = RenameExecutor()
        do {
            try await executor.execute(outcomes: outcomes, in: self.dir, using: provider)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    func testBestEffortRollbackContinues() async throws {
        let provider = RecordingRenameProvider()
        let names = ["a.txt", "b.txt", "c.txt", "d.txt", "e.txt"]
        let items = names.map { makeItem(name: $0, dir: self.dir) }
        await provider.seed(items)
        // Forward renames 1-4 succeed; 5 (e) fails triggering rollback
        // Rollback (reversed journal d,c,b,a): call 6=d, 7=c fails (try?), 8=b, 9=a
        await provider.setFailAtRenameIndices([5, 7])

        let outcomes = names.map {
            self.okOutcome(name: $0, target: $0.replacingOccurrences(of: ".txt", with: "_new.txt"))
        }
        let executor = RenameExecutor()
        do {
            try await executor.execute(outcomes: outcomes, in: self.dir, using: provider)
            XCTFail("Expected execute to throw")
        } catch { /* expected */ }

        // a, b, d should be rolled back; c rollback failed; e was never touched
        let hasA = await provider.hasNode(at: self.dir.appending("a.txt"))
        let hasB = await provider.hasNode(at: self.dir.appending("b.txt"))
        let hasD = await provider.hasNode(at: self.dir.appending("d.txt"))
        let hasE = await provider.hasNode(at: self.dir.appending("e.txt"))
        XCTAssertTrue(hasA, "a.txt should be rolled back")
        XCTAssertTrue(hasB, "b.txt should be rolled back")
        XCTAssertTrue(hasD, "d.txt should be rolled back")
        XCTAssertTrue(hasE, "e.txt was never touched")
    }
}
