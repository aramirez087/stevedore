import Core
import Foundation
import ServicesCredentials
import XCTest

final class KeychainCredentialStoreTests: XCTestCase {
    var store: KeychainCredentialStore!
    var testService: String!

    override func setUp() async throws {
        self.testService = "com.stevedore.test.\(UUID().uuidString)"
        self.store = KeychainCredentialStore(service: self.testService)
    }

    override func tearDown() async throws {
        let ids = try await self.store.list()
        for id in ids {
            try await self.store.remove(for: id)
        }
        let remaining = try await self.store.list()
        XCTAssertTrue(remaining.isEmpty, "Keychain items not cleaned up: \(remaining)")
    }

    func testStoreAndRetrieve() async throws {
        let id = UUID()
        let credential = Credential(username: "alice", material: .password("t3stPa$$"))
        try await self.store.store(credential, for: id)
        let retrieved = try await self.store.credential(for: id)
        XCTAssertEqual(retrieved, credential)
    }

    func testMissingCredentialReturnsNil() async throws {
        let retrieved = try await self.store.credential(for: UUID())
        XCTAssertNil(retrieved)
    }

    func testUpsertOverwritesExistingEntry() async throws {
        let id = UUID()
        let first = Credential(username: "u", material: .password("first"))
        let second = Credential(username: "u", material: .password("updated"))
        try await self.store.store(first, for: id)
        try await self.store.store(second, for: id)
        let retrieved = try await self.store.credential(for: id)
        XCTAssertEqual(retrieved, second)
    }

    func testRemoveDeletesEntry() async throws {
        let id = UUID()
        let credential = Credential(username: "bob", material: .oauthToken("mytoken"))
        try await self.store.store(credential, for: id)
        try await self.store.remove(for: id)
        let retrieved = try await self.store.credential(for: id)
        XCTAssertNil(retrieved)
    }

    func testListReturnsStoredIDs() async throws {
        let id1 = UUID()
        let id2 = UUID()
        try await self.store.store(Credential(username: nil, material: .password("a")), for: id1)
        try await self.store.store(Credential(username: nil, material: .password("b")), for: id2)
        let listed = try await self.store.list()
        XCTAssertTrue(listed.contains(id1))
        XCTAssertTrue(listed.contains(id2))
    }

    func testListEmptyBeforeAnyStore() async throws {
        let listed = try await self.store.list()
        XCTAssertTrue(listed.isEmpty)
    }

    func testRemoveNonExistentIsNoop() async throws {
        try await self.store.remove(for: UUID())
    }

    func testCleanupAfterStoreVerifiesEmpty() async throws {
        let id = UUID()
        try await self.store.store(Credential(username: nil, material: .password("x")), for: id)
        let ids = try await self.store.list()
        for storedID in ids {
            try await self.store.remove(for: storedID)
        }
        let remaining = try await self.store.list()
        XCTAssertTrue(remaining.isEmpty)
    }

    func testOAuthTokenRoundTrip() async throws {
        let id = UUID()
        let credential = Credential(username: "service", material: .oauthToken("bearer-token-xyz"))
        try await self.store.store(credential, for: id)
        let retrieved = try await self.store.credential(for: id)
        XCTAssertEqual(retrieved, credential)
    }

    func testPrivateKeyRoundTrip() async throws {
        let id = UUID()
        let pem = "-----BEGIN RSA PRIVATE KEY-----\nFIXTURE\n-----END RSA PRIVATE KEY-----"
        let credential = Credential(username: "git", material: .privateKey(pem: pem, passphrase: nil))
        try await self.store.store(credential, for: id)
        let retrieved = try await self.store.credential(for: id)
        XCTAssertEqual(retrieved, credential)
    }
}
