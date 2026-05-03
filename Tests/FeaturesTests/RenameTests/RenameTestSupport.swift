import Core
import FeaturesRename
import Foundation
import XCTest

// MARK: - Filename helpers (mirrors private functions in RenameStep.swift)

func testSplitStemExt(_ filename: String) -> (stem: String, ext: String?) {
    guard let dot = filename.lastIndex(of: "."), dot != filename.startIndex else {
        return (filename, nil)
    }
    return (String(filename[..<dot]), String(filename[filename.index(after: dot)...]))
}

func testAssembled(stem: String, ext: String?) -> String {
    guard let ext else { return stem }
    return stem + "." + ext
}

func applyStep(_ step: RenameStep, to name: String, index: Int = 0) throws -> String {
    let parts = testSplitStemExt(name)
    var stem = parts.stem
    var ext = parts.ext
    try step.apply(to: &stem, ext: &ext, index: index)
    return testAssembled(stem: stem, ext: ext)
}

// MARK: - FileItem helpers

func makeItem(name: String, dir: FilePath = FilePath(scheme: .local, posix: "/test")) -> FileItem {
    FileItem(path: dir.appending(name), kind: .regularFile)
}

// MARK: - RecordingRenameProvider

final actor RecordingRenameProvider: FileSystemProvider {
    nonisolated let scheme: ConnectionScheme = .local
    private var nodes: [FilePath: FileItem] = [:]
    private(set) var renames: [(from: FilePath, to: FilePath)] = []
    var failAtRenameIndices: Set<Int> = []
    private var renameCallCount = 0

    func seed(_ items: [FileItem]) {
        for item in items {
            self.nodes[item.path] = item
        }
    }

    func setFailAtRenameIndices(_ indices: Set<Int>) {
        self.failAtRenameIndices = indices
    }

    func hasNode(at path: FilePath) -> Bool {
        self.nodes[path] != nil
    }

    func attributes(at path: FilePath) async throws -> FileAttributes {
        guard let item = self.nodes[path] else {
            throw StevedoreError.fileSystem(.notFound(path))
        }
        return item.attributes
    }

    nonisolated func enumerate(
        at path: FilePath,
        options: EnumerationOptions
    ) -> AsyncThrowingStream<FileItem, any Error> {
        AsyncThrowingStream { continuation in continuation.finish() }
    }

    func execute(
        _ operation: OperationDescriptor,
        progress: (any OperationProgressReporting)?
    ) async throws -> OperationResult {
        if operation.kind == .rename,
           let source = operation.sources.first,
           let destination = operation.destination {
            self.renameCallCount += 1
            if self.failAtRenameIndices.contains(self.renameCallCount) {
                throw StevedoreError.fileSystem(.permissionDenied(source))
            }
            if let item = self.nodes[source] {
                let renamedItem = FileItem(path: destination, kind: item.kind, attributes: item.attributes)
                self.nodes.removeValue(forKey: source)
                self.nodes[destination] = renamedItem
            }
            self.renames.append((from: source, to: destination))
        }
        return OperationResult(
            descriptorID: operation.id,
            status: .completed,
            bytesProcessed: 0,
            itemsProcessed: 1
        )
    }

    nonisolated func watch(_ path: FilePath) -> AsyncStream<FilePathChange> {
        AsyncStream { continuation in continuation.finish() }
    }
}
