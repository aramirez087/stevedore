import Core
import DiskArbitration
import Foundation

/// Enumerates mounted volumes and publishes mount/unmount events via a
/// `DiskArbitration` session held for the lifetime of this actor.
public actor VolumeDiscovery {
    public struct Volume: Hashable, Sendable {
        public let url: URL
        public let name: String
        public let isEjectable: Bool
        public let isRemovable: Bool
        public let isLocal: Bool
    }

    public enum VolumeEvent: Hashable, Sendable {
        case mounted(Volume)
        case unmounted(URL)
    }

    private var continuations: [UUID: AsyncStream<VolumeEvent>.Continuation] = [:]
    private var daSession: DASession?

    public init() {}

    // MARK: - Public API

    public func currentVolumes() throws -> [Volume] {
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeIsEjectableKey,
            .volumeIsRemovableKey,
            .volumeIsLocalKey,
        ]
        guard let urls = FileManager().mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) else {
            throw StevedoreError.fileSystem(.ioFailure(detail: "mountedVolumeURLs returned nil"))
        }
        return urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
            return Volume(
                url: url,
                name: values.volumeName ?? url.lastPathComponent,
                isEjectable: values.volumeIsEjectable ?? false,
                isRemovable: values.volumeIsRemovable ?? false,
                isLocal: values.volumeIsLocal ?? true
            )
        }
    }

    public nonisolated func events() -> AsyncStream<VolumeEvent> {
        AsyncStream { [weak self] continuation in
            guard let self else {
                continuation.finish()
                return
            }
            let id = UUID()
            Task {
                await self.registerContinuation(id: id, continuation: continuation)
                await self.startIfNeeded()
            }
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id: id) }
            }
        }
    }

    // MARK: - Internal

    private func registerContinuation(id: UUID, continuation: AsyncStream<VolumeEvent>.Continuation) {
        self.continuations[id] = continuation
    }

    private func removeContinuation(id: UUID) {
        self.continuations.removeValue(forKey: id)
    }

    func emit(_ event: VolumeEvent) {
        for continuation in self.continuations.values {
            continuation.yield(event)
        }
    }

    private func startIfNeeded() {
        guard self.daSession == nil else { return }

        let queue = DispatchQueue(label: "dev.stevedore.da", qos: .utility)
        guard let session = DASessionCreate(kCFAllocatorDefault) else { return }
        DASessionSetDispatchQueue(session, queue)

        // `Unmanaged.passRetained` keeps `self` alive for DA callbacks.
        // Released inside `diskReleasedCallback` (called when the session is torn down).
        let boxedSelf = Unmanaged.passRetained(DACallbackBox(actor: self))

        DARegisterDiskAppearedCallback(session, nil, diskAppearedCallback, boxedSelf.toOpaque())
        DARegisterDiskDisappearedCallback(session, nil, diskDisappearedCallback, boxedSelf.toOpaque())

        self.daSession = session
    }
}

// MARK: - DA callback helpers

private final class DACallbackBox: @unchecked Sendable {
    let actor: VolumeDiscovery
    init(actor: VolumeDiscovery) {
        self.actor = actor
    }
}

/// Extract all needed info from `disk` on the DA queue *before* any actor hop.
private func volumeEvent(from disk: DADisk, appeared: Bool) -> VolumeDiscovery.VolumeEvent? {
    guard let desc = DADiskCopyDescription(disk) as? [CFString: Any] else { return nil }

    guard
        let urlRef = desc[kDADiskDescriptionVolumePathKey],
        CFGetTypeID(urlRef as CFTypeRef) == CFURLGetTypeID(),
        let url = (urlRef as? NSURL) as URL?
    else { return nil }

    if appeared {
        let name = (desc[kDADiskDescriptionVolumeNameKey] as? String) ?? url.lastPathComponent
        let ejectable = (desc[kDADiskDescriptionMediaEjectableKey] as? Bool) ?? false
        let removable = (desc[kDADiskDescriptionMediaRemovableKey] as? Bool) ?? false
        let volume = VolumeDiscovery.Volume(
            url: url,
            name: name,
            isEjectable: ejectable,
            isRemovable: removable,
            isLocal: true
        )
        return .mounted(volume)
    } else {
        return .unmounted(url)
    }
}

private let diskAppearedCallback: DADiskAppearedCallback = { disk, context in
    guard let context else { return }
    let box = Unmanaged<DACallbackBox>.fromOpaque(context).takeUnretainedValue()
    guard let event = volumeEvent(from: disk, appeared: true) else { return }
    Task { await box.actor.emit(event) }
}

private let diskDisappearedCallback: DADiskDisappearedCallback = { disk, context in
    guard let context else { return }
    let box = Unmanaged<DACallbackBox>.fromOpaque(context).takeUnretainedValue()
    guard let event = volumeEvent(from: disk, appeared: false) else { return }
    Task { await box.actor.emit(event) }
}
