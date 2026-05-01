@testable import Core
import XCTest

final class ResultHelpersTests: XCTestCase {
    // MARK: - mapErrorTo

    func testMapErrorTo_success_passesThrough() {
        let result: Result<Int, StevedoreError> = .success(42)
        let mapped = result.mapErrorTo { _ in StevedoreError.cancelled }
        XCTAssertEqual(try mapped.get(), 42)
    }

    func testMapErrorTo_failure_transformed() {
        let original = StevedoreError.cancelled
        let result: Result<Int, StevedoreError> = .failure(original)
        let mapped = result.mapErrorTo { _ in StevedoreError.unsupported("new") }
        XCTAssertThrowsError(try mapped.get()) { error in
            XCTAssertEqual(error as? StevedoreError, .unsupported("new"))
        }
    }

    // MARK: - asyncFlatMap

    func testAsyncFlatMap_success_transformApplied() async {
        let result: Result<Int, StevedoreError> = .success(5)
        let mapped = await result.asyncFlatMap { value -> Result<String, StevedoreError> in
            .success("value=\(value)")
        }
        XCTAssertEqual(try? mapped.get(), "value=5")
    }

    func testAsyncFlatMap_failure_skipTransform() async {
        let result: Result<Int, StevedoreError> = .failure(.cancelled)
        var transformCalled = false
        let mapped = await result.asyncFlatMap { _ -> Result<String, StevedoreError> in
            transformCalled = true
            return .success("should not reach")
        }
        XCTAssertFalse(transformCalled)
        XCTAssertThrowsError(try mapped.get())
    }

    func testAsyncFlatMap_success_canReturnNewFailure() async {
        let result: Result<Int, StevedoreError> = .success(10)
        let mapped = await result.asyncFlatMap { _ -> Result<Int, StevedoreError> in
            .failure(.cancelled)
        }
        XCTAssertThrowsError(try mapped.get()) { error in
            XCTAssertEqual(error as? StevedoreError, .cancelled)
        }
    }

    // MARK: - toStevedoreError

    func testToStevedoreError_success_passesThrough() {
        let result: Result<Int, any Error> = .success(99)
        let converted = result.toStevedoreError()
        XCTAssertEqual(try? converted.get(), 99)
    }

    func testToStevedoreError_alreadyStevedoreError_unchanged() {
        let original = StevedoreError.cancelled
        let result: Result<Int, any Error> = .failure(original)
        let converted = result.toStevedoreError()
        XCTAssertThrowsError(try converted.get()) { error in
            XCTAssertEqual(error as? StevedoreError, .cancelled)
        }
    }

    func testToStevedoreError_cancellationError_becomesCancelled() {
        let result: Result<Int, any Error> = .failure(CancellationError())
        let converted = result.toStevedoreError()
        XCTAssertThrowsError(try converted.get()) { error in
            XCTAssertEqual(error as? StevedoreError, .cancelled)
        }
    }

    func testToStevedoreError_genericError_becomesInvalidArgument() {
        struct FakeError: Error, LocalizedError {
            var errorDescription: String? {
                "fake detail"
            }
        }
        let result: Result<Int, any Error> = .failure(FakeError())
        let converted = result.toStevedoreError()
        XCTAssertThrowsError(try converted.get()) { error in
            if case .invalidArgument(let detail) = error as? StevedoreError {
                XCTAssertFalse(detail.isEmpty)
            } else {
                XCTFail("Expected .invalidArgument, got \(error)")
            }
        }
    }

    // MARK: - StevedoreErrorBridge.map

    func testBridge_stevedoreError_passthrough() {
        let input = StevedoreError.unsupported("test")
        XCTAssertEqual(StevedoreErrorBridge.map(input), .unsupported("test"))
    }

    func testBridge_cancellation_becomesCancelled() {
        XCTAssertEqual(StevedoreErrorBridge.map(CancellationError()), .cancelled)
    }

    func testBridge_arbitrary_becomesInvalidArgument() {
        struct Other: Error {}
        if case .invalidArgument = StevedoreErrorBridge.map(Other()) {
            // expected
        } else {
            XCTFail("Expected .invalidArgument")
        }
    }
}
