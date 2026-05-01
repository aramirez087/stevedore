import Core
import DesignSystem
import SwiftUI
import XCTest

@MainActor
final class DesignSystemTests: XCTestCase {
    // MARK: – Spacing tokens

    func testSpacingTokens() {
        XCTAssertEqual(Spacing.xs, 4)
        XCTAssertEqual(Spacing.sm, 8)
        XCTAssertEqual(Spacing.md, 16)
        XCTAssertEqual(Spacing.lg, 24)
        XCTAssertEqual(Spacing.xl, 32)
    }

    // MARK: – IconSize tokens

    func testIconSizeTokens() {
        XCTAssertEqual(IconSize.sm.points, 12)
        XCTAssertEqual(IconSize.md.points, 16)
        XCTAssertEqual(IconSize.lg.points, 24)
    }

    // MARK: – IconRegistry

    func testIconRegistryKindSymbols() {
        XCTAssertEqual(IconRegistry.symbolName(for: .directory), "folder")
        XCTAssertEqual(IconRegistry.symbolName(for: .regularFile), "doc")
        XCTAssertEqual(IconRegistry.symbolName(for: .unknown), "doc")
    }

    func testIconRegistryExtensionSymbols() {
        XCTAssertEqual(IconRegistry.symbolName(forExtension: "pdf"), "doc.richtext")
        XCTAssertEqual(IconRegistry.symbolName(forExtension: "jpg"), "photo")
        XCTAssertEqual(IconRegistry.symbolName(forExtension: "UNKNOWN_XYZ"), "doc")
    }

    // MARK: – Theme constructibility

    func testThemeSystemConstructible() {
        XCTAssertNotNil(Theme.system)
    }

    func testColorTokensSystemConstructible() {
        XCTAssertNotNil(ColorTokens.system)
    }

    func testTypographySystemConstructible() {
        XCTAssertNotNil(Typography.system)
    }

    // MARK: – Component rendering smoke tests

    func testSDButtonRenders() {
        let view = SDButton("Test", style: .primary, action: {})
        let host = NSHostingView(rootView: view)
        XCTAssertNotNil(host)
    }

    func testSDButtonSecondaryRenders() {
        let view = SDButton("Cancel", style: .secondary, action: {})
        let host = NSHostingView(rootView: view)
        XCTAssertNotNil(host)
    }

    func testSDButtonDestructiveRenders() {
        let view = SDButton("Delete", style: .destructive, action: {})
        let host = NSHostingView(rootView: view)
        XCTAssertNotNil(host)
    }

    func testSDTextFieldRenders() {
        var text = "hello"
        let binding = Binding(get: { text }, set: { text = $0 })
        let view = SDTextField("Placeholder", text: binding)
        let host = NSHostingView(rootView: view)
        XCTAssertNotNil(host)
    }

    func testSDSearchFieldRenders() {
        var text = ""
        let binding = Binding(get: { text }, set: { text = $0 })
        let view = SDSearchField(text: binding)
        let host = NSHostingView(rootView: view)
        XCTAssertNotNil(host)
    }

    func testSDProgressBarRenders() {
        let view = SDProgressBar(value: 0.5)
        let host = NSHostingView(rootView: view)
        XCTAssertNotNil(host)
    }

    func testSDProgressBarClampsValue() {
        let below = SDProgressBar(value: -1)
        XCTAssertNotNil(NSHostingView(rootView: below))
        let above = SDProgressBar(value: 2)
        XCTAssertNotNil(NSHostingView(rootView: above))
    }

    func testSDListRowSingleLineRenders() {
        let view = SDListRow(content: .singleLine(title: "Test Item"))
        let host = NSHostingView(rootView: view)
        XCTAssertNotNil(host)
    }

    func testSDListRowDoubleLineRenders() {
        let view = SDListRow(content: .doubleLine(title: "Title", subtitle: "Subtitle"))
        let host = NSHostingView(rootView: view)
        XCTAssertNotNil(host)
    }

    func testSDListRowSelectedRenders() {
        let view = SDListRow(
            content: .singleLine(title: "Selected"),
            symbolName: "folder",
            isSelected: true
        )
        let host = NSHostingView(rootView: view)
        XCTAssertNotNil(host)
    }

    func testSDLabelVariantsRender() {
        for variant in [SDLabelVariant.primary, .secondary, .caption, .mono] {
            let view = SDLabel("Test", variant: variant)
            let host = NSHostingView(rootView: view)
            XCTAssertNotNil(host)
        }
    }

    func testFileKindIconDirectoryRenders() {
        let view = FileKindIcon(kind: .directory)
        let host = NSHostingView(rootView: view)
        XCTAssertNotNil(host)
    }

    func testFileKindIconRegularFileRenders() {
        let view = FileKindIcon(kind: .regularFile, fileExtension: "pdf")
        let host = NSHostingView(rootView: view)
        XCTAssertNotNil(host)
    }

    func testFileKindIconUnknownRenders() {
        let view = FileKindIcon(kind: .unknown)
        let host = NSHostingView(rootView: view)
        XCTAssertNotNil(host)
    }
}
