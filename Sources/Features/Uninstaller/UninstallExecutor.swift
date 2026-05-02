import Foundation

public actor UninstallExecutor: UninstallExecuting {
    public init() {}

    public func execute(plan: UninstallPlan) async throws {
        for file in plan.selectedFiles where !file.requiresAdmin {
            do {
                try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
            } catch {
                throw UninstallerError.trashFailed(file.url, error)
            }
        }
        do {
            try FileManager.default.trashItem(at: plan.appMetadata.bundleURL, resultingItemURL: nil)
        } catch {
            throw UninstallerError.trashFailed(plan.appMetadata.bundleURL, error)
        }
    }
}
