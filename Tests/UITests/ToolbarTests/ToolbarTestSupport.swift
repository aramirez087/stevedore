import Core
@testable import UIToolbar
import XCTest

/// Instant sleep — tasks complete without real delay in tests.
let immediateSleep: SleepFunction = { _ in }

func makePath(scheme: ConnectionScheme = .local, _ components: [String]) -> FilePath {
    FilePath(scheme: scheme, components: components)
}
