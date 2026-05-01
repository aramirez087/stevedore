import Core
import Foundation
import ServicesLogging
import XCTest

final class LogEventTests: XCTestCase {
    func testCodableRoundTrip() throws {
        let original = LogEvent(
            id: UUID(),
            timestamp: Date(timeIntervalSince1970: 1_000_000),
            category: .fileSystem,
            level: .warning,
            message: "round-trip test",
            metadata: ["key": "value"]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LogEvent.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testHashableEqualWhenFieldsMatch() {
        let id = UUID()
        let ts = Date(timeIntervalSince1970: 42)
        let a = LogEvent(id: id, timestamp: ts, category: .ui, level: .info, message: "hello")
        let b = LogEvent(id: id, timestamp: ts, category: .ui, level: .info, message: "hello")
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testHashableUnequalWhenIdDiffers() {
        let ts = Date(timeIntervalSince1970: 42)
        let a = LogEvent(id: UUID(), timestamp: ts, category: .ui, level: .info, message: "hello")
        let b = LogEvent(id: UUID(), timestamp: ts, category: .ui, level: .info, message: "hello")
        XCTAssertNotEqual(a, b)
    }

    func testDefaultIdAndTimestampAreGenerated() {
        let event = LogEvent(category: .app, level: .debug, message: "test")
        XCTAssertNotEqual(event.id, UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
        XCTAssertGreaterThan(event.timestamp.timeIntervalSince1970, 0)
    }

    func testDefaultMetadataIsEmpty() {
        let event = LogEvent(category: .remote, level: .error, message: "msg")
        XCTAssertTrue(event.metadata.isEmpty)
    }
}
