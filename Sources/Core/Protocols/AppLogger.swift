/// Uniform logging facade across the app.
///
/// Designed so call sites can pass an `@autoclosure` message — formatting only
/// runs when the level passes the underlying backend's filter. Concrete
/// implementations bridge to `swift-log` and `os.Logger`.
public protocol AppLogger: Sendable {
    // swiftlint:disable:next function_parameter_count
    func log(
        _ level: LogLevel,
        _ message: @autoclosure @Sendable () -> String,
        category: LogCategory,
        metadata: [String: String]?,
        file: StaticString,
        line: UInt
    ) async
}

public extension AppLogger {
    /// Convenience overload omitting metadata + caller-site defaults.
    func log(
        _ level: LogLevel,
        _ message: @autoclosure @Sendable () -> String,
        category: LogCategory = .app,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        await self.log(level, message(), category: category, metadata: nil, file: file, line: line)
    }
}
