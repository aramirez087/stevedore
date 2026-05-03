import Core
import FeaturesSync
import Foundation
import XCTest

// MARK: - SyncPlanTests

final class SyncPlanTests: XCTestCase {
    private let leftRoot = FilePath(scheme: .local, posix: "/left")
    private let rightRoot = FilePath(scheme: .local, posix: "/right")

    private var relPath: FilePath {
        FilePath(scheme: .local, posix: "foo.txt")
    }

    private let t1 = Date(timeIntervalSince1970: 1_000_000)
    private let t2 = Date(timeIntervalSince1970: 2_000_000)

    private func leftItem(size: Int64 = 100, mtime: Date? = nil) -> FileItem {
        FileItem(
            path: FilePath(scheme: .local, posix: "/left/foo.txt"),
            kind: .regularFile,
            attributes: FileAttributes(sizeInBytes: size, modificationDate: mtime)
        )
    }

    private func rightItem(size: Int64 = 100, mtime: Date? = nil) -> FileItem {
        FileItem(
            path: FilePath(scheme: .local, posix: "/right/foo.txt"),
            kind: .regularFile,
            attributes: FileAttributes(sizeInBytes: size, modificationDate: mtime)
        )
    }

    private func diff(status: DifferenceStatus, left: FileItem? = nil, right: FileItem? = nil) -> Difference {
        Difference(relativePath: self.relPath, status: status, leftItem: left, rightItem: right)
    }

    // MARK: - Empty / all-matched

    func testEmptyDifferencesProducesEmptyPlan() {
        let plan = SyncPlan.build(from: [], options: .default)
        XCTAssertTrue(plan.steps.isEmpty)
    }

    func testAllMatchedProducesNoSteps() {
        let matched = self.diff(status: .matched, left: self.leftItem(), right: self.rightItem())
        let plan = SyncPlan.build(from: [matched], options: .default)
        XCTAssertTrue(plan.steps.isEmpty)
    }

    // MARK: - One-way mirror

    func testOneWayMirrorLeftOnly() {
        let item = self.leftItem()
        let d = self.diff(status: .leftOnly, left: item)
        let plan = SyncPlan.build(from: [d], options: SyncOptions(mode: .oneWayMirror))
        guard case .copyToRight(_, let left) = plan.steps.first else {
            XCTFail("Expected copyToRight")
            return
        }
        XCTAssertEqual(left.path, item.path)
    }

    func testOneWayMirrorRightOnly() {
        let d = self.diff(status: .rightOnly, right: self.rightItem())
        let plan = SyncPlan.build(from: [d], options: SyncOptions(mode: .oneWayMirror))
        guard case .deleteFromRight = plan.steps.first else {
            XCTFail("Expected deleteFromRight")
            return
        }
    }

    func testOneWayMirrorModified() {
        let item = self.leftItem()
        let d = self.diff(status: .modified, left: item, right: self.rightItem())
        let plan = SyncPlan.build(from: [d], options: SyncOptions(mode: .oneWayMirror))
        guard case .copyToRight(_, let left) = plan.steps.first else {
            XCTFail("Expected copyToRight")
            return
        }
        XCTAssertEqual(left.path, item.path)
    }

    // MARK: - One-way contribute

    func testOneWayContributeRightOnlyKept() {
        let d = self.diff(status: .rightOnly, right: self.rightItem())
        let plan = SyncPlan.build(from: [d], options: SyncOptions(mode: .oneWayContribute))
        XCTAssertTrue(plan.steps.isEmpty)
    }

    func testOneWayContributeLeftOnly() {
        let item = self.leftItem()
        let d = self.diff(status: .leftOnly, left: item)
        let plan = SyncPlan.build(from: [d], options: SyncOptions(mode: .oneWayContribute))
        guard case .copyToRight = plan.steps.first else {
            XCTFail("Expected copyToRight")
            return
        }
    }

    // MARK: - Two-way

    func testTwoWayLeftOnly() {
        let item = self.leftItem()
        let d = self.diff(status: .leftOnly, left: item)
        let plan = SyncPlan.build(from: [d], options: SyncOptions(mode: .twoWay))
        guard case .copyToRight = plan.steps.first else {
            XCTFail("Expected copyToRight")
            return
        }
    }

    func testTwoWayRightOnly() {
        let item = self.rightItem()
        let d = self.diff(status: .rightOnly, right: item)
        let plan = SyncPlan.build(from: [d], options: SyncOptions(mode: .twoWay))
        guard case .copyToLeft(_, let right) = plan.steps.first else {
            XCTFail("Expected copyToLeft")
            return
        }
        XCTAssertEqual(right.path, item.path)
    }

    func testTwoWayNewerWinsLeftNewer() {
        let opts = SyncOptions(mode: .twoWay, conflictResolution: .newerWins)
        let d = self.diff(status: .modified, left: self.leftItem(mtime: self.t2), right: self.rightItem(mtime: self.t1))
        let plan = SyncPlan.build(from: [d], options: opts)
        guard case .replaceRight = plan.steps.first else {
            XCTFail("Expected replaceRight")
            return
        }
    }

    func testTwoWayNewerWinsRightNewer() {
        let opts = SyncOptions(mode: .twoWay, conflictResolution: .newerWins)
        let d = self.diff(status: .modified, left: self.leftItem(mtime: self.t1), right: self.rightItem(mtime: self.t2))
        let plan = SyncPlan.build(from: [d], options: opts)
        guard case .replaceLeft = plan.steps.first else {
            XCTFail("Expected replaceLeft")
            return
        }
    }

    func testTwoWayLargerWinsLeftLarger() {
        let opts = SyncOptions(mode: .twoWay, conflictResolution: .largerWins)
        let d = self.diff(status: .modified, left: self.leftItem(size: 200), right: self.rightItem(size: 100))
        let plan = SyncPlan.build(from: [d], options: opts)
        guard case .replaceRight = plan.steps.first else {
            XCTFail("Expected replaceRight")
            return
        }
    }

    func testTwoWayLargerWinsRightLarger() {
        let opts = SyncOptions(mode: .twoWay, conflictResolution: .largerWins)
        let d = self.diff(status: .modified, left: self.leftItem(size: 100), right: self.rightItem(size: 200))
        let plan = SyncPlan.build(from: [d], options: opts)
        guard case .replaceLeft = plan.steps.first else {
            XCTFail("Expected replaceLeft")
            return
        }
    }

    func testTwoWayManualConflict() {
        let opts = SyncOptions(mode: .twoWay, conflictResolution: .manual)
        let d = self.diff(status: .modified, left: self.leftItem(), right: self.rightItem())
        let plan = SyncPlan.build(from: [d], options: opts)
        guard case .conflict = plan.steps.first else {
            XCTFail("Expected conflict")
            return
        }
    }

    func testTwoWayNewerWinsNilMtimeGivesConflict() {
        let opts = SyncOptions(mode: .twoWay, conflictResolution: .newerWins)
        // No modificationDate on either side
        let d = self.diff(status: .modified, left: self.leftItem(mtime: nil), right: self.rightItem(mtime: nil))
        let plan = SyncPlan.build(from: [d], options: opts)
        guard case .conflict = plan.steps.first else {
            XCTFail("Expected conflict when mtime unavailable")
            return
        }
    }

    // MARK: - Determinism

    func testPlanIsDeterministic() {
        let diffs = [
            diff(status: .leftOnly, left: leftItem()),
            diff(status: .rightOnly, right: rightItem()),
        ]
        let opts = SyncOptions(mode: .oneWayMirror)
        let plan1 = SyncPlan.build(from: diffs, options: opts)
        let plan2 = SyncPlan.build(from: diffs, options: opts)
        XCTAssertEqual(plan1.steps.count, plan2.steps.count)
    }
}
