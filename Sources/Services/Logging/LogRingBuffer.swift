import Core

/// Bounded ring buffer that retains the most recent `capacity` log events.
/// Thread-safe via actor isolation; `push` is O(1), `snapshot` is O(n).
public actor LogRingBuffer {
    public static let defaultCapacity: Int = 2000

    private let capacity: Int
    private var storage: [LogEvent]
    private var writeIndex: Int = 0

    public init(capacity: Int = 2000) {
        precondition(capacity > 0, "capacity must be positive")
        self.capacity = capacity
        self.storage = []
        self.storage.reserveCapacity(capacity)
    }

    public func push(_ event: LogEvent) {
        if self.storage.count < self.capacity {
            self.storage.append(event)
        } else {
            self.storage[self.writeIndex] = event
            self.writeIndex = (self.writeIndex + 1) % self.capacity
        }
    }

    /// Events in chronological order (oldest first).
    public var snapshot: [LogEvent] {
        guard self.storage.count == self.capacity else { return self.storage }
        return Array(self.storage[self.writeIndex...]) + Array(self.storage[..<self.writeIndex])
    }

    public func snapshot(minLevel: LogLevel) -> [LogEvent] {
        self.snapshot.filter { $0.level >= minLevel }
    }
}
