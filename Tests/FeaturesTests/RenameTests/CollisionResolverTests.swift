import Core
import FeaturesRename
import XCTest

final class CollisionResolverTests: XCTestCase {
    private let dir = FilePath(scheme: .local, posix: "/docs")

    private func outcome(name: String, target: String, status: RenameStatus = .ok) -> RenameOutcome {
        RenameOutcome(item: makeItem(name: name, dir: self.dir), targetName: target, status: status)
    }

    // MARK: - No collisions

    func testNoCollisions() {
        let outcomes = [
            self.outcome(name: "a.txt", target: "aa.txt"),
            self.outcome(name: "b.txt", target: "bb.txt"),
            self.outcome(name: "c.txt", target: "cc.txt"),
        ]
        let resolved = CollisionResolver.resolve(outcomes: outcomes, existingSiblings: [], strategy: .markInvalid)
        XCTAssertEqual(resolved.map(\.status), [.ok, .ok, .ok])
        XCTAssertEqual(resolved.map(\.targetName), ["aa.txt", "bb.txt", "cc.txt"])
    }

    // MARK: - Within-batch collisions

    func testWithinBatchCollisionMarkInvalid() {
        let outcomes = [
            self.outcome(name: "a.txt", target: "same.txt"),
            self.outcome(name: "b.txt", target: "same.txt"),
        ]
        let resolved = CollisionResolver.resolve(outcomes: outcomes, existingSiblings: [], strategy: .markInvalid)
        XCTAssertEqual(resolved[0].status, .ok)
        XCTAssertEqual(resolved[1].status, .collision)
    }

    func testWithinBatchCollisionAutoSuffix() {
        let outcomes = [
            self.outcome(name: "a.txt", target: "foo.txt"),
            self.outcome(name: "b.txt", target: "foo.txt"),
        ]
        let resolved = CollisionResolver.resolve(outcomes: outcomes, existingSiblings: [], strategy: .autoSuffix)
        XCTAssertEqual(resolved[0].targetName, "foo.txt")
        XCTAssertEqual(resolved[0].status, .ok)
        XCTAssertEqual(resolved[1].targetName, "foo 2.txt")
        XCTAssertEqual(resolved[1].status, .ok)
    }

    // MARK: - Sibling collisions

    func testExistingSiblingMarkInvalid() {
        let outcomes = [self.outcome(name: "a.txt", target: "foo.txt")]
        let resolved = CollisionResolver.resolve(
            outcomes: outcomes,
            existingSiblings: ["foo.txt"],
            strategy: .markInvalid
        )
        XCTAssertEqual(resolved[0].status, .collision)
    }

    func testExistingSiblingAutoSuffix() {
        let outcomes = [self.outcome(name: "a.txt", target: "foo.txt")]
        let resolved = CollisionResolver.resolve(
            outcomes: outcomes,
            existingSiblings: ["foo.txt"],
            strategy: .autoSuffix
        )
        XCTAssertEqual(resolved[0].targetName, "foo 2.txt")
        XCTAssertEqual(resolved[0].status, .ok)
    }

    func testAutoSuffixChain() {
        let outcomes = [self.outcome(name: "a.txt", target: "foo.txt")]
        let resolved = CollisionResolver.resolve(
            outcomes: outcomes,
            existingSiblings: ["foo.txt", "foo 2.txt"],
            strategy: .autoSuffix
        )
        XCTAssertEqual(resolved[0].targetName, "foo 3.txt")
    }

    func testAutoSuffixNoExtension() {
        let outcomes = [self.outcome(name: "readme", target: "readme")]
        let resolved = CollisionResolver.resolve(
            outcomes: outcomes,
            existingSiblings: ["readme"],
            strategy: .autoSuffix
        )
        XCTAssertEqual(resolved[0].targetName, "readme 2")
    }

    // MARK: - Pass-through of non-ok statuses

    func testCollisionAndInvalidPassThrough() {
        let outcomes = [
            self.outcome(name: "a.txt", target: "foo.txt", status: .collision),
            self.outcome(name: "b.txt", target: "bar.txt", status: .invalid(reason: "bad")),
        ]
        let resolved = CollisionResolver.resolve(outcomes: outcomes, existingSiblings: [], strategy: .autoSuffix)
        XCTAssertEqual(resolved[0].status, .collision)
        XCTAssertEqual(resolved[1].status, .invalid(reason: "bad"))
    }

    // MARK: - Ordering

    func testAutoSuffixPreservesFirstClaimer() {
        let outcomes = [
            self.outcome(name: "a.txt", target: "foo.txt"),
            self.outcome(name: "b.txt", target: "foo.txt"),
            self.outcome(name: "c.txt", target: "foo.txt"),
        ]
        let resolved = CollisionResolver.resolve(outcomes: outcomes, existingSiblings: [], strategy: .autoSuffix)
        XCTAssertEqual(resolved[0].targetName, "foo.txt")
        XCTAssertEqual(resolved[0].status, .ok)
        XCTAssertEqual(resolved[1].targetName, "foo 2.txt")
        XCTAssertEqual(resolved[2].targetName, "foo 3.txt")
    }

    func testLargeAutoSuffixCounter() {
        let siblings: Set<String> = Set((1 ... 4).map { $0 == 1 ? "foo.txt" : "foo \($0).txt" })
        let outcomes = [self.outcome(name: "a.txt", target: "foo.txt")]
        let resolved = CollisionResolver.resolve(outcomes: outcomes, existingSiblings: siblings, strategy: .autoSuffix)
        XCTAssertEqual(resolved[0].targetName, "foo 5.txt")
    }
}
