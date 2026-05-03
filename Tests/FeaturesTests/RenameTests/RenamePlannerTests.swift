import Core
import FeaturesRename
import XCTest

final class RenamePlannerTests: XCTestCase {
    private let dir = FilePath(scheme: .local, posix: "/photos")

    // MARK: - Basic planning

    func testEmptyItemsReturnsEmpty() {
        let outcomes = RenamePlanner.plan(items: [], recipe: .identity)
        XCTAssertTrue(outcomes.isEmpty)
    }

    func testIdentityRecipe() {
        let items = [makeItem(name: "photo.jpg", dir: self.dir)]
        let outcomes = RenamePlanner.plan(items: items, recipe: .identity)
        XCTAssertEqual(outcomes.count, 1)
        XCTAssertEqual(outcomes[0].targetName, "photo.jpg")
        XCTAssertEqual(outcomes[0].status, .ok)
    }

    func testSingleFindStep() {
        let items = [makeItem(name: "IMG_001.jpg", dir: self.dir)]
        let recipe = RenameRecipe(steps: [.find(text: "IMG_", replace: "photo_", caseSensitive: true)])
        let outcomes = RenamePlanner.plan(items: items, recipe: recipe)
        XCTAssertEqual(outcomes[0].targetName, "photo_001.jpg")
        XCTAssertEqual(outcomes[0].status, .ok)
    }

    func testMultipleStepsAppliedInOrder() {
        let items = [makeItem(name: "  hello world  .txt", dir: self.dir)]
        let recipe = RenameRecipe(steps: [
            .trim(.both),
            .case(.upper),
        ])
        let outcomes = RenamePlanner.plan(items: items, recipe: recipe)
        XCTAssertEqual(outcomes[0].targetName, "HELLO WORLD.txt")
    }

    // MARK: - Determinism

    func testDeterminism() {
        let items = [
            makeItem(name: "alpha.jpg", dir: self.dir),
            makeItem(name: "beta.png", dir: self.dir),
            makeItem(name: "gamma.txt", dir: self.dir),
        ]
        let recipe = RenameRecipe(steps: [.sequence(start: 1, padding: 3, position: .prefix)])
        let outcomes1 = RenamePlanner.plan(items: items, recipe: recipe)
        let outcomes2 = RenamePlanner.plan(items: items, recipe: recipe)
        XCTAssertEqual(outcomes1.map(\.targetName), outcomes2.map(\.targetName))
        XCTAssertEqual(outcomes1.map(\.status), outcomes2.map(\.status))
    }

    // MARK: - Regex validation

    func testRegexValidPattern() {
        let items = [makeItem(name: "IMG_001.jpg", dir: self.dir)]
        let recipe = RenameRecipe(steps: [.regex(pattern: "IMG_(\\d+)", replacement: "photo_$1")])
        let outcomes = RenamePlanner.plan(items: items, recipe: recipe)
        XCTAssertEqual(outcomes[0].status, .ok)
        XCTAssertEqual(outcomes[0].targetName, "photo_001.jpg")
    }

    func testRegexMalformedPattern() {
        let items = [
            makeItem(name: "photo1.jpg", dir: self.dir),
            makeItem(name: "photo2.jpg", dir: self.dir),
        ]
        let recipe = RenameRecipe(steps: [.regex(pattern: "[unclosed", replacement: "$0")])
        let outcomes = RenamePlanner.plan(items: items, recipe: recipe)
        for outcome in outcomes {
            if case .invalid = outcome.status {
                // expected
            } else {
                XCTFail("Expected .invalid status but got \(outcome.status)")
            }
        }
    }

    func testRegexMalformedAllItemsInvalid() {
        let items = (1 ... 5).map { makeItem(name: "file\($0).jpg", dir: self.dir) }
        let recipe = RenameRecipe(steps: [.regex(pattern: "**bad**", replacement: "")])
        let outcomes = RenamePlanner.plan(items: items, recipe: recipe)
        XCTAssertEqual(outcomes.count, 5)
        XCTAssertTrue(outcomes.allSatisfy {
            if case .invalid = $0.status { return true }
            return false
        })
    }

    func testRegexBackreferenceInPlan() {
        let items = [makeItem(name: "hello_world.txt", dir: self.dir)]
        let recipe = RenameRecipe(steps: [.regex(pattern: "(\\w+)_(\\w+)", replacement: "$2_$1")])
        let outcomes = RenamePlanner.plan(items: items, recipe: recipe)
        XCTAssertEqual(outcomes[0].targetName, "world_hello.txt")
        XCTAssertEqual(outcomes[0].status, .ok)
    }

    // MARK: - Collision detection

    func testCollisionDetectedInPlan() {
        let items = [
            makeItem(name: "alpha.jpg", dir: self.dir),
            makeItem(name: "beta.jpg", dir: self.dir),
        ]
        let recipe = RenameRecipe(steps: [
            .find(text: "alpha", replace: "same", caseSensitive: true),
            .find(text: "beta", replace: "same", caseSensitive: true),
        ])
        let outcomes = RenamePlanner.plan(items: items, recipe: recipe, collisionStrategy: .markInvalid)
        XCTAssertEqual(outcomes[0].targetName, "same.jpg")
        XCTAssertEqual(outcomes[0].status, .ok)
        XCTAssertEqual(outcomes[1].targetName, "same.jpg")
        XCTAssertEqual(outcomes[1].status, .collision)
    }

    func testExistingSiblingConflict() {
        let items = [makeItem(name: "photo.jpg", dir: self.dir)]
        let recipe = RenameRecipe(steps: [.case(.lower)])
        let outcomes = RenamePlanner.plan(
            items: items,
            recipe: recipe,
            existingSiblings: ["photo.jpg"],
            collisionStrategy: .markInvalid
        )
        XCTAssertEqual(outcomes[0].status, .collision)
    }

    // MARK: - Edge cases

    func testLongNameEdgeCase() {
        let longStem = String(repeating: "a", count: 480)
        let items = [makeItem(name: "\(longStem).txt", dir: self.dir)]
        let outcomes = RenamePlanner.plan(items: items, recipe: .identity)
        XCTAssertEqual(outcomes[0].targetName, "\(longStem).txt")
        XCTAssertEqual(outcomes[0].status, .ok)
    }

    func testUnicodeNormalization() {
        let nfdA = "\u{0041}\u{0301}"
        let items = [makeItem(name: "\(nfdA).txt", dir: self.dir)]
        let recipe = RenameRecipe(steps: [.case(.upper)])
        let outcomes = RenamePlanner.plan(items: items, recipe: recipe)
        XCTAssertEqual(outcomes[0].status, .ok)
        XCTAssertFalse(outcomes[0].targetName.isEmpty)
    }
}
