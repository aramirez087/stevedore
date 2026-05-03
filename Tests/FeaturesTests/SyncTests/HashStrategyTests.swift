import Core
import CryptoKit
import FeaturesSync
import Foundation
import XCTest

final class HashStrategyTests: XCTestCase {
    // MARK: - Default chunk size

    func testHashStrategyDefaultChunkSize() {
        XCTAssertEqual(HashStrategy.defaultChunkSize, 262_144)
    }

    // MARK: - SHA-256 correctness

    func testSha256EmptyStream() async throws {
        let stream = AsyncThrowingStream<Data, any Error> { $0.finish() }
        let digest = try await HashStrategy.sha256(reading: stream)
        let reference = SHA256.hash(data: Data())
        XCTAssertEqual(digest, reference)
    }

    func testSha256SingleChunk() async throws {
        let data = Data(repeating: 0xAB, count: 1024)
        let stream = AsyncThrowingStream<Data, any Error> { continuation in
            continuation.yield(data)
            continuation.finish()
        }
        let digest = try await HashStrategy.sha256(reading: stream)
        let reference = SHA256.hash(data: data)
        XCTAssertEqual(digest, reference)
    }

    func testSha256MultiChunk() async throws {
        let chunk1 = Data(repeating: 0x01, count: 512)
        let chunk2 = Data(repeating: 0x02, count: 512)
        let combined = chunk1 + chunk2

        let stream = AsyncThrowingStream<Data, any Error> { continuation in
            continuation.yield(chunk1)
            continuation.yield(chunk2)
            continuation.finish()
        }
        let digest = try await HashStrategy.sha256(reading: stream)
        let reference = SHA256.hash(data: combined)
        XCTAssertEqual(digest, reference)
    }

    func testSha256LargeData() async throws {
        let data = Data(repeating: 0x42, count: 1_048_576) // 1 MB
        let chunkSize = 65536
        let stream = AsyncThrowingStream<Data, any Error> { continuation in
            var offset = 0
            while offset < data.count {
                let end = min(offset + chunkSize, data.count)
                continuation.yield(data[offset ..< end])
                offset = end
            }
            continuation.finish()
        }
        let digest = try await HashStrategy.sha256(reading: stream)
        let reference = SHA256.hash(data: data)
        XCTAssertEqual(digest, reference)
    }

    // MARK: - Cancellation

    func testSha256CancellationHalts() async throws {
        // A stream that never yields — the sha256 task suspends indefinitely on next().
        // Cancellation is the only way the stream terminates.
        let stream = AsyncThrowingStream<Data, any Error> { continuation in
            continuation.onTermination = { _ in
                continuation.finish()
            }
        }

        let task = Task<SHA256Digest, any Error> {
            try await HashStrategy.sha256(reading: stream)
        }

        // Let the task start and suspend on next().
        try await Task.sleep(nanoseconds: 10_000_000) // 10 ms
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected CancellationError")
        } catch is CancellationError {
            // Expected: sha256 checks cancellation after the loop exits.
        }
    }

    // MARK: - SyncReadableProvider protocol smoke test

    func testSyncReadableProviderProtocol() async throws {
        let provider = InMemorySyncProvider(scheme: .local)
        let path = FilePath(scheme: .local, posix: "/file.txt")
        let expectedData = Data("hello sync".utf8)
        await provider.seed(expectedData, at: path)

        var received = Data()
        for try await chunk in provider.readChunks(at: path, chunkSize: 4) {
            received.append(chunk)
        }
        XCTAssertEqual(received, expectedData)
    }
}
