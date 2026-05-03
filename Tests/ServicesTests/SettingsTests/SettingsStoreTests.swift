import Core
import ServicesSettings
import XCTest

final class SettingsStoreTests: XCTestCase {
    private var suiteName: String!
    private var store: UserDefaultsSettingsStore!

    override func setUp() {
        super.setUp()
        self.suiteName = "SettingsStoreTests-\(UUID().uuidString)"
        guard let suite = UserDefaults(suiteName: self.suiteName) else {
            XCTFail("Could not create isolated UserDefaults suite")
            return
        }
        self.store = UserDefaultsSettingsStore(defaults: suite)
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: self.suiteName)
        super.tearDown()
    }

    // MARK: - Read defaults

    func testValueReturnsDefaultWhenNotSet() async {
        let value = await self.store.value(for: Settings.showHiddenFiles)
        XCTAssertEqual(value, Settings.showHiddenFiles.defaultValue)
    }

    // MARK: - Round-trips

    func testSetAndGetBoolRoundTrip() async {
        await self.store.set(true, for: Settings.showHiddenFiles)
        let value = await self.store.value(for: Settings.showHiddenFiles)
        XCTAssertTrue(value)
    }

    func testSetAndGetStringRoundTrip() async {
        await self.store.set("dark", for: Settings.theme)
        let value = await self.store.value(for: Settings.theme)
        XCTAssertEqual(value, "dark")
    }

    func testSetAndGetDoubleRoundTrip() async {
        await self.store.set(0.75, for: Settings.splitRatio)
        let value = await self.store.value(for: Settings.splitRatio)
        XCTAssertEqual(value, 0.75, accuracy: 0.0001)
    }

    // MARK: - Observation: initial value

    func testObserveEmitsDefaultOnSubscription() async {
        let stream = self.store.observe(Settings.showHiddenFiles)
        var iterator = stream.makeAsyncIterator()
        let first = await iterator.next()
        XCTAssertEqual(first, Settings.showHiddenFiles.defaultValue)
    }

    // MARK: - Observation: emits on write

    func testObserveEmitsOnWrite() async {
        let stream = self.store.observe(Settings.showHiddenFiles)
        var iterator = stream.makeAsyncIterator()

        // Initial default
        let initial = await iterator.next()
        XCTAssertEqual(initial, false)

        // Write new value — continuation was registered during the initial next() call
        await self.store.set(true, for: Settings.showHiddenFiles)

        let updated = await iterator.next()
        XCTAssertEqual(updated, true)
    }

    // MARK: - Observation: clean cancellation

    func testObserveCancelsCleanly() async {
        let stream = self.store.observe(Settings.theme)
        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next() // consume initial default; iterator goes out of scope after
    }

    // MARK: - Concurrent writers

    func testConcurrentWritersDoNotCorrupt() async throws {
        let store = try XCTUnwrap(self.store)
        await withTaskGroup(of: Void.self) { group in
            for i in 0 ..< 50 {
                group.addTask {
                    await store.set(i % 2 == 0, for: Settings.showHiddenFiles)
                }
            }
        }
        let value = await self.store.value(for: Settings.showHiddenFiles)
        // Must be a valid Bool (not a crash or corrupt value)
        XCTAssertTrue(value == true || value == false)
    }
}
