import AppKit
import SwiftUI
@testable import UISidebar
import XCTest

@MainActor
final class SidebarTagsSectionTests: XCTestCase {
    func testRendersTags() async {
        let fakeTags = FakeTagsProvider(tags: ["Red", "Blue"])
        let fakeVols = FakeVolumeDiscovery(volumes: [SidebarVolume.fake()])
        let vm = makeSidebarViewModel(volumes: fakeVols, tags: fakeTags)
        await vm.start()
        let host = NSHostingView(rootView: TagsSection(viewModel: vm))
        XCTAssertNotNil(host)
        XCTAssertEqual(vm.tags, ["Red", "Blue"])
    }

    func testRendersEmpty() {
        let vm = makeSidebarViewModel()
        let host = NSHostingView(rootView: TagsSection(viewModel: vm))
        XCTAssertNotNil(host)
    }

    func testSelectTagSetsSidebarItemID() async {
        let fakeTags = FakeTagsProvider(tags: ["Work"])
        let fakeVols = FakeVolumeDiscovery(volumes: [SidebarVolume.fake()])
        let vm = makeSidebarViewModel(volumes: fakeVols, tags: fakeTags)
        await vm.start()
        vm.select(.tag("Work"))
        XCTAssertEqual(vm.selection, .tag("Work"))
    }

    func testTagsLoadedForSyntheticHome() async {
        // normalizeVolumes always prepends the synthetic Home volume, so tags are
        // fetched even when no real mounted volumes are provided.
        let fakeTags = FakeTagsProvider(tags: ["Red"])
        let vm = makeSidebarViewModel(tags: fakeTags) // no real volumes, but Home is injected
        await vm.start()
        XCTAssertEqual(vm.tags, ["Red"])
    }
}
