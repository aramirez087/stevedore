import Core
import Foundation

/// Stateless implementation of all local file operations.
///
/// `FileManager` is not `Sendable`; each method that needs disk access
/// creates a fresh `FileManager()` instance inside `Task.detached`, which is
/// the correct pattern per Apple's threading guidance for `FileManager`.
struct LocalFileOperations: Sendable {
    // MARK: - Public entry points

    func perform(
        _ op: OperationDescriptor,
        progress: (any OperationProgressReporting)?
    ) async throws -> OperationResult {
        await self.reportProgress(progress, phase: .preparing, done: 0, total: nil, item: nil)

        let result: OperationResult = try await Task.detached(priority: .utility) {
            try Self.dispatch(op)
        }.value

        await self.reportProgress(
            progress,
            phase: .completed,
            done: result.bytesProcessed,
            total: result.bytesProcessed,
            item: nil
        )
        return result
    }

    func detectConflicts(for op: OperationDescriptor) async -> [ConflictDescriptor] {
        await Task.detached(priority: .utility) {
            Self.preflight(op)
        }.value
    }

    // MARK: - Dispatch

    private static func dispatch(_ op: OperationDescriptor) throws -> OperationResult {
        switch op.kind {
        case .copy: return try self.performCopy(op)
        case .move: return try self.performMove(op)
        case .delete: return try self.performDelete(op)
        case .rename: return try self.performRename(op)
        case .mkdir: return try self.performMkdir(op)
        case .symlink: return try self.performSymlink(op)
        case .trash: return try self.performTrash(op)
        case .archive, .extract:
            throw StevedoreError.unsupported("\(op.kind) is handled by FileSystemArchive (Session 05)")
        }
    }

    // MARK: - mkdir

    private static func performMkdir(_ op: OperationDescriptor) throws -> OperationResult {
        guard let dest = op.destination else {
            throw StevedoreError.invalidArgument("mkdir requires a destination path")
        }
        let fm = FileManager()
        let url = URL(fileURLWithPath: dest.posixString)

        if fm.fileExists(atPath: url.path) {
            switch op.conflictPolicy {
            case .skip, .ask: return self.makeResult(op, status: .skipped, bytes: 0, items: 0)
            case .overwrite, .rename: break
            }
        }

        do {
            try fm.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        } catch let nsError as NSError {
            throw mapped(nsError, path: dest)
        }
        return self.makeResult(op, status: .completed, bytes: 0, items: 1)
    }

    // MARK: - copy

    private static func performCopy(_ op: OperationDescriptor) throws -> OperationResult {
        guard let destDir = op.destination else {
            throw StevedoreError.invalidArgument("copy requires a destination path")
        }
        let fm = FileManager()
        var bytesTotal: Int64 = 0
        var itemsDone = 0
        var anySkipped = false

        for source in op.sources {
            let srcURL = URL(fileURLWithPath: source.posixString)
            let name = source.lastComponent ?? srcURL.lastPathComponent
            let destURL = URL(fileURLWithPath: destDir.posixString).appendingPathComponent(name)

            if fm.fileExists(atPath: destURL.path) {
                switch op.conflictPolicy {
                case .skip, .ask:
                    anySkipped = true
                    continue
                case .overwrite:
                    try? fm.removeItem(at: destURL)
                case .rename:
                    let uniqueDest = self.uniqueURL(for: destURL, fm: fm)
                    try self.doCopy(fm: fm, srcURL: srcURL, destURL: uniqueDest, path: source)
                    bytesTotal += self.fileSize(srcURL, fm: fm)
                    itemsDone += 1
                    continue
                }
            }

            try self.doCopy(fm: fm, srcURL: srcURL, destURL: destURL, path: source)
            bytesTotal += self.fileSize(srcURL, fm: fm)
            itemsDone += 1
        }

        let status: OperationResult.Status = anySkipped && itemsDone == 0
            ? .skipped
            : (anySkipped ? .partiallyFailed : .completed)
        return self.makeResult(op, status: status, bytes: bytesTotal, items: itemsDone)
    }

    private static func doCopy(fm: FileManager, srcURL: URL, destURL: URL, path: FilePath) throws {
        do {
            try fm.copyItem(at: srcURL, to: destURL)
        } catch let nsError as NSError {
            throw mapped(nsError, path: path)
        }
    }

    // MARK: - move

    private static func performMove(_ op: OperationDescriptor) throws -> OperationResult {
        guard let destDir = op.destination else {
            throw StevedoreError.invalidArgument("move requires a destination path")
        }
        let fm = FileManager()
        var itemsDone = 0
        var anySkipped = false

        for source in op.sources {
            let srcURL = URL(fileURLWithPath: source.posixString)
            let name = source.lastComponent ?? srcURL.lastPathComponent
            let destURL = URL(fileURLWithPath: destDir.posixString).appendingPathComponent(name)

            if fm.fileExists(atPath: destURL.path) {
                switch op.conflictPolicy {
                case .skip, .ask:
                    anySkipped = true
                    continue
                case .overwrite:
                    try? fm.removeItem(at: destURL)
                case .rename:
                    let uniqueDest = self.uniqueURL(for: destURL, fm: fm)
                    try self.doMove(fm: fm, srcURL: srcURL, destURL: uniqueDest, path: source)
                    itemsDone += 1
                    continue
                }
            }

            try self.doMove(fm: fm, srcURL: srcURL, destURL: destURL, path: source)
            itemsDone += 1
        }

        let status: OperationResult.Status = anySkipped && itemsDone == 0
            ? .skipped
            : (anySkipped ? .partiallyFailed : .completed)
        return self.makeResult(op, status: status, bytes: 0, items: itemsDone)
    }

    private static func doMove(fm: FileManager, srcURL: URL, destURL: URL, path: FilePath) throws {
        do {
            try fm.moveItem(at: srcURL, to: destURL)
        } catch let nsError as NSError {
            throw mapped(nsError, path: path)
        }
    }

    // MARK: - delete

    private static func performDelete(_ op: OperationDescriptor) throws -> OperationResult {
        let fm = FileManager()
        var itemsDone = 0
        for source in op.sources {
            let url = URL(fileURLWithPath: source.posixString)
            guard fm.fileExists(atPath: url.path) else { continue }
            do {
                try fm.removeItem(at: url)
                itemsDone += 1
            } catch let nsError as NSError {
                throw mapped(nsError, path: source)
            }
        }
        return self.makeResult(op, status: .completed, bytes: 0, items: itemsDone)
    }

    // MARK: - rename

    private static func performRename(_ op: OperationDescriptor) throws -> OperationResult {
        guard let source = op.sources.first, let dest = op.destination else {
            throw StevedoreError.invalidArgument("rename requires exactly one source and a destination")
        }
        let fm = FileManager()
        let srcURL = URL(fileURLWithPath: source.posixString)
        let destURL = URL(fileURLWithPath: dest.posixString)

        if fm.fileExists(atPath: destURL.path) {
            switch op.conflictPolicy {
            case .skip, .ask: return self.makeResult(op, status: .skipped, bytes: 0, items: 0)
            case .overwrite: try? fm.removeItem(at: destURL)
            case .rename: break
            }
        }

        do {
            try fm.moveItem(at: srcURL, to: destURL)
        } catch let nsError as NSError {
            throw mapped(nsError, path: source)
        }
        return self.makeResult(op, status: .completed, bytes: 0, items: 1)
    }

    // MARK: - symlink

    private static func performSymlink(_ op: OperationDescriptor) throws -> OperationResult {
        guard let source = op.sources.first, let dest = op.destination else {
            throw StevedoreError.invalidArgument("symlink requires a source and a destination")
        }
        let fm = FileManager()
        do {
            try fm.createSymbolicLink(
                atPath: dest.posixString,
                withDestinationPath: source.posixString
            )
        } catch let nsError as NSError {
            throw mapped(nsError, path: dest)
        }
        return self.makeResult(op, status: .completed, bytes: 0, items: 1)
    }

    // MARK: - trash

    private static func performTrash(_ op: OperationDescriptor) throws -> OperationResult {
        let fm = FileManager()
        var itemsDone = 0
        for source in op.sources {
            let url = URL(fileURLWithPath: source.posixString)
            var trashedURL: NSURL?
            do {
                try fm.trashItem(at: url, resultingItemURL: &trashedURL)
                itemsDone += 1
            } catch let nsError as NSError {
                throw mapped(nsError, path: source)
            }
        }
        return self.makeResult(op, status: .completed, bytes: 0, items: itemsDone)
    }

    // MARK: - Conflict preflight

    private static func preflight(_ op: OperationDescriptor) -> [ConflictDescriptor] {
        guard let destDir = op.destination else { return [] }
        let fm = FileManager()
        var conflicts: [ConflictDescriptor] = []

        for source in op.sources {
            let name = source.lastComponent ?? URL(fileURLWithPath: source.posixString).lastPathComponent
            let destPath = destDir.appending(name)
            let destURL = URL(fileURLWithPath: destPath.posixString)

            if fm.fileExists(atPath: destURL.path) {
                var isDir: ObjCBool = false
                fm.fileExists(atPath: destURL.path, isDirectory: &isDir)
                let reason: ConflictDescriptor.Reason = isDir.boolValue
                    ? .destinationIsDirectory
                    : .destinationExists
                conflicts.append(ConflictDescriptor(
                    source: source,
                    destination: destPath,
                    reason: reason,
                    operationKind: op.kind
                ))
            }

            if op.kind == .move {
                let srcDev = self.deviceID(URL(fileURLWithPath: source.posixString))
                let dstDev = self.deviceID(URL(fileURLWithPath: destDir.posixString))
                if let s = srcDev, let d = dstDev, s != d {
                    conflicts.append(ConflictDescriptor(
                        source: source,
                        destination: destPath,
                        reason: .crossDeviceMove,
                        operationKind: op.kind
                    ))
                }
            }
        }
        return conflicts
    }

    // MARK: - Helpers

    private static func makeResult(
        _ op: OperationDescriptor,
        status: OperationResult.Status,
        bytes: Int64,
        items: Int
    ) -> OperationResult {
        OperationResult(
            descriptorID: op.id,
            status: status,
            bytesProcessed: bytes,
            itemsProcessed: items
        )
    }

    private static func mapped(_ nsError: NSError, path: FilePath) -> StevedoreError {
        switch nsError.code {
        case NSFileReadNoSuchFileError, NSFileNoSuchFileError:
            .fileSystem(.notFound(path))
        case NSFileReadNoPermissionError, NSFileWriteNoPermissionError:
            .fileSystem(.permissionDenied(path))
        case NSFileWriteFileExistsError:
            .fileSystem(.alreadyExists(path))
        default:
            .fileSystem(.ioFailure(detail: nsError.localizedDescription))
        }
    }

    private static func fileSize(_ url: URL, fm: FileManager) -> Int64 {
        let v = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(v?.fileSize ?? 0)
    }

    private static func deviceID(_ url: URL) -> Int? {
        let v = try? url.resourceValues(forKeys: [.volumeIdentifierKey])
        return v?.volumeIdentifier as? Int
    }

    private static func uniqueURL(for url: URL, fm: FileManager) -> URL {
        let dir = url.deletingLastPathComponent()
        let ext = url.pathExtension
        let base = url.deletingPathExtension().lastPathComponent
        var counter = 2
        var candidate = url
        while fm.fileExists(atPath: candidate.path) {
            let name = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)"
            candidate = dir.appendingPathComponent(name)
            counter += 1
        }
        return candidate
    }

    private func reportProgress(
        _ sink: (any OperationProgressReporting)?,
        phase: Core.Progress.Phase,
        done: Int64,
        total: Int64?,
        item: String?
    ) async {
        guard let sink else { return }
        await sink.report(Core.Progress(
            bytesDone: done,
            bytesTotal: total,
            phase: phase,
            currentItemDisplayName: item
        ))
    }
}
