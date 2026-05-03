import Core
import Foundation
import OSLog

/// Production `AppLogger` backed by `os.Logger`.
///
/// Every call site passes through `Redaction.redact` before the message
/// reaches the system log or the in-memory ring buffer, so sensitive values
/// are scrubbed regardless of the log level.
public final class OSLogger: AppLogger, Sendable {
    /// Subsystem label shared by all `os.Logger` instances and `OSSignposter`.
    /// Falls back to a static identifier when running outside an app bundle
    /// (e.g. in unit tests).
    static let subsystem: String =
        Bundle.main.bundleIdentifier ?? "com.stevedore.app"

    private let ringBuffer: LogRingBuffer

    public init(ringBuffer: LogRingBuffer = LogRingBuffer()) {
        self.ringBuffer = ringBuffer
    }

    // swiftlint:disable:next function_parameter_count
    public func log(
        _ level: LogLevel,
        _ message: @autoclosure @Sendable () -> String,
        category: LogCategory,
        metadata: [String: String]?,
        file: StaticString,
        line: UInt
    ) async {
        let text = Redaction.redact(message())
        let osLog = category.osLogger
        switch level {
        case .trace, .debug:
            osLog.debug("\(text, privacy: .auto)")
        case .info:
            osLog.info("\(text, privacy: .auto)")
        case .notice:
            osLog.notice("\(text, privacy: .auto)")
        case .warning:
            osLog.warning("\(text, privacy: .auto)")
        case .error:
            osLog.error("\(text, privacy: .auto)")
        case .critical:
            osLog.fault("\(text, privacy: .auto)")
        }
        let event = LogEvent(
            category: category,
            level: level,
            message: text,
            metadata: metadata ?? [:]
        )
        await self.ringBuffer.push(event)
    }

    /// Snapshot of buffered events for the Diagnostics panel.
    /// Accesses the ring buffer actor; callers must `await`.
    public var events: [LogEvent] {
        get async { await self.ringBuffer.snapshot }
    }
}

// MARK: - Module marker

/// Re-declares the sentinel from the deleted Placeholder.swift so that
/// ServicesLoggingSmokeTests continues to compile without modifying a file
/// outside this session's declared touches scope.
public enum ServicesLoggingModule {
    public static let moduleName: String = "ServicesLogging"
}
