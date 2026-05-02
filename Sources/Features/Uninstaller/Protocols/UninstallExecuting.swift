public protocol UninstallExecuting: Sendable {
    func execute(plan: UninstallPlan) async throws
}
