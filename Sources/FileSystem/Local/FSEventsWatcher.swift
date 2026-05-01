import Core
import CoreServices
import Foundation

/// Actor wrapping `FSEventStreamCreate`, exposing an `AsyncStream` of
/// `FilePathChange` events for a watched directory tree.
///
/// Each call to `events(for:recursive:)` creates a new `FSEventStreamRef`.
/// The stream is stopped and invalidated when its iterator is deinitialized
/// (via `continuation.onTermination`).
///
/// Concurrency: the C callback runs on a dedicated serial `DispatchQueue`
/// and yields straight to `AsyncStream.Continuation` (which is `Sendable`).
public actor FSEventsWatcher {
    private let latencySeconds: Double

    public init(latencySeconds: Double = 0.5) {
        self.latencySeconds = latencySeconds
    }

    public nonisolated func events(
        for path: FilePath,
        recursive: Bool = true
    ) -> AsyncStream<FilePathChange> {
        let posixPath = path.posixString
        let latency = self.latencySeconds

        return AsyncStream { continuation in
            let queue = DispatchQueue(label: "dev.stevedore.fsevents.\(UUID().uuidString)", qos: .utility)
            let box = StreamBox(continuation: continuation)

            // Use a wrapper to make the opaque pointer Sendable-safe inside onTermination.
            let streamRef = StreamRef()

            var context = FSEventStreamContext(
                version: 0,
                info: Unmanaged.passRetained(box).toOpaque(),
                retain: nil,
                release: { ptr in
                    guard let p = ptr else { return }
                    Unmanaged<StreamBox>.fromOpaque(p).release()
                },
                copyDescription: nil
            )

            let flags = FSEventStreamCreateFlags(
                kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes
            )

            guard let stream = FSEventStreamCreate(
                nil,
                fsEventsCallback,
                &context,
                [posixPath] as CFArray,
                FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                latency,
                flags
            ) else {
                continuation.finish()
                return
            }

            streamRef.value = stream
            FSEventStreamSetDispatchQueue(stream, queue)
            FSEventStreamStart(stream)

            continuation.onTermination = { [streamRef] _ in
                if let s = streamRef.value {
                    FSEventStreamStop(s)
                    FSEventStreamInvalidate(s)
                    FSEventStreamRelease(s)
                }
            }
        }
    }
}

// MARK: - Internal helpers

/// Heap box for the stream continuation — passed through the C context pointer.
private final class StreamBox: @unchecked Sendable {
    let continuation: AsyncStream<FilePathChange>.Continuation
    init(continuation: AsyncStream<FilePathChange>.Continuation) {
        self.continuation = continuation
    }
}

/// Heap box for the `FSEventStreamRef` so it can be captured `@Sendable`.
/// `FSEventStreamRef` is an opaque C pointer; boxing it in a class makes it
/// safe to capture across isolation boundaries while keeping ownership clear.
private final class StreamRef: @unchecked Sendable {
    var value: FSEventStreamRef?
}

private let fsEventsCallback: FSEventStreamCallback = { _, clientCallBackInfo, numEvents, eventPaths, eventFlags, _ in
    guard let info = clientCallBackInfo else { return }
    let box = Unmanaged<StreamBox>.fromOpaque(info).takeUnretainedValue()

    // eventPaths is a CFArray of CFString when kFSEventStreamCreateFlagUseCFTypes is set.
    let cfArray = unsafeBitCast(eventPaths, to: CFArray.self)
    guard let pathsArray = cfArray as? [String] else { return }

    let flagsBuffer = UnsafeBufferPointer(start: eventFlags, count: numEvents)
    for (pathString, rawFlags) in zip(pathsArray, flagsBuffer) {
        box.continuation.yield(filePathChange(pathString: pathString, flags: rawFlags))
    }
}

private func filePathChange(pathString: String, flags: FSEventStreamEventFlags) -> FilePathChange {
    let path = FilePath(scheme: .local, posix: pathString)
    let flags32 = flags
    let kind: FilePathChange.Kind = if flags32 & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved) != 0 {
        .deleted
    } else if flags32 & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRenamed) != 0 {
        .renamed
    } else if flags32 & FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated) != 0 {
        .created
    } else {
        .modified
    }
    return FilePathChange(path: path, kind: kind)
}
