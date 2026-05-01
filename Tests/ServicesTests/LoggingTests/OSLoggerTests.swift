import Core
import ServicesLogging
import XCTest

final class OSLoggerTests: XCTestCase {
    func testLogEventStoredInRingBuffer() async {
        let logger = OSLogger()
        await logger.log(.info, "hello", category: .app, metadata: nil, file: #file, line: #line)
        let events = await logger.events
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].level, .info)
        XCTAssertEqual(events[0].category, .app)
        XCTAssertEqual(events[0].message, "hello")
    }

    func testRedactionAppliedBeforeRingBufferWrite() async {
        let logger = OSLogger()
        await logger.log(
            .info,
            "key AKIAIOSFODNN7EXAMPLE used",
            category: .credentials,
            metadata: nil,
            file: #file,
            line: #line
        )
        let events = await logger.events
        XCTAssertEqual(events.count, 1)
        XCTAssertFalse(events[0].message.contains("AKIAIOSFODNN7EXAMPLE"))
        XCTAssertTrue(events[0].message.contains("[REDACTED-AWS-KEY]"))
    }

    func testMetadataStoredInEvent() async {
        let logger = OSLogger()
        let meta = ["requestId": "abc-123", "userId": "u99"]
        await logger.log(.debug, "with meta", category: .operations, metadata: meta, file: #file, line: #line)
        let events = await logger.events
        XCTAssertEqual(events[0].metadata, meta)
    }

    func testEventsPropertyMatchesRingBufferSnapshot() async {
        let buffer = LogRingBuffer()
        let logger = OSLogger(ringBuffer: buffer)
        await logger.log(.notice, "test event", category: .sync, metadata: nil, file: #file, line: #line)
        let fromLogger = await logger.events
        let fromBuffer = await buffer.snapshot
        XCTAssertEqual(fromLogger, fromBuffer)
    }

    func testConformsToAppLoggerProtocol() async {
        let logger: any AppLogger = OSLogger()
        await logger.log(.error, "protocol call", category: .ui, metadata: nil, file: #file, line: #line)
        // Verified by compilation: OSLogger satisfies the AppLogger contract.
    }

    func testMultipleLevelsAllStored() async {
        let logger = OSLogger()
        await logger.log(.debug, "d", category: .app, metadata: nil, file: #file, line: #line)
        await logger.log(.info, "i", category: .app, metadata: nil, file: #file, line: #line)
        await logger.log(.error, "e", category: .app, metadata: nil, file: #file, line: #line)
        let events = await logger.events
        XCTAssertEqual(events.count, 3)
        XCTAssertEqual(events.map(\.level), [.debug, .info, .error])
    }
}
