import Core
import Foundation
import Observation
import UISidebar

/// Live, observable window-arrangement state for the current session.
///
/// `splitFraction` is clamped to `minFraction...maxFraction` on write.
/// Persisted fields live in `WindowStateSnapshot`; sidebar selection is ephemeral.
@MainActor
@Observable
public final class WindowState {
    public static let minFraction = 0.2
    public static let maxFraction = 0.8

    public var splitFraction: Double {
        didSet {
            let clamped = max(Self.minFraction, min(Self.maxFraction, self.splitFraction))
            guard clamped != self.splitFraction else { return }
            self.splitFraction = clamped
        }
    }

    public var activePaneID: PaneID
    public var selectedSidebarItem: SidebarItemID?

    public init(snapshot: WindowStateSnapshot = .default) {
        self.splitFraction = max(Self.minFraction, min(Self.maxFraction, snapshot.splitFraction))
        self.activePaneID = .left
    }
}

/// The `Codable, Sendable` value persisted via `WorkspacesRepository`.
///
/// `selectedSidebarItem` is omitted because `SidebarItemID` is not `Codable`;
/// sidebar selection is ephemeral and not restored across launches.
public struct WindowStateSnapshot: Codable, Sendable, Equatable {
    public var splitFraction: Double
    public var leftTabs: [Tab]
    public var leftActiveTabID: Tab.ID?
    public var rightTabs: [Tab]
    public var rightActiveTabID: Tab.ID?

    public init(
        splitFraction: Double,
        leftTabs: [Tab],
        leftActiveTabID: Tab.ID?,
        rightTabs: [Tab],
        rightActiveTabID: Tab.ID?
    ) {
        self.splitFraction = splitFraction
        self.leftTabs = leftTabs
        self.leftActiveTabID = leftActiveTabID
        self.rightTabs = rightTabs
        self.rightActiveTabID = rightActiveTabID
    }

    public static let `default` = Self(
        splitFraction: 0.5,
        leftTabs: [],
        leftActiveTabID: nil,
        rightTabs: [],
        rightActiveTabID: nil
    )
}
