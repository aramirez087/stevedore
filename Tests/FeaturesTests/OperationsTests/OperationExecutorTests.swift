import Core
import FeaturesOperations
import Foundation
import XCTest

final class OperationExecutorTests: XCTestCase {
    // MARK: - Helpers

    private func makeExecutor(
        localProvider: TestDataProvider? = nil,
        remoteProvider: TestDataProvider? = nil
    ) async -> OperationExecutor {
        var providers: [ConnectionScheme: any FileSystemProvider] = [:]
        if let local = localProvider {
            providers[.local] = local
        }
        if let remote = remoteProvider {
            providers[.sftp] = remote
        }
        let tracker = TransferProgressTracker()
        let resolver = ConflictResolver()
        return OperationExecutor(
            providers: providers,
            conflictResolver: resolver,
            progressTracker: tracker
        )
    }

    // MARK: - Same-provider operations

    func testSameProviderMkdir() async throws {
        let provider = TestDataProvider(scheme: .local)
        let executor = await makeExecutor(localProvider: provider)
        let gate = PauseResumeGate()

        let dir = FilePath.local("/new/dir")
        let descriptor = OperationDescriptor(kind: .mkdir, sources: [], destination: dir)
        let op = Operation(descriptor: descriptor)
        let result = try await executor.execute(op, gate: gate)
        XCTAssertEqual(result.status, .completed)
    }

    func testSameProviderDelete() async throws {
        let provider = TestDataProvider(scheme: .local)
        let src = FilePath.local("/to/delete.txt")
        await provider.seed(file: src, data: Data("content".utf8))

        let executor = await makeExecutor(localProvider: provider)
        let gate = PauseResumeGate()
        let descriptor = OperationDescriptor(kind: .delete, sources: [src])
        let op = Operation(descriptor: descriptor)
        let result = try await executor.execute(op, gate: gate)
        XCTAssertEqual(result.status, .completed)
    }

    func testSameProviderRename() async throws {
        let provider = TestDataProvider(scheme: .local)
        let src = FilePath.local("/old.txt")
        let dst = FilePath.local("/new.txt")
        await provider.seed(file: src, data: Data("hello".utf8))

        let executor = await makeExecutor(localProvider: provider)
        let gate = PauseResumeGate()
        let descriptor = OperationDescriptor(kind: .rename, sources: [src], destination: dst)
        let op = Operation(descriptor: descriptor)
        let result = try await executor.execute(op, gate: gate)
        XCTAssertEqual(result.status, .completed)
    }

    // MARK: - Cross-provider

    func testCrossProviderCopyDataIntegrity() async throws {
        let local = TestDataProvider(scheme: .local)
        let remote = TestDataProvider(scheme: .sftp)

        let src = FilePath.local("/src/data.bin")
        let dst = FilePath.remote("/dst/data.bin")
        let data = Data((0 ..< 256).map { UInt8($0) })
        await local.seed(file: src, data: data)

        let executor = await makeExecutor(localProvider: local, remoteProvider: remote)
        let gate = PauseResumeGate()
        let descriptor = OperationDescriptor(kind: .copy, sources: [src], destination: dst)
        let op = Operation(descriptor: descriptor)
        let result = try await executor.execute(op, gate: gate)

        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(result.bytesProcessed, 256)
        let received = await remote.data(at: dst)
        XCTAssertEqual(received, data)
    }

    func testCrossProviderConflictSkip() async throws {
        let local = TestDataProvider(scheme: .local)
        let remote = TestDataProvider(scheme: .sftp)

        let src = FilePath.local("/src/f.txt")
        let dst = FilePath.remote("/dst/f.txt")
        await local.seed(file: src, data: Data("new".utf8))
        await remote.seed(file: dst, data: Data("existing".utf8))

        let executor = await makeExecutor(localProvider: local, remoteProvider: remote)
        let gate = PauseResumeGate()
        let descriptor = OperationDescriptor(
            kind: .copy, sources: [src], destination: dst, conflictPolicy: .skip
        )
        let op = Operation(descriptor: descriptor)
        let result = try await executor.execute(op, gate: gate)

        XCTAssertEqual(result.status, .skipped)
        // Original file should be unchanged.
        let existing = await remote.data(at: dst)
        XCTAssertEqual(existing, Data("existing".utf8))
    }

    func testMissingProviderThrows() async throws {
        let executor = await makeExecutor()
        let gate = PauseResumeGate()
        let descriptor = OperationDescriptor(kind: .copy, sources: [.local("/a")], destination: .remote("/b"))
        let op = Operation(descriptor: descriptor)

        do {
            _ = try await executor.execute(op, gate: gate)
            XCTFail("Expected error")
        } catch let err as StevedoreError {
            if case .unsupported = err {} else { XCTFail("Expected .unsupported, got \(err)") }
        }
    }

    func testNoSourcesAndNoDestinationThrows() async throws {
        let executor = await makeExecutor()
        let gate = PauseResumeGate()
        // Both sources and destination are absent — no scheme can be inferred.
        let descriptor = OperationDescriptor(kind: .delete, sources: [], destination: nil)
        let op = Operation(descriptor: descriptor)

        do {
            _ = try await executor.execute(op, gate: gate)
            XCTFail("Expected error")
        } catch let err as StevedoreError {
            if case .invalidArgument = err {} else { XCTFail("Expected .invalidArgument, got \(err)") }
        }
    }
}
