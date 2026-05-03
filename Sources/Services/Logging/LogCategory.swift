import Core
import OSLog

// Module-internal: only ServicesLogging call sites can reach this property.
extension LogCategory {
    var osLogger: Logger {
        Logger(subsystem: OSLogger.subsystem, category: self.rawValue)
    }
}
