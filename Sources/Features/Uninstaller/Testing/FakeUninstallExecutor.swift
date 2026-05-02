import Foundation
import os

public final class FakeUninstallExecutor: UninstallExecuting, @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock<[UninstallPlan]>(initialState: [])
    public var error: (any Error)?

    public init(error: (any Error)? = nil) {
        self.error = error
    }

    public var executedPlans: [UninstallPlan] {
        self.lock.withLock { $0 }
    }

    public func execute(plan: UninstallPlan) async throws {
        if let error = self.error { throw error }
        self.lock.withLock { $0.append(plan) }
    }
}
