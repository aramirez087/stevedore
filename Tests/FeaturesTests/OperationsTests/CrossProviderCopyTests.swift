import Core
import FeaturesOperations
import Foundation
import XCTest

final class CrossProviderCopyTests: XCTestCase {
    // MARK: - Basic copy

    func testSameDataRoundtrip() async throws {
        let src = FilePath.local("/src/file.bin")
        let dst = FilePath.remote("/dst/file.bin")
        let data = Data(repeating: 0xAB, count: 1024)

        let source = TestDataProvider(scheme: .local)
        await source.seed(file: src, data: data)
        let dest = TestDataProvider(scheme: .sftp)

        let gate = PauseResumeGate()
        let copier = CrossProviderCopy(chunkSize: 256)
        let bytes = try await copier.copy(
            from: src, on: source,
            to: dst, on: dest,
            gate: gate, progress: nil
        )

        let result = await dest.data(at: dst)
        XCTAssertEqual(result, data)
        XCTAssertEqual(bytes, 1024)
    }

    func testChunkedTransfer() async throws {
        let src = FilePath.local("/src/big.bin")
        let dst = FilePath.remote("/dst/big.bin")
        // 3 MB file with 256 KB chunks → 12 chunks
        let data = Data(repeating: 0xFF, count: 3 * 1024 * 1024)

        let source = TestDataProvider(scheme: .local)
        await source.seed(file: src, data: data)
        let dest = TestDataProvider(scheme: .sftp)

        let gate = PauseResumeGate()
        let copier = CrossProviderCopy()
        let bytes = try await copier.copy(from: src, on: source, to: dst, on: dest, gate: gate, progress: nil)
        XCTAssertEqual(bytes, Int64(data.count))

        let result = await dest.data(at: dst)
        XCTAssertEqual(result?.count, data.count)
    }

    func testProgressReportsTransferPhases() async throws {
        let src = FilePath.local("/src/f.bin")
        let dst = FilePath.remote("/dst/f.bin")
        let data = Data(repeating: 0x01, count: 512)

        let source = TestDataProvider(scheme: .local)
        await source.seed(file: src, data: data)
        let dest = TestDataProvider(scheme: .sftp)
        let reporter = RecordingProgressReporter()

        let gate = PauseResumeGate()
        let copier = CrossProviderCopy(chunkSize: 256)
        _ = try await copier.copy(from: src, on: source, to: dst, on: dest, gate: gate, progress: reporter)

        let reports = await reporter.reports
        XCTAssertFalse(reports.isEmpty)
        // Last report should have completed phase.
        XCTAssertEqual(reports.last?.phase, .completed)
    }

    // MARK: - Pause / resume

    func testPauseHaltsByteProgressionWithin100ms() async throws {
        let src = FilePath.local("/src/stream.bin")
        let dst = FilePath.remote("/dst/stream.bin")
        // Large enough that transfer takes > 100ms at tiny chunk sizes.
        let data = Data(repeating: 0xCC, count: 10 * 1024)

        let source = TestDataProvider(scheme: .local)
        await source.seed(file: src, data: data)
        // Slow down the source by using a small simulated chunk size.
        await source.set(simulatedChunkSize: 64)
        let dest = SlowWriteProvider(scheme: .sftp, writeDelay: .milliseconds(5))

        let gate = PauseResumeGate()
        let copier = CrossProviderCopy(chunkSize: 64)

        let copyTask = Task {
            try await copier.copy(from: src, on: source, to: dst, on: dest, gate: gate, progress: nil)
        }

        // Let a few chunks transfer.
        try await Task.sleep(for: .milliseconds(20))
        let bytesBefore = await dest.bytesWritten

        // Pause the gate.
        await gate.pause()
        let pauseTime = ContinuousClock.now

        // Wait 100ms and verify byte count didn't advance significantly.
        try await Task.sleep(for: .milliseconds(100))
        let bytesAfterPause = await dest.bytesWritten
        let elapsed = ContinuousClock.now - pauseTime

        // Resume so the copy can complete.
        await gate.resume()
        _ = try await copyTask.value

        // Bytes should not have advanced more than one chunk after pause.
        let chunkSize = 64
        XCTAssertLessThanOrEqual(
            Int(bytesAfterPause - bytesBefore),
            chunkSize,
            "Pause should halt byte progression within one chunk (≤\(chunkSize) bytes)"
        )
        XCTAssertLessThanOrEqual(elapsed.components.attoseconds, 150 * 1_000_000_000_000_000)
    }

    func testResumeFromSameOffset() async throws {
        let src = FilePath.local("/src/r.bin")
        let dst = FilePath.remote("/dst/r.bin")
        let data = Data((0 ..< 256).map { UInt8($0) })

        let source = TestDataProvider(scheme: .local)
        await source.seed(file: src, data: data)
        let dest = TestDataProvider(scheme: .sftp)

        let gate = PauseResumeGate()
        await gate.pause()

        let copyTask = Task {
            try await CrossProviderCopy(chunkSize: 64).copy(
                from: src, on: source, to: dst, on: dest, gate: gate, progress: nil
            )
        }

        // Immediately resume — gate was never really blocking (task hadn't started yet).
        await gate.resume()
        let bytes = try await copyTask.value
        XCTAssertEqual(bytes, 256)

        let result = await dest.data(at: dst)
        XCTAssertEqual(result, data)
    }

    // MARK: - Cancellation

    func testCancelCleansUpPartialFile() async throws {
        let src = FilePath.local("/src/large.bin")
        let dst = FilePath.remote("/dst/large.bin")
        // 64KB data, 1KB chunks, slow write (5ms each) → ~320ms total
        let data = Data(repeating: 0xDE, count: 64 * 1024)

        let source = TestDataProvider(scheme: .local)
        await source.seed(file: src, data: data)
        await source.set(simulatedChunkSize: 1024)
        // Use a slow writer so cancellation can interrupt mid-transfer.
        let dest = SlowWriteProvider(scheme: .sftp, writeDelay: .milliseconds(5))

        let gate = PauseResumeGate()
        let copier = CrossProviderCopy(chunkSize: 1024)

        let copyTask = Task {
            try await copier.copy(from: src, on: source, to: dst, on: dest, gate: gate, progress: nil)
        }
        // Wait for a few chunks to transfer, then cancel.
        try await Task.sleep(for: .milliseconds(25))
        copyTask.cancel()

        do {
            _ = try await copyTask.value
        } catch {
            // Expected: CancellationError
        }

        let deleteCalls = await dest.deletePartialCalls
        XCTAssertTrue(
            deleteCalls.contains(dst),
            "deletePartial should be called for the destination path on cancellation"
        )
    }

    // MARK: - Conflict policies

    func testConflictReplaceOverwritesDestination() async throws {
        let src = FilePath.local("/src/f.txt")
        let dst = FilePath.remote("/dst/f.txt")
        let original = Data("original".utf8)
        let replacement = Data("replacement".utf8)

        let source = TestDataProvider(scheme: .local)
        await source.seed(file: src, data: replacement)
        let dest = TestDataProvider(scheme: .sftp)
        await dest.seed(file: dst, data: original)

        let gate = PauseResumeGate()
        let copier = CrossProviderCopy()
        _ = try await copier.copy(from: src, on: source, to: dst, on: dest, gate: gate, progress: nil)

        let result = await dest.data(at: dst)
        XCTAssertEqual(result, replacement)
    }

    func testCrossProviderCopyMissingSource() async throws {
        let src = FilePath.local("/src/missing.txt")
        let dst = FilePath.remote("/dst/missing.txt")

        let source = TestDataProvider(scheme: .local) // file not seeded
        let dest = TestDataProvider(scheme: .sftp)

        let gate = PauseResumeGate()
        let copier = CrossProviderCopy()

        do {
            _ = try await copier.copy(from: src, on: source, to: dst, on: dest, gate: gate, progress: nil)
            XCTFail("Expected error for missing source")
        } catch let err as StevedoreError {
            if case .fileSystem(.notFound) = err {} else { XCTFail("Expected .notFound, got \(err)") }
        }
    }
}

// MARK: - SlowWriteProvider

/// A `DataWritableProvider` that introduces a small delay per write for pause/resume testing.
private actor SlowWriteProvider: DataWritableProvider {
    let scheme: ConnectionScheme
    let writeDelay: Duration
    private var chunks: [FilePath: Data] = [:]
    private(set) var bytesWritten: Int64 = 0
    private(set) var deletePartialCalls: [FilePath] = []

    init(scheme: ConnectionScheme, writeDelay: Duration) {
        self.scheme = scheme
        self.writeDelay = writeDelay
    }

    func attributes(at path: FilePath) async throws -> FileAttributes {
        guard let data = self.chunks[path] else {
            throw StevedoreError.fileSystem(.notFound(path))
        }
        return FileAttributes(sizeInBytes: Int64(data.count))
    }

    nonisolated func enumerate(at: FilePath, options: EnumerationOptions) -> AsyncThrowingStream<FileItem, any Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func execute(_ op: OperationDescriptor,
                 progress: (any OperationProgressReporting)?) async throws -> OperationResult {
        throw StevedoreError.unsupported("SlowWriteProvider.execute not implemented")
    }

    nonisolated func watch(_ path: FilePath) -> AsyncStream<FilePathChange> {
        AsyncStream { $0.finish() }
    }

    nonisolated func read(at path: FilePath, chunkSize: Int) -> AsyncThrowingStream<Data, any Error> {
        AsyncThrowingStream { $0.finish(throwing: StevedoreError.unsupported("not readable")) }
    }

    func writeChunk(_ data: Data, to destination: FilePath, isFirst: Bool, isLast: Bool) async throws {
        try await Task.sleep(for: self.writeDelay)
        if isFirst {
            self.chunks[destination] = data
        } else {
            self.chunks[destination, default: Data()].append(data)
        }
        self.bytesWritten += Int64(data.count)
    }

    func deletePartial(at path: FilePath) async throws {
        self.deletePartialCalls.append(path)
        self.chunks.removeValue(forKey: path)
    }
}

// MARK: - TestDataProvider extension for test control

extension TestDataProvider {
    func set(simulatedChunkSize size: Int) {
        self.simulatedChunkSize = size
    }
}
