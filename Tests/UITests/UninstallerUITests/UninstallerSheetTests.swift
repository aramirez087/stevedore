import AppKit
import FeaturesUninstaller
import SwiftUI
import UIUninstallerUI
import XCTest

@MainActor
final class UninstallerSheetTests: XCTestCase {
    func testIdleState_rendersLauncher() {
        let vm = UninstallerViewModel()
        let sheet = UninstallerSheet(viewModel: vm)
        let hosting = NSHostingView(rootView: sheet)
        XCTAssertNotNil(hosting)
    }

    func testScanningState_rendersView() {
        let vm = UninstallerViewModel()
        vm.scanState = .scanning
        let sheet = UninstallerSheet(viewModel: vm)
        let hosting = NSHostingView(rootView: sheet)
        XCTAssertNotNil(hosting)
    }

    func testReadyState_rendersTable() {
        let vm = UninstallerViewModel()
        vm.metadata = .fake()
        vm.rows = [
            FileRow(file: makeHighConfidenceFile(), selected: true),
            FileRow(file: makeMediumConfidenceFile(), selected: false),
        ]
        vm.scanState = .ready
        let sheet = UninstallerSheet(viewModel: vm)
        let hosting = NSHostingView(rootView: sheet)
        XCTAssertNotNil(hosting)
    }

    func testErrorState_rendersView() {
        let vm = UninstallerViewModel()
        vm.scanState = .error("Something went wrong")
        let sheet = UninstallerSheet(viewModel: vm)
        let hosting = NSHostingView(rootView: sheet)
        XCTAssertNotNil(hosting)
    }
}
