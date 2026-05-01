import Core
@testable import FileSystemRemote
import os
import XCTest

final class RemoteProviderRegistryTests: XCTestCase {
    // MARK: - open

    func testOpenWithRegisteredScheme() async throws {
        let registry = RemoteProviderRegistry()
        let transport = FakeSFTPTransport(
            files: ["/readme.txt": Data("x".utf8)]
        )
        await registry.register(scheme: .sftp) { host, _ in
            let session = RemoteSession<any SFTPTransport> { transport }
            return SFTPProvider(descriptor: host, session: session)
        }
        let host = RemoteHostDescriptor(displayName: "test", scheme: .sftp, host: "localhost", port: 22)
        let provider = try await registry.open(host, credential: nil)
        XCTAssertEqual(provider.scheme, .sftp)
    }

    func testOpenWithUnregisteredSchemeThrows() async throws {
        let registry = RemoteProviderRegistry()
        let host = RemoteHostDescriptor(displayName: "test", scheme: .sftp, host: "localhost", port: 22)
        do {
            _ = try await registry.open(host, credential: nil)
            XCTFail("Expected error for unregistered scheme")
        } catch let e as StevedoreError {
            guard case .unsupported = e else {
                return XCTFail("Expected .unsupported, got \(e)")
            }
        }
    }

    // MARK: - test (connectivity check)

    func testTestSuccessReturnsSuccessStatus() async throws {
        let registry = RemoteProviderRegistry()
        let transport = FakeSFTPTransport(
            files: ["/probe.txt": Data("ok".utf8)],
            directories: ["/"]
        )
        await registry.register(scheme: .sftp) { host, _ in
            let session = RemoteSession<any SFTPTransport> { transport }
            return SFTPProvider(descriptor: host, session: session)
        }
        let host = RemoteHostDescriptor(
            displayName: "test",
            scheme: .sftp,
            host: "localhost",
            port: 22,
            initialPath: FilePath(scheme: .sftp, posix: "/probe.txt")
        )
        let result = try await registry.test(host, credential: nil)
        XCTAssertEqual(result.status, .success)
        XCTAssertGreaterThanOrEqual(result.latencyMilliseconds ?? 0, 0)
    }

    func testTestAuthFailureReturnsAuthStatus() async throws {
        let registry = RemoteProviderRegistry()
        await registry.register(scheme: .sftp) { _, _ in
            throw StevedoreError.remote(.authenticationFailed)
        }
        let host = RemoteHostDescriptor(displayName: "test", scheme: .sftp, host: "localhost", port: 22)
        let result = try await registry.test(host, credential: nil)
        XCTAssertEqual(result.status, .authenticationFailed)
    }

    func testTestConnectionFailedReturnsUnreachable() async throws {
        let registry = RemoteProviderRegistry()
        await registry.register(scheme: .sftp) { _, _ in
            throw StevedoreError.remote(.connectionFailed(detail: "refused"))
        }
        let host = RemoteHostDescriptor(displayName: "test", scheme: .sftp, host: "badhost", port: 22)
        let result = try await registry.test(host, credential: nil)
        XCTAssertEqual(result.status, .unreachable)
    }

    func testTestUnsupportedSchemeReturnsUnsupported() async throws {
        let registry = RemoteProviderRegistry()
        await registry.register(scheme: .sftp) { _, _ in
            throw StevedoreError.unsupported("not supported")
        }
        let host = RemoteHostDescriptor(displayName: "test", scheme: .sftp, host: "localhost", port: 22)
        let result = try await registry.test(host, credential: nil)
        XCTAssertEqual(result.status, .unsupported)
    }

    // MARK: - register (override)

    func testRegisterOverridesPreviousFactory() async throws {
        let registry = RemoteProviderRegistry()
        let calledFactory = OSAllocatedUnfairLock(initialState: 0)

        await registry.register(scheme: .ftp) { host, _ in
            calledFactory.withLock { $0 = 1 }
            let t = FakeFTPTransport()
            let session = RemoteSession<any FTPTransport> { t }
            return FTPProvider(descriptor: host, session: session)
        }
        await registry.register(scheme: .ftp) { host, _ in
            calledFactory.withLock { $0 = 2 }
            let t = FakeFTPTransport()
            let session = RemoteSession<any FTPTransport> { t }
            return FTPProvider(descriptor: host, session: session)
        }

        let host = RemoteHostDescriptor(displayName: "test", scheme: .ftp, host: "localhost", port: 21)
        _ = try await registry.open(host, credential: nil)
        XCTAssertEqual(calledFactory.withLock { $0 }, 2)
    }

    // MARK: - Multiple schemes

    func testMultipleSchemesRegisteredIndependently() async throws {
        let registry = RemoteProviderRegistry()

        await registry.register(scheme: .sftp) { host, _ in
            let t = FakeSFTPTransport()
            let session = RemoteSession<any SFTPTransport> { t }
            return SFTPProvider(descriptor: host, session: session)
        }
        await registry.register(scheme: .ftp) { host, _ in
            let t = FakeFTPTransport()
            let session = RemoteSession<any FTPTransport> { t }
            return FTPProvider(descriptor: host, session: session)
        }

        let sftpHost = RemoteHostDescriptor(displayName: "test", scheme: .sftp, host: "h", port: 22)
        let ftpHost = RemoteHostDescriptor(displayName: "test", scheme: .ftp, host: "h", port: 21)

        let sftpProvider = try await registry.open(sftpHost, credential: nil)
        let ftpProvider = try await registry.open(ftpHost, credential: nil)

        XCTAssertEqual(sftpProvider.scheme, .sftp)
        XCTAssertEqual(ftpProvider.scheme, .ftp)
    }
}
