import Core
import FileSystemLocal
import Foundation
import XCTest

final class FSEventsWatcherTests: XCTestCase {
    private var fixture = TempDirectoryFixture()

    override func setUp() async throws {
        self.fixture = TempDirectoryFixture()
        try self.fixture.setUp()
    }

    override func tearDown() async throws {
        self.fixture.tearDown()
    }

    // MARK: - Basic event emission

    func testWatcherEmitsEventOnFileCreation() async throws {
        let watcher = FSEventsWatcher(latencySeconds: 0.1)
        let stream = watcher.events(for: self.fixture.path, recursive: true)

        // Allow the stream to start, then write a file, then collect one event.
        try await Task.sleep(for: .milliseconds(200))
        _ = try self.fixture.makeFile(name: "watched.txt")

        let task = Task<FilePathChange?, Never> {
            for await change in stream {
                return change
            }
            return nil
        }
        let timeoutTask = Task<Void, Never> {
            try? await Task.sleep(for: .seconds(5))
            task.cancel()
        }
        let received = await task.value
        timeoutTask.cancel()
        XCTAssertNotNil(received, "Watcher should emit an event after file creation")
    }

    // MARK: - Cancellation / cleanup

    func testStreamTerminatesOnBreak() async {
        let watcher = FSEventsWatcher(latencySeconds: 0.1)
        let stream = watcher.events(for: self.fixture.path, recursive: true)
        // Simply break after receiving the stream handle — no crash or hang.
        for await _ in stream {
            break
        }
    }

    // MARK: - Weak-reference leak guard

    func testWatcherDeallocatesAfterStreamEnds() async throws {
        weak var weakWatcher: FSEventsWatcher?
        do {
            let watcher = FSEventsWatcher(latencySeconds: 0.1)
            weakWatcher = watcher
            let stream = watcher.events(for: self.fixture.path, recursive: true)
            // Start the stream then immediately stop iterating.
            for await _ in stream {
                break
            }
        }
        // Give `onTermination` a moment to run.
        try await Task.sleep(for: .milliseconds(200))
        // The actor should be deallocated if no strong reference remains.
        // NOTE: actors with an executor retain themselves briefly; we give it
        // a generous window. If this flakes, the leak is real.
        XCTAssertNil(weakWatcher, "FSEventsWatcher should deallocate after stream terminates")
    }

    // MARK: - Provider watch() integration

    func testProviderWatchWiresIntoWatcher() async {
        let provider = LocalFileSystemProvider()
        let stream = provider.watch(self.fixture.path)
        // Start iterating then immediately stop — no crash.
        for await _ in stream {
            break
        }
    }
}
