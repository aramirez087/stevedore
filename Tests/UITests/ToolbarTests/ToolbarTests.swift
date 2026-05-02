import Core
@testable import UIToolbar
import XCTest

@MainActor
final class ToolbarTests: XCTestCase {
    // MARK: - HistoryStack tests

    func testInitialStateHasNoHistory() {
        let stack = HistoryStack()
        XCTAssertNil(stack.current)
        XCTAssertFalse(stack.canGoBack)
        XCTAssertFalse(stack.canGoForward)
    }

    func testNavigateSetsCurrentPath() {
        var stack = HistoryStack()
        let pathA = makePath(["a"])
        stack.navigate(to: pathA)
        XCTAssertEqual(stack.current, pathA)
    }

    func testCanGoBackAfterTwoNavigations() {
        var stack = HistoryStack()
        stack.navigate(to: makePath(["a"]))
        stack.navigate(to: makePath(["b"]))
        XCTAssertTrue(stack.canGoBack)
    }

    func testGoBackFromSingleEntryIsNoop() {
        var stack = HistoryStack()
        let pathA = makePath(["a"])
        stack.navigate(to: pathA)
        let result = stack.goBack()
        XCTAssertNil(result)
        XCTAssertEqual(stack.current, pathA)
    }

    func testGoBackRestoresPath() {
        var stack = HistoryStack()
        let pathA = makePath(["a"])
        let pathB = makePath(["b"])
        stack.navigate(to: pathA)
        stack.navigate(to: pathB)
        let restored = stack.goBack()
        XCTAssertEqual(restored, pathA)
        XCTAssertEqual(stack.current, pathA)
        XCTAssertTrue(stack.canGoForward)
    }

    func testForwardClearedOnNewNavigation() {
        var stack = HistoryStack()
        stack.navigate(to: makePath(["a"]))
        stack.navigate(to: makePath(["b"]))
        stack.goBack()
        stack.navigate(to: makePath(["c"]))
        XCTAssertFalse(stack.canGoForward)
    }

    func testCapacityDropsOldestEntry() {
        var stack = HistoryStack(capacity: 3)
        stack.navigate(to: makePath(["a"]))
        stack.navigate(to: makePath(["b"]))
        stack.navigate(to: makePath(["c"]))
        stack.navigate(to: makePath(["d"]))
        // Only 3 entries remain (a dropped). canGoBack requires count > 1.
        XCTAssertTrue(stack.canGoBack)
        stack.goBack()
        stack.goBack()
        // Now at position 0 (b) — one more goBack would be a no-op.
        XCTAssertFalse(stack.canGoBack)
    }

    // MARK: - PaneToolbarViewModel tests

    func testGoUpAtRootDoesNotCallOnNavigate() {
        let vm = PaneToolbarViewModel(initialPath: .root(.local))
        var navigateCalled = false
        vm.onNavigate = { _ in navigateCalled = true }
        vm.goUp()
        XCTAssertFalse(navigateCalled)
    }

    func testGoUpNavigatesToParent() {
        let path = makePath(["a", "b"])
        let vm = PaneToolbarViewModel(initialPath: path)
        var received: FilePath?
        vm.onNavigate = { received = $0 }
        vm.goUp()
        let expected = makePath(["a"])
        XCTAssertEqual(received, expected)
        XCTAssertEqual(vm.currentPath, expected)
    }

    func testRefreshCallsCallback() {
        let vm = PaneToolbarViewModel(initialPath: .root(.local))
        var called = false
        vm.onRefresh = { called = true }
        vm.refresh()
        XCTAssertTrue(called)
    }

    func testNewFolderCallsCallback() {
        let vm = PaneToolbarViewModel(initialPath: .root(.local))
        var called = false
        vm.onNewFolder = { called = true }
        vm.newFolder()
        XCTAssertTrue(called)
    }

    func testSetViewModeListUpdatesMode() {
        let vm = PaneToolbarViewModel(initialPath: .root(.local))
        var unavailableCalled = false
        vm.onViewModeUnavailable = { _ in unavailableCalled = true }
        vm.setViewMode(.list)
        XCTAssertEqual(vm.viewMode, .list)
        XCTAssertFalse(unavailableCalled)
    }

    func testSetViewModeColumnsCallsUnavailable() {
        let vm = PaneToolbarViewModel(initialPath: .root(.local))
        var received: ViewMode?
        vm.onViewModeUnavailable = { received = $0 }
        vm.setViewMode(.columns)
        XCTAssertEqual(received, .columns)
        XCTAssertEqual(vm.viewMode, .list)
    }

    func testSetViewModeIconsCallsUnavailable() {
        let vm = PaneToolbarViewModel(initialPath: .root(.local))
        var received: ViewMode?
        vm.onViewModeUnavailable = { received = $0 }
        vm.setViewMode(.icons)
        XCTAssertEqual(received, .icons)
        XCTAssertEqual(vm.viewMode, .list)
    }

    func testNavigateUpdatesCurrentPath() {
        let vm = PaneToolbarViewModel(initialPath: .root(.local))
        let pathX = makePath(["x", "y"])
        vm.navigate(to: pathX)
        XCTAssertEqual(vm.currentPath, pathX)
    }

    // MARK: - Breadcrumb derivation tests

    func testRootPathProducesOneBreadcrumb() {
        let bar = PathBar(path: .root(.local), onNavigate: { _ in })
        let items = bar.breadcrumbs
        XCTAssertEqual(items.count, 1)
        if case .segment(_, let data) = items[0] {
            XCTAssertEqual(data.label, "local:/")
        } else {
            XCTFail("Expected a segment, got ellipsis")
        }
    }

    func testShortPathNoEllipsis() {
        // 4 prefixes (root + a + b + c) ≤ maxVisible(5) → no ellipsis
        let bar = PathBar(path: makePath(["a", "b", "c"]), onNavigate: { _ in })
        let items = bar.breadcrumbs
        XCTAssertFalse(items.contains(where: {
            if case .ellipsis = $0 { return true }
            return false
        }))
        XCTAssertEqual(items.count, 4)
    }

    func testLongPathHasEllipsis() {
        // 8 prefixes (root + a..g) > maxVisible(5) → one ellipsis
        let bar = PathBar(path: makePath(["a", "b", "c", "d", "e", "f", "g"]), onNavigate: { _ in })
        let items = bar.breadcrumbs
        let ellipsisCount = items.count(where: {
            if case .ellipsis = $0 { return true }
            return false
        })
        XCTAssertEqual(ellipsisCount, 1)
        if case .segment(_, let data) = items.first {
            XCTAssertEqual(data.label, "local:/")
        } else {
            XCTFail("First item should be a segment")
        }
        if case .segment(_, let data) = items.last {
            XCTAssertEqual(data.label, "g")
        } else {
            XCTFail("Last item should be a segment")
        }
    }

    func testRemoteSchemeRootLabel() {
        let bar = PathBar(path: .root(.sftp), onNavigate: { _ in })
        let items = bar.breadcrumbs
        if case .segment(_, let data) = items[0] {
            XCTAssertEqual(data.label, "sftp:/")
        } else {
            XCTFail("Expected a segment")
        }
    }

    func testBreadcrumbPathsAreCorrectPrefixes() {
        let path = FilePath(scheme: .local, posix: "/Users/alex/Documents")
        let bar = PathBar(path: path, onNavigate: { _ in })
        let segmentPaths = bar.breadcrumbs.compactMap { item -> FilePath? in
            if case .segment(_, let data) = item { return data.path }
            return nil
        }
        let expected: [FilePath] = [
            .root(.local),
            FilePath(scheme: .local, components: ["Users"]),
            FilePath(scheme: .local, components: ["Users", "alex"]),
            FilePath(scheme: .local, components: ["Users", "alex", "Documents"]),
        ]
        XCTAssertEqual(segmentPaths, expected)
    }

    // MARK: - Search debounce tests

    func testUpdateSetsTermImmediately() {
        let debouncer = SearchDebouncer(interval: .milliseconds(250), sleep: immediateSleep)
        debouncer.update("hello")
        XCTAssertEqual(debouncer.term, "hello")
    }

    func testMultipleUpdatesFiredOnce() async {
        let debouncer = SearchDebouncer(interval: .milliseconds(250), sleep: immediateSleep)
        var fired: [String] = []
        debouncer.onFire = { fired.append($0) }
        debouncer.update("a")
        debouncer.update("b")
        debouncer.update("c")
        // Allow the pending task to complete.
        await Task.yield()
        await Task.yield()
        // Only the last non-cancelled task fires.
        XCTAssertEqual(fired, ["c"])
    }

    func testClearResetsTermAndFiresEmpty() async {
        let debouncer = SearchDebouncer(interval: .milliseconds(250), sleep: immediateSleep)
        var lastFired: String?
        debouncer.onFire = { lastFired = $0 }
        debouncer.update("hello")
        await Task.yield()
        await Task.yield()
        debouncer.clear()
        XCTAssertEqual(debouncer.term, "")
        XCTAssertEqual(lastFired, "")
    }
}
