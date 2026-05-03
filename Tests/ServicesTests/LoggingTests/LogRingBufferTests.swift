import Core
import ServicesLogging
import XCTest

final class LogRingBufferTests: XCTestCase {
    private func makeEvent(message: String, level: LogLevel = .info) -> LogEvent {
        LogEvent(category: .app, level: level, message: message)
    }

    func testPushWithinCapacity() async {
        let buffer = LogRingBuffer(capacity: 10)
        for i in 0 ..< 5 {
            await buffer.push(self.makeEvent(message: "event\(i)"))
        }
        let snap = await buffer.snapshot
        XCTAssertEqual(snap.count, 5)
    }

    func testEvictionPreservesChronologicalOrder() async {
        let buffer = LogRingBuffer(capacity: 3)
        let messages = ["A", "B", "C", "D", "E"]
        for msg in messages {
            await buffer.push(self.makeEvent(message: msg))
        }
        let snap = await buffer.snapshot
        XCTAssertEqual(snap.count, 3)
        XCTAssertEqual(snap.map(\.message), ["C", "D", "E"])
    }

    func testBurstWriteRespectsBounds() async {
        let buffer = LogRingBuffer(capacity: 2000)
        let start = Date()
        for i in 0 ..< 10000 {
            await buffer.push(self.makeEvent(message: "burst\(i)"))
        }
        let elapsed = Date().timeIntervalSince(start)
        let snap = await buffer.snapshot
        XCTAssertEqual(snap.count, 2000)
        XCTAssertLessThan(elapsed, 1.0, "10k pushes should complete in under 1 second")
    }

    func testLevelFilterReturnsMatchingEvents() async {
        let buffer = LogRingBuffer(capacity: 10)
        await buffer.push(self.makeEvent(message: "debug-msg", level: .debug))
        await buffer.push(self.makeEvent(message: "error-msg", level: .error))
        let filtered = await buffer.snapshot(minLevel: .error)
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered[0].message, "error-msg")
    }

    func testSnapshotIsEmptyInitially() async {
        let buffer = LogRingBuffer(capacity: 5)
        let snap = await buffer.snapshot
        XCTAssertTrue(snap.isEmpty)
    }
}
