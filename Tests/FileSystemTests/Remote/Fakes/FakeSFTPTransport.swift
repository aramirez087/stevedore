import Core
@testable import FileSystemRemote
import Foundation
import os

/// In-memory SFTP transport for testing.
///
/// Uses `OSAllocatedUnfairLock` so state is accessible from both sync
/// (`readFile`) and async (`listDirectory`, `stat`, …) contexts.
public final class FakeSFTPTransport: SFTPTransport, @unchecked Sendable {
    private struct State {
        var files: [String: Data] = [:]
        var directories: Set<String> = ["/"]
    }

    private let lock: OSAllocatedUnfairLock<State>

    public init(files: [String: Data] = [:], directories: [String] = []) {
        var s = State()
        s.files = files
        s.directories = Set(directories).union(["/"])
        self.lock = OSAllocatedUnfairLock(initialState: s)
    }

    public func listDirectory(at path: String) async throws -> [SFTPEntry] {
        self.lock.withLock { state in
            var entries: [SFTPEntry] = []
            for (fp, data) in state.files {
                let parent = (fp as NSString).deletingLastPathComponent
                guard (parent.isEmpty ? "/" : parent) == path else { continue }
                entries.append(SFTPEntry(
                    name: (fp as NSString).lastPathComponent,
                    posixPath: fp,
                    isDirectory: false,
                    sizeInBytes: Int64(data.count)
                ))
            }
            for dir in state.directories where dir != path {
                let parent = (dir as NSString).deletingLastPathComponent
                guard (parent.isEmpty ? "/" : parent) == path else { continue }
                entries.append(SFTPEntry(
                    name: (dir as NSString).lastPathComponent,
                    posixPath: dir,
                    isDirectory: true
                ))
            }
            return entries
        }
    }

    public func stat(at path: String) async throws -> SFTPEntry {
        try self.lock.withLock { state in
            if state.directories.contains(path) {
                let name = (path as NSString).lastPathComponent.isEmpty ? "/" :
                    (path as NSString).lastPathComponent
                return SFTPEntry(name: name, posixPath: path, isDirectory: true)
            }
            if let data = state.files[path] {
                return SFTPEntry(
                    name: (path as NSString).lastPathComponent,
                    posixPath: path,
                    isDirectory: false,
                    sizeInBytes: Int64(data.count)
                )
            }
            throw StevedoreError.fileSystem(.notFound(FilePath(scheme: .sftp, posix: path)))
        }
    }

    public func createDirectory(at path: String) async throws {
        self.lock.withLock { $0.directories.insert(path) }
    }

    public func rename(from source: String, to destination: String) async throws {
        self.lock.withLock { state in
            if let data = state.files.removeValue(forKey: source) {
                state.files[destination] = data
            } else if state.directories.remove(source) != nil {
                state.directories.insert(destination)
            }
        }
    }

    public func remove(at path: String) async throws {
        self.lock.withLock { state in
            state.files[path] = nil
            state.directories.remove(path)
        }
    }

    public func readFile(at path: String, fromOffset offset: UInt64) -> AsyncThrowingStream<Data, any Error> {
        let data = self.lock.withLock { $0.files[path] }
        return AsyncThrowingStream { continuation in
            guard let d = data else {
                continuation.finish(
                    throwing: StevedoreError.fileSystem(.notFound(FilePath(scheme: .sftp, posix: path)))
                )
                return
            }
            let slice = Int(offset) < d.count ? d.dropFirst(Int(offset)) : Data()
            if !slice.isEmpty { continuation.yield(Data(slice)) }
            continuation.finish()
        }
    }

    public func writeFile(at path: String, data: AsyncThrowingStream<Data, any Error>) async throws {
        var buffer = Data()
        for try await chunk in data {
            buffer.append(chunk)
        }
        let final = buffer
        _ = self.lock.withLock { $0.files[path] = final }
    }

    public func chmod(at path: String, permissions: UInt32) async throws {}

    // MARK: - Inspection

    public func file(at path: String) -> Data? {
        self.lock.withLock { $0.files[path] }
    }

    public func hasDirectory(_ path: String) -> Bool {
        self.lock.withLock { $0.directories.contains(path) }
    }
}
