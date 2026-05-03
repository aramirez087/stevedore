import Core
@testable import FileSystemRemote
import Foundation
import os

/// In-memory FTP transport for testing.
public final class FakeFTPTransport: FTPTransport, @unchecked Sendable {
    private struct State {
        var files: [String: Data] = [:]
        var directories: Set<String> = ["/"]
    }

    private let lock: OSAllocatedUnfairLock<State>
    public var mlsdSupported: Bool
    public var listError: (any Error)?

    public init(
        files: [String: Data] = [:],
        directories: [String] = [],
        mlsdSupported: Bool = true
    ) {
        var s = State()
        s.files = files
        s.directories = Set(directories).union(["/"])
        self.lock = OSAllocatedUnfairLock(initialState: s)
        self.mlsdSupported = mlsdSupported
    }

    public func connect() async throws {}

    public func list(at path: String) async throws -> Data {
        if let err = listError { throw err }
        return self.lock.withLock { state in
            var lines: [String] = []
            for (fp, data) in state.files {
                let parent = (fp as NSString).deletingLastPathComponent
                guard (parent.isEmpty ? "/" : parent) == path else { continue }
                let name = (fp as NSString).lastPathComponent
                lines.append("-rw-r--r-- 1 user group \(data.count) Jan  1 12:00 \(name)")
            }
            for dir in state.directories where dir != path {
                let parent = (dir as NSString).deletingLastPathComponent
                guard (parent.isEmpty ? "/" : parent) == path else { continue }
                let name = (dir as NSString).lastPathComponent
                lines.append("drwxr-xr-x 2 user group 4096 Jan  1 12:00 \(name)")
            }
            return Data(lines.joined(separator: "\n").utf8)
        }
    }

    public func mlsd(at path: String) async throws -> Data {
        guard self.mlsdSupported else {
            throw StevedoreError.unsupported("MLSD not supported")
        }
        return self.lock.withLock { state in
            var lines: [String] = []
            for (fp, data) in state.files {
                let parent = (fp as NSString).deletingLastPathComponent
                guard (parent.isEmpty ? "/" : parent) == path else { continue }
                let name = (fp as NSString).lastPathComponent
                lines.append("type=file;size=\(data.count);modify=20240101120000; \(name)")
            }
            for dir in state.directories where dir != path {
                let parent = (dir as NSString).deletingLastPathComponent
                guard (parent.isEmpty ? "/" : parent) == path else { continue }
                let name = (dir as NSString).lastPathComponent
                lines.append("type=dir;size=0;modify=20240101120000; \(name)")
            }
            return Data(lines.joined(separator: "\n").utf8)
        }
    }

    public func retrieve(at path: String) -> AsyncThrowingStream<Data, any Error> {
        let data = self.lock.withLock { $0.files[path] }
        return AsyncThrowingStream { continuation in
            guard let d = data else {
                continuation.finish(
                    throwing: StevedoreError.fileSystem(.notFound(FilePath(scheme: .ftp, posix: path)))
                )
                return
            }
            continuation.yield(d)
            continuation.finish()
        }
    }

    public func store(at path: String, data: AsyncThrowingStream<Data, any Error>) async throws {
        var buffer = Data()
        for try await chunk in data {
            buffer.append(chunk)
        }
        let final = buffer
        _ = self.lock.withLock { $0.files[path] = final }
    }

    public func makeDirectory(at path: String) async throws {
        self.lock.withLock { $0.directories.insert(path) }
    }

    public func rename(from: String, to: String) async throws {
        self.lock.withLock { state in
            if let data = state.files.removeValue(forKey: from) {
                state.files[to] = data
            } else if state.directories.remove(from) != nil {
                state.directories.insert(to)
            }
        }
    }

    public func delete(at path: String) async throws {
        self.lock.withLock { state in
            state.files[path] = nil
            state.directories.remove(path)
        }
    }

    public func disconnect() async {}

    // MARK: - Inspection

    public func file(at path: String) -> Data? {
        self.lock.withLock { $0.files[path] }
    }
}
