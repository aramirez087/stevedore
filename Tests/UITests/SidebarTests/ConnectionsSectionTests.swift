import AppKit
import Core
import SwiftUI
@testable import UISidebar
import XCTest

@MainActor
final class SidebarConnectionsSectionTests: XCTestCase {
    func testRendersDescriptors() {
        let desc = RemoteHostDescriptor.fake(name: "server")
        let fakeConn = FakeConnectionStatus(descriptors: [desc])
        let vm = makeSidebarViewModel(connections: fakeConn)
        let host = NSHostingView(rootView: ConnectionsSection(viewModel: vm))
        XCTAssertNotNil(host)
    }

    func testRendersEmpty() {
        let vm = makeSidebarViewModel()
        let host = NSHostingView(rootView: ConnectionsSection(viewModel: vm))
        XCTAssertNotNil(host)
    }

    func testIdleStatus() {
        let desc = RemoteHostDescriptor.fake()
        let fakeConn = FakeConnectionStatus(descriptors: [desc])
        fakeConn.statusMap[desc.id] = .idle
        let vm = makeSidebarViewModel(connections: fakeConn)
        let host = NSHostingView(rootView: ConnectionsSection(viewModel: vm))
        XCTAssertNotNil(host)
    }

    func testConnectingStatus() {
        let desc = RemoteHostDescriptor.fake()
        let fakeConn = FakeConnectionStatus(descriptors: [desc])
        fakeConn.statusMap[desc.id] = .connecting
        let vm = makeSidebarViewModel(connections: fakeConn)
        let host = NSHostingView(rootView: ConnectionsSection(viewModel: vm))
        XCTAssertNotNil(host)
    }

    func testConnectedStatus() {
        let desc = RemoteHostDescriptor.fake()
        let fakeConn = FakeConnectionStatus(descriptors: [desc])
        fakeConn.statusMap[desc.id] = .connected
        let vm = makeSidebarViewModel(connections: fakeConn)
        let host = NSHostingView(rootView: ConnectionsSection(viewModel: vm))
        XCTAssertNotNil(host)
    }

    func testErrorStatus() {
        let desc = RemoteHostDescriptor.fake()
        let fakeConn = FakeConnectionStatus(descriptors: [desc])
        fakeConn.statusMap[desc.id] = .error("Connection refused")
        let vm = makeSidebarViewModel(connections: fakeConn)
        let host = NSHostingView(rootView: ConnectionsSection(viewModel: vm))
        XCTAssertNotNil(host)
    }

    func testAddConnectionCallsProvider() {
        let fakeConn = FakeConnectionStatus()
        let vm = makeSidebarViewModel(connections: fakeConn)
        let desc = RemoteHostDescriptor.fake(name: "new-host")
        vm.connectionStatus.add(desc)
        XCTAssertEqual(fakeConn.addCalls.count, 1)
        XCTAssertEqual(fakeConn.addCalls.first?.displayName, "new-host")
    }

    func testRemoveConnectionCallsProvider() {
        let desc = RemoteHostDescriptor.fake()
        let fakeConn = FakeConnectionStatus(descriptors: [desc])
        let vm = makeSidebarViewModel(connections: fakeConn)
        vm.connectionStatus.remove(id: desc.id)
        XCTAssertEqual(fakeConn.removeCalls.count, 1)
        XCTAssertEqual(fakeConn.removeCalls.first, desc.id)
    }
}
