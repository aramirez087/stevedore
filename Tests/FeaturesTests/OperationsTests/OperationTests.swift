import Core
import FeaturesOperations
import Foundation
import XCTest

final class OperationTests: XCTestCase {
    func testIdentifiableID() {
        let descriptor = OperationDescriptor(kind: .mkdir, sources: [], destination: .local("/a"))
        let op = Operation(descriptor: descriptor)
        XCTAssertEqual(op.id, descriptor.id)
    }

    func testInitialStatePending() {
        let descriptor = OperationDescriptor(kind: .copy, sources: [.local("/a")], destination: .local("/b"))
        let op = Operation(descriptor: descriptor)
        if case .pending = op.state {} else { XCTFail("expected .pending") }
    }

    func testInitialProgressZero() {
        let descriptor = OperationDescriptor(kind: .delete, sources: [.local("/a")])
        let op = Operation(descriptor: descriptor)
        XCTAssertEqual(op.progress.bytesCompleted, 0)
        XCTAssertNil(op.progress.bytesTotal)
    }

    func testProgressFractionNilWhenTotalUnknown() {
        var progress = TransferProgress(operationID: UUID())
        progress.bytesCompleted = 100
        XCTAssertNil(progress.fraction)
    }

    func testProgressFractionComputedCorrectly() throws {
        var progress = TransferProgress(operationID: UUID())
        progress.bytesCompleted = 500
        progress.bytesTotal = 1000
        XCTAssertEqual(try XCTUnwrap(progress.fraction), 0.5, accuracy: 0.001)
    }
}
