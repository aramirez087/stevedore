import Core
import Foundation
@testable import UISidebar
import XCTest

@MainActor
final class SidebarViewModelTests: XCTestCase {
    func testDefaultSelectionIsNil() {
        let vm = makeSidebarViewModel()
        XCTAssertNil(vm.selection)
    }

    func testSelectBookmark() {
        let bm = Bookmark.fake()
        let vm = makeSidebarViewModel()
        vm.select(.bookmark(bm.id))
        XCTAssertEqual(vm.selection, .bookmark(bm.id))
    }

    func testSelectVolume() {
        let url = URL(fileURLWithPath: "/Volumes/Test")
        let vm = makeSidebarViewModel()
        vm.select(.volume(url))
        XCTAssertEqual(vm.selection, .volume(url))
    }

    func testSelectConnection() {
        let id = RemoteHostDescriptor.fake().id
        let vm = makeSidebarViewModel()
        vm.select(.connection(id))
        XCTAssertEqual(vm.selection, .connection(id))
    }

    func testSelectTag() {
        let vm = makeSidebarViewModel()
        vm.select(.tag("Red"))
        XCTAssertEqual(vm.selection, .tag("Red"))
    }

    func testSelectNilClearsSelection() {
        let vm = makeSidebarViewModel()
        vm.select(.tag("Red"))
        vm.select(nil)
        XCTAssertNil(vm.selection)
    }

    func testStartPopulatesVolumes() async {
        let vol1 = SidebarVolume.fake(path: "/Volumes/A", name: "A")
        let vol2 = SidebarVolume.fake(path: "/Volumes/B", name: "B")
        let fakeVols = FakeVolumeDiscovery(volumes: [vol1, vol2])
        let vm = makeSidebarViewModel(volumes: fakeVols)
        await vm.start()
        XCTAssertEqual(vm.volumes.count, 3)
        XCTAssertEqual(vm.volumes.first?.url, FileManager.default.homeDirectoryForCurrentUser)
        XCTAssertEqual(vm.volumes.first?.name, "Home")
    }

    func testStartPopulatesTags() async {
        let vol = SidebarVolume.fake(path: "/Volumes/A", name: "A")
        let fakeVols = FakeVolumeDiscovery(volumes: [vol])
        let fakeTags = FakeTagsProvider(tags: ["Red", "Blue", "Green"])
        let vm = makeSidebarViewModel(volumes: fakeVols, tags: fakeTags)
        await vm.start()
        XCTAssertEqual(vm.tags, ["Red", "Blue", "Green"])
    }

    func testMountedEventAddsVolume() async {
        let initial = SidebarVolume.fake(path: "/Volumes/A", name: "A")
        let fakeVols = FakeVolumeDiscovery(volumes: [initial])
        let vm = makeSidebarViewModel(volumes: fakeVols)
        await vm.start()

        let newVol = SidebarVolume.fake(path: "/Volumes/B", name: "B")
        fakeVols.emit(.mounted(newVol))
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertTrue(vm.volumes.contains(where: { $0.url == newVol.url }))
    }

    func testUnmountedEventRemovesVolume() async {
        let vol = SidebarVolume.fake(path: "/Volumes/A", name: "A")
        let fakeVols = FakeVolumeDiscovery(volumes: [vol])
        let vm = makeSidebarViewModel(volumes: fakeVols)
        await vm.start()

        fakeVols.emit(.unmounted(vol.url))
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertFalse(vm.volumes.contains(where: { $0.url == vol.url }))
    }

    func testMountedEventDeduplicates() async {
        let vol = SidebarVolume.fake(path: "/Volumes/A", name: "A")
        let fakeVols = FakeVolumeDiscovery(volumes: [vol])
        let vm = makeSidebarViewModel(volumes: fakeVols)
        await vm.start()
        let countBefore = vm.volumes.count

        fakeVols.emit(.mounted(vol)) // same URL — should not duplicate
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(vm.volumes.count, countBefore)
    }

    func testStartIdempotent() async {
        let fakeVols = FakeVolumeDiscovery(volumes: [SidebarVolume.fake()])
        let vm = makeSidebarViewModel(volumes: fakeVols)
        await vm.start()
        await vm.start() // second call should be a no-op
        XCTAssertEqual(vm.volumes.count, 2)
    }

    func testEjectCallsInjectedEjector() async {
        let url = URL(fileURLWithPath: "/Volumes/USB")
        let ejector = FakeVolumeEjector()
        let vm = makeSidebarViewModel(ejector: ejector)
        await vm.ejectVolume(url: url)
        XCTAssertEqual(ejector.ejectCalls, [url])
    }

    func testEjectFailureDoesNotCrash() async {
        let url = URL(fileURLWithPath: "/Volumes/USB")
        let ejector = FakeVolumeEjector()
        ejector.shouldThrow = true
        let vm = makeSidebarViewModel(ejector: ejector)
        await vm.ejectVolume(url: url)
        XCTAssertEqual(ejector.ejectCalls.count, 1)
    }

    func testStartFiltersAutofsHome() async {
        let autofs = SidebarVolume.fake(path: "/System/Volumes/Data/home", name: "home")
        let fakeVols = FakeVolumeDiscovery(volumes: [autofs])
        let vm = makeSidebarViewModel(volumes: fakeVols)
        await vm.start()
        XCTAssertFalse(vm.volumes.contains(where: { $0.url.path == "/System/Volumes/Data/home" }))
        XCTAssertFalse(vm.volumes.contains(where: { $0.url.path == "/home" }))
    }

    func testStartPrependsRealHomeVolume() async {
        let vol = SidebarVolume.fake(path: "/Volumes/A", name: "A")
        let fakeVols = FakeVolumeDiscovery(volumes: [vol])
        let vm = makeSidebarViewModel(volumes: fakeVols)
        await vm.start()
        XCTAssertEqual(vm.volumes.first?.url, FileManager.default.homeDirectoryForCurrentUser)
        XCTAssertEqual(vm.volumes.first?.name, "Home")
        XCTAssertFalse(vm.volumes.first?.isEjectable ?? true)
    }

    func testMountedEventIgnoresAutofsHome() async {
        let fakeVols = FakeVolumeDiscovery(volumes: [])
        let vm = makeSidebarViewModel(volumes: fakeVols)
        await vm.start()
        let countAfterStart = vm.volumes.count

        let autofs = SidebarVolume.fake(path: "/System/Volumes/Data/home", name: "home")
        fakeVols.emit(.mounted(autofs))
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(vm.volumes.count, countAfterStart)
        XCTAssertFalse(vm.volumes.contains(where: { $0.url.path == "/System/Volumes/Data/home" }))
    }
}
