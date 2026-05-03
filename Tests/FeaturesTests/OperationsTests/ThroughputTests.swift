import FeaturesOperations
import Foundation
import XCTest

final class ThroughputTests: XCTestCase {
    func testEmptyWindowReturnsNil() {
        let estimator = ThroughputEstimator()
        XCTAssertNil(estimator.bytesPerSecond)
    }

    func testSingleSampleReturnsNil() {
        var estimator = ThroughputEstimator()
        estimator.record(bytes: 1_000_000)
        // Need at least two samples to compute a rate.
        XCTAssertNil(estimator.bytesPerSecond)
    }

    func testETAZeroWhenNoBytesLeft() {
        var estimator = ThroughputEstimator()
        estimator.record(bytes: 1000)
        XCTAssertEqual(estimator.estimatedSecondsRemaining(bytesLeft: 0), 0)
    }

    func testETANilWhenNoSamples() {
        let estimator = ThroughputEstimator()
        XCTAssertNil(estimator.estimatedSecondsRemaining(bytesLeft: 1000))
    }

    func testMultiSampleRate() async throws {
        var estimator = ThroughputEstimator(windowDuration: .seconds(10))
        // Record two samples separated by ~0.1 seconds:
        // total 2 MB in ~0.1 s → ~20 MB/s
        estimator.record(bytes: 1_000_000)
        try await Task.sleep(for: .milliseconds(100))
        estimator.record(bytes: 1_000_000)
        let bps = estimator.bytesPerSecond
        XCTAssertNotNil(bps)
        // At ~100ms gap, rate should be very high (>5 MB/s). Just check it's positive.
        XCTAssertGreaterThan(try XCTUnwrap(bps), 0)
    }

    func testETAPositive() async throws {
        var estimator = ThroughputEstimator(windowDuration: .seconds(10))
        estimator.record(bytes: 1_000_000)
        try await Task.sleep(for: .milliseconds(100))
        estimator.record(bytes: 1_000_000)
        let eta = estimator.estimatedSecondsRemaining(bytesLeft: 5_000_000)
        XCTAssertNotNil(eta)
        XCTAssertGreaterThan(try XCTUnwrap(eta), 0)
    }
}
