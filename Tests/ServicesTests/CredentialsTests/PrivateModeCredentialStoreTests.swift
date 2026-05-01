import Core
import ServicesCredentials
import XCTest

final class PrivateModeCredentialStoreTests: XCTestCase {
    var store: PrivateModeCredentialStore!

    override func setUp() async throws {
        self.store = PrivateModeCredentialStore()
    }

    func testStoreAndRetrieve() async throws {
        let id = UUID()
        let credential = Credential(username: "alice", material: .password("p4ss"))
        try await self.store.store(credential, for: id)
        let retrieved = try await self.store.credential(for: id)
        XCTAssertEqual(retrieved, credential)
    }

    func testMissingCredentialReturnsNil() async throws {
        let retrieved = try await self.store.credential(for: UUID())
        XCTAssertNil(retrieved)
    }

    func testRemoveDeletesCredential() async throws {
        let id = UUID()
        let credential = Credential(username: "bob", material: .oauthToken("tok"))
        try await self.store.store(credential, for: id)
        try await self.store.remove(for: id)
        let retrieved = try await self.store.credential(for: id)
        XCTAssertNil(retrieved)
    }

    func testListReturnsSortedIDs() async throws {
        let id1 = UUID()
        let id2 = UUID()
        try await self.store.store(Credential(username: nil, material: .password("a")), for: id1)
        try await self.store.store(Credential(username: nil, material: .password("b")), for: id2)
        let listed = try await self.store.list()
        XCTAssertTrue(listed.contains(id1))
        XCTAssertTrue(listed.contains(id2))
        XCTAssertEqual(listed.count, 2)
    }

    func testUpsertOverwritesExistingCredential() async throws {
        let id = UUID()
        let first = Credential(username: "u", material: .password("first"))
        let second = Credential(username: "u", material: .password("second"))
        try await self.store.store(first, for: id)
        try await self.store.store(second, for: id)
        let retrieved = try await self.store.credential(for: id)
        XCTAssertEqual(retrieved, second)
    }

    func testResetClearsAllCredentials() async throws {
        let id = UUID()
        try await self.store.store(Credential(username: nil, material: .password("x")), for: id)
        await self.store.reset()
        let listed = try await self.store.list()
        XCTAssertTrue(listed.isEmpty)
    }

    func testRemoveNonExistentIsNoop() async throws {
        try await self.store.remove(for: UUID())
        let listed = try await self.store.list()
        XCTAssertTrue(listed.isEmpty)
    }
}
