import ServicesLogging
import XCTest

final class SignpostHelperTests: XCTestCase {
    func testNonThrowingClosureReturnsValue() async {
        let result = await SignpostHelper.withSignpost("test-non-throwing") {
            42
        }
        XCTAssertEqual(result, 42)
    }

    func testThrowingClosureReraisesOriginalError() async {
        struct SentinelError: Error, Equatable {}
        do {
            try await SignpostHelper.withSignpost("test-throwing") {
                throw SentinelError()
            }
            XCTFail("Expected SentinelError to be thrown")
        } catch is SentinelError {
            // Error type is preserved, not wrapped — pass.
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testVoidClosureCompletesWithoutError() async {
        await SignpostHelper.withSignpost("test-void") {
            // No-op work; verifies @discardableResult and rethrows both apply.
        }
    }

    func testStringReturnValue() async {
        let result = await SignpostHelper.withSignpost("test-string") {
            "signpost"
        }
        XCTAssertEqual(result, "signpost")
    }
}
