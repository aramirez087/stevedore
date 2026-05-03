import Core
import ServicesSettings
import SwiftUI
@testable import UISettingsUI
import XCTest

@MainActor
final class SettingsSceneTests: XCTestCase {
    func testSettingsSceneConstructible() {
        let store = InMemorySettingsStore()
        let scene = SettingsScene(store: store)
        let host = NSHostingView(rootView: scene)
        XCTAssertNotNil(host)
    }

    func testGeneralTabConstructible() {
        let store = InMemorySettingsStore()
        let tab = GeneralTab(store: store)
        let host = NSHostingView(rootView: tab)
        XCTAssertNotNil(host)
    }

    func testAppearanceTabConstructible() {
        let store = InMemorySettingsStore()
        let tab = AppearanceTab(store: store)
        let host = NSHostingView(rootView: tab)
        XCTAssertNotNil(host)
    }

    func testFileDisplayTabConstructible() {
        let store = InMemorySettingsStore()
        let tab = FileDisplayTab(store: store)
        let host = NSHostingView(rootView: tab)
        XCTAssertNotNil(host)
    }

    func testAdvancedTabConstructible() {
        let store = InMemorySettingsStore()
        let tab = AdvancedTab(store: store)
        let host = NSHostingView(rootView: tab)
        XCTAssertNotNil(host)
    }
}
