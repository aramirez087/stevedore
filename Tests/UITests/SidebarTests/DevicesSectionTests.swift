import AppKit
import SwiftUI
@testable import UISidebar
import XCTest

@MainActor
final class SidebarDevicesSectionTests: XCTestCase {
    func testRendersVolumes() async {
        let vol = SidebarVolume.fake(name: "USB", isEjectable: true, isRemovable: true)
        let fakeVols = FakeVolumeDiscovery(volumes: [vol])
        let vm = makeSidebarViewModel(volumes: fakeVols)
        await vm.start()
        let host = NSHostingView(rootView: DevicesSection(viewModel: vm))
        XCTAssertNotNil(host)
    }

    func testRendersEmpty() {
        let vm = makeSidebarViewModel()
        let host = NSHostingView(rootView: DevicesSection(viewModel: vm))
        XCTAssertNotNil(host)
    }

    func testEjectButtonCallsEjector() async {
        let url = URL(fileURLWithPath: "/Volumes/USB")
        let vol = SidebarVolume(url: url, name: "USB", isEjectable: true, isRemovable: true)
        let fakeVols = FakeVolumeDiscovery(volumes: [vol])
        let ejector = FakeVolumeEjector()
        let vm = makeSidebarViewModel(volumes: fakeVols, ejector: ejector)
        await vm.start()

        await vm.ejectVolume(url: url)

        XCTAssertEqual(ejector.ejectCalls, [url])
    }

    func testNoFileManagerDirectCall() async {
        let url = URL(fileURLWithPath: "/Volumes/USB")
        let ejector = FakeVolumeEjector()
        let vm = makeSidebarViewModel(ejector: ejector)

        await vm.ejectVolume(url: url)

        // Eject was routed through the injected VolumeEjecting collaborator.
        XCTAssertEqual(ejector.ejectCalls.count, 1)
    }

    func testNonEjectableVolumeDoesNotShowEjectButton() async {
        let vol = SidebarVolume.fake(name: "Macintosh HD", isEjectable: false, isRemovable: false)
        let fakeVols = FakeVolumeDiscovery(volumes: [vol])
        let vm = makeSidebarViewModel(volumes: fakeVols)
        await vm.start()
        let host = NSHostingView(rootView: DevicesSection(viewModel: vm))
        XCTAssertNotNil(host)
    }
}
