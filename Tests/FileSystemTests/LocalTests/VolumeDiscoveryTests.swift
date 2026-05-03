import Core
import FileSystemLocal
import Foundation
import XCTest

final class VolumeDiscoveryTests: XCTestCase {
    func testCurrentVolumesReturnsBootVolume() async throws {
        let discovery = VolumeDiscovery()
        let volumes = try await discovery.currentVolumes()
        XCTAssertFalse(volumes.isEmpty, "At least the boot volume should be present")
        // The boot volume is mounted at /
        let bootVolume = volumes.first { $0.url.path == "/" }
        XCTAssertNotNil(bootVolume, "Boot volume at / should be present")
        XCTAssertTrue(bootVolume?.isLocal ?? false, "Boot volume should be local")
    }

    func testCurrentVolumesAreNonEmpty() async throws {
        let discovery = VolumeDiscovery()
        let volumes = try await discovery.currentVolumes()
        for volume in volumes {
            XCTAssertFalse(volume.name.isEmpty, "Volume name should be non-empty")
        }
    }

    func testEventsStreamInstallsAndUninstallsCleanly() async {
        // Smoke test: verify the stream can be created and immediately terminated
        // without a crash or leak. Full mount/unmount integration tests require
        // disk image fixtures and are out of scope for unit testing.
        let discovery = VolumeDiscovery()
        let stream = discovery.events()
        for await _ in stream {
            break
        }
    }
}
