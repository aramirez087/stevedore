import Core
import ServicesSettings
import UISettingsUI
import XCTest

@MainActor
final class SettingBindingTests: XCTestCase {
    private func waitForValue<T: Equatable>(
        _ binding: SettingBinding<T>,
        equals expected: T,
        timeout: Duration = .milliseconds(500)
    ) async {
        let deadline = ContinuousClock.now + timeout
        while binding.value != expected, ContinuousClock.now < deadline {
            await Task.yield()
        }
    }

    func testEmitsDefaultOnSubscribeWhenStoreIsEmpty() async {
        let store = InMemorySettingsStore()
        let binding = SettingBinding(setting: Settings.theme, store: store)
        binding.start()
        await self.waitForValue(binding, equals: "system")
        XCTAssertEqual(binding.value, "system")
        binding.stop()
    }

    func testEmitsOnStoreChange() async {
        let store = InMemorySettingsStore()
        let binding = SettingBinding(setting: Settings.theme, store: store)
        binding.start()
        await self.waitForValue(binding, equals: "system")
        await store.set("dark", for: Settings.theme)
        await self.waitForValue(binding, equals: "dark")
        XCTAssertEqual(binding.value, "dark")
        binding.stop()
    }

    func testBindingSetWritesToStore() async {
        let store = InMemorySettingsStore()
        let binding = SettingBinding(setting: Settings.theme, store: store)
        binding.start()
        await self.waitForValue(binding, equals: "system")
        binding.binding.wrappedValue = "light"
        for _ in 0 ..< 100 {
            await Task.yield()
        }
        let stored = await store.value(for: Settings.theme)
        XCTAssertEqual(stored, "light")
        binding.stop()
    }

    func testStopCancelsObservation() async {
        let store = InMemorySettingsStore()
        let binding = SettingBinding(setting: Settings.theme, store: store)
        binding.start()
        await self.waitForValue(binding, equals: "system")
        binding.stop()
        await store.set("dark", for: Settings.theme)
        for _ in 0 ..< 10 {
            await Task.yield()
        }
        XCTAssertEqual(binding.value, "system")
    }

    func testTwoBindingsSameSettingStayInSync() async {
        let store = InMemorySettingsStore()
        let b1 = SettingBinding(setting: Settings.theme, store: store)
        let b2 = SettingBinding(setting: Settings.theme, store: store)
        b1.start()
        b2.start()
        await self.waitForValue(b1, equals: "system")
        await self.waitForValue(b2, equals: "system")
        await store.set("dark", for: Settings.theme)
        await self.waitForValue(b1, equals: "dark")
        await self.waitForValue(b2, equals: "dark")
        XCTAssertEqual(b1.value, "dark")
        XCTAssertEqual(b2.value, "dark")
        b1.stop()
        b2.stop()
    }

    func testBoolSettingRoundTrip() async {
        let store = InMemorySettingsStore()
        let binding = SettingBinding(setting: Settings.dualPaneEnabled, store: store)
        binding.start()
        await self.waitForValue(binding, equals: true)
        XCTAssertTrue(binding.value)
        await store.set(false, for: Settings.dualPaneEnabled)
        await self.waitForValue(binding, equals: false)
        XCTAssertFalse(binding.value)
        binding.stop()
    }

    func testIntSettingRoundTrip() async {
        let store = InMemorySettingsStore()
        let binding = SettingBinding(setting: Settings.logRingBufferSize, store: store)
        binding.start()
        await self.waitForValue(binding, equals: 500)
        XCTAssertEqual(binding.value, 500)
        await store.set(1000, for: Settings.logRingBufferSize)
        await self.waitForValue(binding, equals: 1000)
        XCTAssertEqual(binding.value, 1000)
        binding.stop()
    }
}
