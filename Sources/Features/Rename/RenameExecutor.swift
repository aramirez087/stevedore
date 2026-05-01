import Core
import os

public actor RenameExecutor {
    public struct JournalEntry: Sendable {
        public let originalPath: FilePath
        public let renamedPath: FilePath
    }

    public private(set) var journal: [JournalEntry] = []

    private let logger = Logger(subsystem: "com.stevedore", category: "RenameExecutor")

    public init() {}

    public func execute(
        outcomes: [RenameOutcome],
        in directory: FilePath,
        using provider: any FileSystemProvider
    ) async throws {
        for outcome in outcomes where outcome.status == .ok {
            let source = outcome.item.path
            let destination = directory.appending(outcome.targetName)
            let descriptor = OperationDescriptor(
                kind: .rename,
                sources: [source],
                destination: destination
            )
            do {
                _ = try await provider.execute(descriptor, progress: nil)
                self.journal.append(JournalEntry(originalPath: source, renamedPath: destination))
            } catch {
                await self.rollback(using: provider)
                throw error
            }
        }
    }

    public func reset() {
        self.journal = []
    }

    private func rollback(using provider: any FileSystemProvider) async {
        for entry in self.journal.reversed() {
            let descriptor = OperationDescriptor(
                kind: .rename,
                sources: [entry.renamedPath],
                destination: entry.originalPath
            )
            do {
                _ = try await provider.execute(descriptor, progress: nil)
            } catch {
                self.logger.error("Rollback failed for \(entry.renamedPath.posixString): \(error.localizedDescription)")
            }
        }
    }
}
