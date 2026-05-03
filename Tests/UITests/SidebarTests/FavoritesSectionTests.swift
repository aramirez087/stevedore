import AppKit
import Core
import SwiftUI
@testable import UISidebar
import XCTest

@MainActor
final class SidebarFavoritesSectionTests: XCTestCase {
    func testRendersWithBookmarks() {
        let bm = Bookmark.fake(name: "Home")
        let fake = FakeBookmarksProvider(bookmarks: [bm])
        let vm = makeSidebarViewModel(bookmarks: fake)
        let view = FavoritesSection(viewModel: vm)
        let host = NSHostingView(rootView: view)
        XCTAssertNotNil(host)
    }

    func testRendersEmpty() {
        let vm = makeSidebarViewModel()
        let view = FavoritesSection(viewModel: vm)
        let host = NSHostingView(rootView: view)
        XCTAssertNotNil(host)
    }

    func testAddBookmarkCallsProvider() {
        let fake = FakeBookmarksProvider()
        let vm = makeSidebarViewModel(bookmarks: fake)
        let newBM = Bookmark.fake(name: "Work")
        vm.bookmarks.add(newBM)
        XCTAssertEqual(fake.addCalls.count, 1)
        XCTAssertEqual(fake.addCalls.first?.displayName, "Work")
    }

    func testRemoveBookmarkCallsProvider() {
        let bm = Bookmark.fake(name: "Home")
        let fake = FakeBookmarksProvider(bookmarks: [bm])
        let vm = makeSidebarViewModel(bookmarks: fake)
        vm.bookmarks.remove(id: bm.id)
        XCTAssertEqual(fake.removeCalls.count, 1)
        XCTAssertEqual(fake.removeCalls.first, bm.id)
    }

    func testReorderIsStable() {
        let bm1 = Bookmark.fake(name: "A")
        let bm2 = Bookmark.fake(name: "B")
        let bm3 = Bookmark.fake(name: "C")
        let fake = FakeBookmarksProvider(bookmarks: [bm1, bm2, bm3])
        let vm = makeSidebarViewModel(bookmarks: fake)
        vm.bookmarks.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        XCTAssertEqual(fake.bookmarks.map(\.displayName), ["B", "C", "A"])
        XCTAssertEqual(fake.moveCalls.count, 1)
    }
}
