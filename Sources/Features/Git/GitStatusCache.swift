import Core
import CoreServices
import Foundation

/// Per-repository git-status cache invalidated by FSEvents.
///
/// Each unique `repoRoot` gets one cache entry and one FSEvents watch task.
/// The watcher fires on changes to any file under the working tree, which
/// clears the stale entry so the next `getOrFetch` call triggers a fresh
/// `git status` run.
public actor GitStatusCache {
    private var entries: [FilePath: CacheEntry] = [:]

    private struct CacheEntry {
        var statuses: [GitFileStatus]
        /// Task owning the FSEvents watch loop for this repo.
        var watchTask: Task<Void, Never>?
        /// In-flight fetch task, used to coalesce concurrent callers.
        var fetchTask: Task<[GitFileStatus], any Error>?
    }

    public init() {}

    /// Returns cached statuses, or calls `fetch` if the cache is cold or stale.
    ///
    /// Concurrent callers for the same repo share a single in-flight fetch
    /// task so `git status` is invoked at most once per cache miss.
    public func getOrFetch(
        repoRoot: FilePath,
        fetch: @Sendable @escaping () async throws -> [GitFileStatus]
    ) async throws -> [GitFileStatus] {
        // Cache hit: return immediately.
        if let entry = entries[repoRoot], !entry.statuses.isEmpty, entry.fetchTask == nil {
            return entry.statuses
        }

        // Coalesce: if a fetch is already in flight, await it.
        if let existing = entries[repoRoot]?.fetchTask {
            return try await existing.value
        }

        // Start a new fetch task.
        let fetchTask = Task<[GitFileStatus], any Error> {
            try await fetch()
        }

        // Ensure the entry exists before we await (actor reentrancy safe).
        if entries[repoRoot] == nil {
            entries[repoRoot] = CacheEntry(statuses: [], watchTask: nil, fetchTask: fetchTask)
        } else {
            entries[repoRoot]?.fetchTask = fetchTask
        }

        // Start the FSEvents watcher the first time we see this repo.
        if entries[repoRoot]?.watchTask == nil {
            let watchTask = makeWatchTask(repoRoot: repoRoot)
            entries[repoRoot]?.watchTask = watchTask
        }

        do {
            let statuses = try await fetchTask.value
            entries[repoRoot]?.statuses = statuses
            entries[repoRoot]?.fetchTask = nil
            return statuses
        } catch {
            entries[repoRoot]?.fetchTask = nil
            throw error
        }
    }

    /// Clears cached statuses for `repoRoot`, forcing a fresh fetch on the next call.
    public func invalidate(repoRoot: FilePath) {
        entries[repoRoot]?.statuses = []
        entries[repoRoot]?.fetchTask = nil
    }

    // MARK: - FSEvents watch task

    private func makeWatchTask(repoRoot: FilePath) -> Task<Void, Never> {
        // Capture only the string path so we don't close over `self` unsafely.
        let rootPosix = repoRoot.posixString
        let repoRootCopy = repoRoot

        return Task<Void, Never> { [weak self] in
            guard let self else { return }
            await self.runWatcher(rootPosix: rootPosix, repoRoot: repoRootCopy)
        }
    }

    private func runWatcher(rootPosix: String, repoRoot: FilePath) async {
        // `StreamBox` transfers the FSEventStreamRef across the Sendable boundary.
        // Ownership: created here, stopped on task cancellation via onTermination.
        // @unchecked Sendable justified: single-owner, never accessed concurrently.
        final class StreamBox: @unchecked Sendable {
            var stream: FSEventStreamRef?
        }
        let box = StreamBox()

        // `CallbackPayload` carries the actor reference plus the repoRoot across
        // the C callback boundary.  Must be heap-allocated as a class.
        final class CallbackPayload: @unchecked Sendable {
            weak var cache: GitStatusCache?
            let repoRoot: FilePath
            init(cache: GitStatusCache, repoRoot: FilePath) {
                self.cache = cache
                self.repoRoot = repoRoot
            }
        }

        let payload = CallbackPayload(cache: self, repoRoot: repoRoot)
        let payloadPtr = Unmanaged.passRetained(payload).toOpaque()

        var context = FSEventStreamContext(
            version: 0,
            info: payloadPtr,
            retain: { ptr -> UnsafeRawPointer? in
                guard let p = ptr else { return nil }
                _ = Unmanaged<CallbackPayload>.fromOpaque(p).retain()
                return p
            },
            release: { ptr in
                guard let p = ptr else { return }
                Unmanaged<CallbackPayload>.fromOpaque(p).release()
            },
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let payload = Unmanaged<CallbackPayload>.fromOpaque(info).takeUnretainedValue()
            let repoRoot = payload.repoRoot
            Task {
                await payload.cache?.invalidate(repoRoot: repoRoot)
            }
        }

        let paths = [rootPosix] as CFArray
        // 50ms latency: ensures FSEvents arrive well within the 200ms exit criterion.
        let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.05,
            UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        )

        // Release the extra retain from passRetained now that the stream owns a copy.
        Unmanaged<CallbackPayload>.fromOpaque(payloadPtr).release()

        box.stream = stream

        if let stream {
            FSEventStreamSetDispatchQueue(stream, DispatchQueue.global(qos: .utility))
            FSEventStreamStart(stream)
        }

        // Park this task; cleanup when cancelled.
        await withTaskCancellationHandler {
            // Wait forever; the task will be cancelled when the actor entry is removed.
            await Task.yield()
            // Keep the task alive until cancelled.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
            }
        } onCancel: {
            if let stream = box.stream {
                FSEventStreamStop(stream)
                FSEventStreamInvalidate(stream)
                FSEventStreamRelease(stream)
                box.stream = nil
            }
        }
    }
}
