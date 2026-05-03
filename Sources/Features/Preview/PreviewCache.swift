import Core
import Foundation

/// NSCache value wrapper — must be NSObject subclass for NSCache.
final class CachedPreview: NSObject {
    let payload: PreviewPayload

    init(_ payload: PreviewPayload) {
        self.payload = payload
    }

    var cost: Int {
        self.payload.data.count
    }
}

public actor PreviewCache {
    private let inner: NSCache<NSString, CachedPreview>

    public init(byteLimit: Int = 50 * 1024 * 1024) {
        self.inner = NSCache<NSString, CachedPreview>()
        self.inner.totalCostLimit = byteLimit
        self.inner.countLimit = 0
    }

    public func fetch(key: String) -> PreviewPayload? {
        self.inner.object(forKey: key as NSString)?.payload
    }

    public func store(_ payload: PreviewPayload, forKey key: String) {
        let entry = CachedPreview(payload)
        self.inner.setObject(entry, forKey: key as NSString, cost: entry.cost)
    }

    public func remove(key: String) {
        self.inner.removeObject(forKey: key as NSString)
    }

    public func removeAll() {
        self.inner.removeAllObjects()
    }
}
