import AppKit
import Foundation

/// Ejects a mounted volume by URL.
///
/// `Sendable` so it can be stored on the `@MainActor` view model and called from a task.
public protocol VolumeEjecting: Sendable {
    func eject(volumeURL: URL) async throws
}

/// Production implementation: delegates to `NSWorkspace.unmountAndEjectDevice(at:)`.
public struct SystemVolumeEjector: VolumeEjecting {
    public init() {}

    public func eject(volumeURL: URL) async throws {
        // NSWorkspace is @MainActor; run on main actor and forward the thrown error.
        try await MainActor.run {
            try NSWorkspace.shared.unmountAndEjectDevice(at: volumeURL)
        }
    }
}
