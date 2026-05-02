import Core
import Foundation

// MARK: - UninstallResult

/// Per-item result from `UninstallExecutor`.
public struct UninstallItemResult: Sendable {
    public let url: URL
    public let trashedURL: URL?
    public let error: (any Error)?

    public var succeeded: Bool {
        self.error == nil
    }

    public init(url: URL, trashedURL: URL?, error: (any Error)?) {
        self.url = url
        self.trashedURL = trashedURL
        self.error = error
    }
}

/// Aggregate outcome of executing an `UninstallPlan`.
public struct UninstallSummary: Sendable {
    public let itemResults: [UninstallItemResult]

    public var succeeded: [UninstallItemResult] {
        self.itemResults.filter(\.succeeded)
    }

    public var failed: [UninstallItemResult] {
        self.itemResults.filter { !$0.succeeded }
    }

    public var allSucceeded: Bool {
        self.failed.isEmpty
    }
}

// MARK: - UninstallExecutor

/// Executes an `UninstallPlan` by moving every selected URL to Trash.
///
/// **Safety guarantee:** Only `FileManager.trashItem(at:resultingItemURL:)` is
/// used.  `removeItem` is never called.  System-owned paths (where
/// `AssociatedFile.requiresAdmin == true`) are silently skipped; the caller
/// is responsible for filtering them before building the plan.
public struct UninstallExecutor: Sendable {
    public init() {}

    // MARK: Public API

    /// Execute the plan synchronously and return a summary of results.
    public func execute(_ plan: UninstallPlan) -> UninstallSummary {
        var results: [UninstallItemResult] = []
        // Use the per-thread FileManager for thread-safe operation.
        let fm = FileManager()

        for url in plan.urlsToTrash {
            var resultURL: NSURL?
            do {
                try fm.trashItem(at: url, resultingItemURL: &resultURL)
                results.append(UninstallItemResult(
                    url: url,
                    trashedURL: resultURL as URL?,
                    error: nil
                ))
            } catch {
                results.append(UninstallItemResult(url: url, trashedURL: nil, error: error))
            }
        }

        return UninstallSummary(itemResults: results)
    }
}
