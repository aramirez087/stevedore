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

    func testTagsNotLoadedWithoutVolumes() async {
        let fakeTags = FakeTagsProvider(tags: ["Red"])
        let vm = makeSidebarViewModel(tags: fakeTags) // no volumes
        await vm.start()
        XCTAssertTrue(vm.tags.isEmpty)
    }
}
