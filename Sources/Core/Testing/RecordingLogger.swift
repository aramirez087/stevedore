import Foundation

/// In-memory `AppLogger` that records every call for inspection in tests.
///
/// Actor-isolated so concurrent producers cannot tear the event log; the
/// `events` snapshot is returned by value to keep callers Sendable-clean.
public actor RecordingLogger: AppLogger {
    public struct Event: Hashable, Sendable {
        public let level: LogLevel
        public let message: String
        public let category: LogCategory
        public let metadata: [String: String]
        public let file: String
        public let line: UInt
    }

    private var recorded: [Event] = []

    public init() {}

    // swiftlint:disable:next function_parameter_count
    public func log(
        _ level: LogLevel,
        _ message: @autoclosure @Sendable () -> String,
        category: LogCategory,
        metadata: [String: String]?,
        file: StaticString,
        line: UInt
    ) async {
        let event = Event(
            level: level,
            message: message(),
            category: category,
            metadata: metadata ?? [:],
            file: String(describing: file),
            line: line
        )
        self.recorded.append(event)
    }

    /// Snapshot of all events captured so far.
    public var events: [Event] {
        self.recorded
    }

    /// Drop all recorded events.
    public func reset() {
        self.recorded.removeAll()
    }
}
