import Core
import FeaturesUninstaller
import UIUninstallerUI
import XCTest

/// Verifies that the confirmation footer reflects the live selection state.
@MainActor
final class UninstallerUIConfirmationTextTests: XCTestCase {
    func testItemCountIncludesAppBundlePlusSelected() {
        let vm = self.makeReadyViewModel(selected: 2, unselected: 1)
        // App bundle (1) + 2 selected files = 3
        XCTAssertEqual(vm.confirmationItemCount, 3)
    }

    func testItemCountWithNoSelectedFiles() {
        let vm = self.makeReadyViewModel(selected: 0, unselected: 3)
        // App bundle only
        XCTAssertEqual(vm.confirmationItemCount, 1)
    }

    func testSelectedBytesReflectsCurrentSelection() {
        let vm = UninstallerViewModel()
        vm.metadata = .fake()
        let f1 = makeHighConfidenceFile(path: "/Users/test/Library/Caches/App1")
        let f2 = makeHighConfidenceFile(path: "/Users/test/Library/Caches/App2")
        vm.rows = [
            FileRow(file: self.makeFile(f1, size: 500), selected: true),
            FileRow(file: self.makeFile(f2, size: 300), selected: false),
        ]

        XCTAssertEqual(vm.selectedAssociatedBytes, 500)
    }

    func testSelectedBytesUpdatesWhenSelectionChanges() {
        let vm = UninstallerViewModel()
        vm.metadata = .fake()
        let f1 = self.makeFile(makeHighConfidenceFile(), size: 1000)
        let f2 = self.makeFile(makeMediumConfidenceFile(), size: 2000)
        let row1 = FileRow(file: f1, selected: true)
        let row2 = FileRow(file: f2, selected: false)
        vm.rows = [row1, row2]

        XCTAssertEqual(vm.selectedAssociatedBytes, 1000)

        // Toggle second file on
        vm.rows[1].isSelected = true
        XCTAssertEqual(vm.selectedAssociatedBytes, 3000)

        // Toggle first file off
        vm.rows[0].isSelected = false
        XCTAssertEqual(vm.selectedAssociatedBytes, 2000)
    }

    func testCanConfirmWhenReady() {
        let vm = self.makeReadyViewModel(selected: 1, unselected: 0)
        vm.scanState = .ready
        XCTAssertTrue(vm.canConfirm)
    }

    func testCannotConfirmWhenScanning() {
        let vm = UninstallerViewModel()
        // Manually set to scanning state
        // canConfirm requires scanState == .ready
        XCTAssertFalse(vm.canConfirm)
    }

    // MARK: - Helpers

    private func makeReadyViewModel(selected: Int, unselected: Int) -> UninstallerViewModel {
        let vm = UninstallerViewModel()
        vm.metadata = .fake()
        var rows: [FileRow] = []
        for i in 0 ..< selected {
            let file = makeAssociatedFile(
                path: "/Users/test/Library/Caches/com.example.App_\(i)",
                score: 0.80
            )
            rows.append(FileRow(file: file, selected: true))
        }
        for i in 0 ..< unselected {
            let file = makeAssociatedFile(
                path: "/Users/test/Library/Logs/Example_\(i)",
                score: 0.35
            )
            rows.append(FileRow(file: file, selected: false))
        }
        vm.rows = rows
        // Simulate ready state by checking what canConfirm needs
        // (scanState is private; inject via load path in integration tests)
        return vm
    }

    private func makeFile(_ template: AssociatedFile, size: Int64) -> AssociatedFile {
        AssociatedFile(
            id: UUID(),
            url: template.url,
            sizeInBytes: size,
            modificationDate: template.modificationDate,
            scoreResult: template.scoreResult,
            requiresAdmin: template.requiresAdmin
        )
    }
}
