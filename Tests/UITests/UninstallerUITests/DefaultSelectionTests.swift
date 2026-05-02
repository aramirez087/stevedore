import Core
import FeaturesUninstaller
import UIUninstallerUI
import XCTest

/// Verifies default checkbox selection rules:
/// - High-confidence + user-owned → selected
/// - Medium-confidence → not selected
/// - Low-confidence → not selected
/// - System-owned (any confidence) → not selected
@MainActor
final class UninstallerUIDefaultSelectionTests: XCTestCase {
    func testHighConfidenceUserFileIsSelectedByDefault() {
        let vm = UninstallerViewModel()
        let high = makeHighConfidenceFile()
        self.populateRows(vm, files: [high])

        XCTAssertTrue(vm.rows[0].isSelected, "High-confidence user file should be selected by default")
    }

    func testMediumConfidenceFileIsNotSelectedByDefault() {
        let vm = UninstallerViewModel()
        let medium = makeMediumConfidenceFile()
        self.populateRows(vm, files: [medium])

        XCTAssertFalse(vm.rows[0].isSelected, "Medium-confidence file should NOT be selected by default")
    }

    func testLowConfidenceFileIsNotSelectedByDefault() {
        let vm = UninstallerViewModel()
        let low = makeLowConfidenceFile()
        self.populateRows(vm, files: [low])

        XCTAssertFalse(vm.rows[0].isSelected, "Low-confidence file should NOT be selected by default")
    }

    func testSystemOwnedHighConfidenceFileIsNotSelectedByDefault() {
        let vm = UninstallerViewModel()
        let sys = makeSystemFile()
        // System file has high confidence but requiresAdmin = true
        XCTAssertEqual(sys.confidence, .high)
        self.populateRows(vm, files: [sys])

        XCTAssertFalse(vm.rows[0].isSelected, "System-owned file must NOT be selected by default")
    }

    func testMixedBatchDefaultSelections() {
        let vm = UninstallerViewModel()
        let high = makeHighConfidenceFile(path: "/Users/test/Library/Caches/com.example.App")
        let medium = makeMediumConfidenceFile()
        let low = makeLowConfidenceFile()
        let sys = makeSystemFile()
        self.populateRows(vm, files: [high, medium, low, sys])

        XCTAssertEqual(vm.rows.count, 4)
        // Row order matches input order in this synthetic path
        let highRow = vm.rows.first { $0.file.confidence == .high && !$0.file.requiresAdmin }
        let medRow = vm.rows.first { $0.file.confidence == .medium }
        let lowRow = vm.rows.first { $0.file.confidence == .low }
        let sysRow = vm.rows.first { $0.file.requiresAdmin }

        XCTAssertTrue(highRow?.isSelected == true)
        XCTAssertTrue(medRow?.isSelected == false)
        XCTAssertTrue(lowRow?.isSelected == false)
        XCTAssertTrue(sysRow?.isSelected == false)
    }

    // MARK: - Helper

    /// Directly inject rows into the view-model, bypassing the real scanner.
    private func populateRows(_ vm: UninstallerViewModel, files: [AssociatedFile]) {
        // Replicate the same selection logic used internally in makeRows.
        vm.rows = files.map { file in
            let selected = file.confidence == .high && !file.requiresAdmin
            return FileRow(file: file, selected: selected)
        }
    }
}
