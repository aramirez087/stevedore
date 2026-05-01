import Core
import Foundation

/// Interprets an `Operation` against the appropriate provider(s) and executes it.
///
/// - Same-scheme operations delegate to the source provider's `execute(_:progress:)`.
/// - Cross-scheme operations use `CrossProviderCopy` when both providers conform
///   to `DataReadableProvider` and `DataWritableProvider`.
/// - Operations requiring cross-provider transfer that lack data protocol conformance
///   throw `StevedoreError.unsupported`.
public struct OperationExecutor: Sendable {
    public let providers: [ConnectionScheme: any FileSystemProvider]
    public let conflictResolver: ConflictResolver
    public let progressTracker: TransferProgressTracker

    public init(
        providers: [ConnectionScheme: any FileSystemProvider],
        conflictResolver: ConflictResolver,
        progressTracker: TransferProgressTracker
    ) {
        self.providers = providers
        self.conflictResolver = conflictResolver
        self.progressTracker = progressTracker
    }

    /// Execute `operation`, pausing at `gate` checkpoints.
    public func execute(
        _ operation: Operation,
        gate: PauseResumeGate
    ) async throws -> OperationResult {
        let descriptor = operation.descriptor
        let sourceScheme = descriptor.sources.first?.scheme
        let destScheme = descriptor.destination?.scheme

        // Determine the primary scheme. For destination-only ops (mkdir, etc.),
        // fall back to the destination scheme; sources are optional for such ops.
        let primaryScheme = sourceScheme ?? destScheme
        guard let srcScheme = primaryScheme else {
            throw StevedoreError.invalidArgument("no source paths provided")
        }
        guard let sourceProvider = self.providers[srcScheme] else {
            throw StevedoreError.unsupported("no provider registered for scheme \(srcScheme)")
        }

        // Same-scheme or no destination: delegate to provider.
        if destScheme == nil || destScheme == srcScheme {
            return try await self.executeSameProvider(
                descriptor: descriptor,
                sourceProvider: sourceProvider,
                gate: gate
            )
        }

        // Cross-scheme copy/move.
        guard let dst = descriptor.destination, let dstScheme = destScheme else {
            throw StevedoreError.invalidArgument("no destination for cross-provider operation")
        }
        guard let destProvider = self.providers[dstScheme] else {
            throw StevedoreError.unsupported("no provider registered for scheme \(dstScheme)")
        }

        return try await self.executeCrossProvider(
            descriptor: descriptor,
            sourceProvider: sourceProvider,
            destProvider: destProvider,
            destination: dst,
            gate: gate
        )
    }

    // MARK: Private

    private func executeSameProvider(
        descriptor: OperationDescriptor,
        sourceProvider: any FileSystemProvider,
        gate: PauseResumeGate
    ) async throws -> OperationResult {
        // Check for conflict before delegating.
        if let dest = descriptor.destination,
           descriptor.kind == .copy || descriptor.kind == .move {
            let destExists = await (try? sourceProvider.attributes(at: dest)) != nil
            if destExists {
                let resolution = await self.conflictResolver.resolve(
                    source: descriptor.sources.first ?? dest,
                    destination: dest,
                    policy: descriptor.conflictPolicy
                )
                if resolution == .skip {
                    return OperationResult(
                        descriptorID: descriptor.id,
                        status: .skipped,
                        bytesProcessed: 0,
                        itemsProcessed: 0
                    )
                }
                // .replace and .renameWithSuffix both proceed — the provider handles the
                // actual conflict resolution (rename suffix not supported at provider level;
                // it falls through to overwrite for same-provider ops).
            }
        }

        let reporter = ProgressBridge(
            operationID: descriptor.id,
            tracker: self.progressTracker
        )
        return try await sourceProvider.execute(descriptor, progress: reporter)
    }

    private func executeCrossProvider(
        descriptor: OperationDescriptor,
        sourceProvider: any FileSystemProvider,
        destProvider: any FileSystemProvider,
        destination: FilePath,
        gate: PauseResumeGate
    ) async throws -> OperationResult {
        guard
            let readable = sourceProvider as? any DataReadableProvider,
            let writable = destProvider as? any DataWritableProvider
        else {
            throw StevedoreError.unsupported(
                "Cross-provider copy requires DataReadableProvider/DataWritableProvider conformance"
            )
        }

        // Conflict check on destination.
        let destExists = await (try? destProvider.attributes(at: destination)) != nil
        if destExists {
            let src = descriptor.sources.first ?? destination
            let resolution = await self.conflictResolver.resolve(
                source: src,
                destination: destination,
                policy: descriptor.conflictPolicy
            )
            switch resolution {
            case .skip:
                return OperationResult(
                    descriptorID: descriptor.id,
                    status: .skipped,
                    bytesProcessed: 0,
                    itemsProcessed: 0
                )
            case .replace:
                break // proceed; writeChunk with isFirst=true truncates
            case .renameWithSuffix:
                // Collect existing paths at destination for uniqueness check.
                let existingPaths = await Self.collectPaths(at: destination.parent, provider: destProvider)
                let unique = ConflictResolver.uniquePath(
                    for: destination,
                    existingPaths: existingPaths
                )
                return try await self.copyFile(
                    descriptor: descriptor,
                    source: descriptor.sources.first ?? destination,
                    destination: unique,
                    readable: readable,
                    writable: writable,
                    gate: gate
                )
            }
        }

        return try await self.copyFile(
            descriptor: descriptor,
            source: descriptor.sources.first ?? destination,
            destination: destination,
            readable: readable,
            writable: writable,
            gate: gate
        )
    }

    // swiftlint:disable function_parameter_count
    private func copyFile(
        descriptor: OperationDescriptor,
        source: FilePath,
        destination: FilePath,
        readable: any DataReadableProvider,
        writable: any DataWritableProvider,
        gate: PauseResumeGate
    ) async throws -> OperationResult {
        let reporter = ProgressBridge(
            operationID: descriptor.id,
            tracker: self.progressTracker
        )
        let copier = CrossProviderCopy()
        let bytes = try await copier.copy(
            from: source,
            on: readable,
            to: destination,
            on: writable,
            gate: gate,
            progress: reporter
        )
        return OperationResult(
            descriptorID: descriptor.id,
            status: .completed,
            bytesProcessed: bytes,
            itemsProcessed: 1
        )
    }

    // swiftlint:enable function_parameter_count

    private static func collectPaths(
        at parent: FilePath?,
        provider: any FileSystemProvider
    ) async -> Set<FilePath> {
        guard let parent else { return [] }
        var paths = Set<FilePath>()
        let stream = provider.enumerate(at: parent, options: .default)
        do {
            for try await item in stream {
                paths.insert(item.path)
            }
        } catch {
            // Best-effort: return whatever was collected before the error.
        }
        return paths
    }
}

// MARK: - ProgressBridge

/// Adapts `TransferProgressTracker.update` to the `OperationProgressReporting` protocol.
private struct ProgressBridge: OperationProgressReporting {
    let operationID: OperationDescriptor.ID
    let tracker: TransferProgressTracker

    func report(_ coreProgress: Core.Progress) async {
        var tp = TransferProgress(operationID: self.operationID)
        tp.bytesCompleted = coreProgress.bytesDone
        tp.bytesTotal = coreProgress.bytesTotal
        tp.throughputBytesPerSecond = coreProgress.throughputBytesPerSecond
        await self.tracker.update(tp)
    }
}
