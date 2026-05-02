import Core

/// Browser-style back/forward history for a single file pane.
///
/// `backStack.last` is always the current path. `canGoBack` requires
/// `count > 1` because index 0 is the oldest location with no further back.
/// Forward stack is cleared whenever a new navigation occurs.
public struct HistoryStack: Sendable {
    public static let defaultCapacity: Int = 64

    public let capacity: Int
    private var backStack: [FilePath]
    private var forwardStack: [FilePath]

    public init(capacity: Int = defaultCapacity) {
        self.capacity = capacity
        self.backStack = []
        self.forwardStack = []
    }

    public var current: FilePath? {
        self.backStack.last
    }

    public var canGoBack: Bool {
        self.backStack.count > 1
    }

    public var canGoForward: Bool {
        !self.forwardStack.isEmpty
    }

    public mutating func navigate(to path: FilePath) {
        self.forwardStack.removeAll()
        self.backStack.append(path)
        if self.backStack.count > self.capacity { self.backStack.removeFirst() }
    }

    @discardableResult
    public mutating func goBack() -> FilePath? {
        guard self.canGoBack else { return nil }
        let popped = self.backStack.removeLast()
        self.forwardStack.append(popped)
        return self.backStack.last
    }

    @discardableResult
    public mutating func goForward() -> FilePath? {
        guard self.canGoForward else { return nil }
        let next = self.forwardStack.removeLast()
        self.backStack.append(next)
        return next
    }
}
