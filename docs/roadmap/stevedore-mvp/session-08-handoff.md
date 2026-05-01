# Session 08 Handoff — Design System

## Scope

Implement the full DesignSystem library target: semantic color tokens, typography scale, spacing
constants, theme environment injection, icon registry with SF Symbol mappings, and six atomic
SwiftUI components (SDButton, SDTextField, SDSearchField, SDProgressBar, SDListRow, SDLabel), plus
FileKindIcon. Every component and token is covered by tests. SwiftUI previews in light and dark
mode are compiled into the library target.

## What changed

### `Sources/UI/DesignSystem/`
- `Placeholder.swift` — **deleted**; sentinel preserved in `DesignSystemModule.swift`
- `DesignSystemModule.swift` — preserves `DesignSystemModule.moduleName = "DesignSystem"` sentinel

### `Sources/UI/DesignSystem/Theme/`
- `Spacing.swift` — `enum Spacing` with five `CGFloat` constants (xs=4, sm=8, md=16, lg=24, xl=32)
- `ColorTokens.swift` — `struct ColorTokens: Sendable`; ten tokens backed by dynamic `NSColor`
- `Typography.swift` — `struct Typography: Sendable`; five `Font` tokens (largeTitle/title/body/caption/mono)
- `Theme.swift` — `struct Theme: Sendable`; `@Entry var theme: Theme` EnvironmentValues extension;
  `View.theme(_:)` convenience modifier

### `Sources/UI/DesignSystem/Icons/`
- `IconSize.swift` — `enum IconSize: Sendable` (sm=12pt, md=16pt, lg=24pt)
- `IconRegistry.swift` — `enum IconRegistry`; two static funcs; dictionary-based extension map
- `FileKindIcon.swift` — `struct FileKindIcon: View`; resolves symbol via `IconRegistry`; tinted
  with `theme.colors.textSecondary`

### `Sources/UI/DesignSystem/Components/`
- `SDButtonStyle.swift` — `enum SDButtonStyle: Sendable` (primary/secondary/destructive)
- `SDButton.swift` — `struct SDButton: View`
- `SDLabelVariant.swift` — `enum SDLabelVariant: Sendable` (primary/secondary/caption/mono)
- `SDLabel.swift` — `struct SDLabel: View`
- `SDListRowContent.swift` — `enum SDListRowContent: Sendable` (singleLine/doubleLine)
- `SDListRow.swift` — `struct SDListRow: View`
- `SDTextField.swift` — `struct SDTextField: View`
- `SDSearchField.swift` — `struct SDSearchField: View`
- `SDProgressBar.swift` — `struct SDProgressBar: View`; value clamped to 0…1 in `init`

### `Sources/UI/DesignSystem/Previews/`
- Nine preview files, each with two `#Preview` blocks (light + dark):
  `ColorTokensPreviews`, `TypographyPreviews`, `SDButtonPreviews`, `SDTextFieldPreviews`,
  `SDSearchFieldPreviews`, `SDProgressBarPreviews`, `SDListRowPreviews`, `SDLabelPreviews`,
  `FileKindIconPreviews`

### `Tests/UITests/DesignSystemTests/`
- `DesignSystemTests.swift` — `@MainActor final class DesignSystemTests: XCTestCase`;
  21 tests covering spacing/icon/theme token values and all component rendering smoke tests

## Decisions

- **`ColorTokens` gains a 10th token `textOnAccent`** (`NSColor.white`). The nine-token spec had no
  provision for white text on accent/danger button backgrounds; rather than use a raw `Color.white`
  literal in SDButton (violating D4), a proper token was added. Downstream sessions should use
  `theme.colors.textOnAccent` for text on colored fills.
- **`Theme.swift` uses `@Entry` macro** instead of a private `EnvironmentKey` struct. SwiftFormat
  0.59's `environmentEntry` rule rewrites the classic pattern to the `@Entry` macro automatically.
  The `@Entry` macro is a compile-time transformation with no macOS version constraint beyond Swift 6.
- **`IconRegistry.symbolName(forExtension:)` uses a `private static let` dictionary** instead of a
  switch statement. The switch form exceeded SwiftLint's cyclomatic_complexity warning threshold
  (17 cases vs. 12 limit). The dictionary lookup has complexity 1.
- **`View.theme(_:)` is `public` on extension, not on individual member.** SwiftFormat's
  `extensionAccessControl` rule hoists access control to the extension declaration.
- **Preview files use `@Previewable @State`** for stateful previews (SDTextField, SDSearchField).
  Plain `@State` in `#Preview` closures generates a warning under `-warnings-as-errors`.
- **Supporting enum types are top-level files** (`SDButtonStyle`, `SDLabelVariant`,
  `SDListRowContent`, `IconSize`) — consistent with Session 01's pattern for avoiding the SwiftLint
  `nesting` rule.
- **`NSHostingView` smoke tests** rather than ViewInspector (not in `Package.swift`). All component
  tests are `@MainActor`; instantiating `NSHostingView(rootView:)` is non-nil and exercises the
  view `body` without needing a display connection.

## Token palette (quick reference)

### ColorTokens

| Token | NSColor source |
|---|---|
| `background` | `NSColor.windowBackgroundColor` |
| `surface` | `NSColor.controlBackgroundColor` |
| `surfaceElevated` | `NSColor.textBackgroundColor` |
| `textPrimary` | `NSColor.labelColor` |
| `textSecondary` | `NSColor.secondaryLabelColor` |
| `accent` | `NSColor.controlAccentColor` |
| `danger` | `NSColor.systemRed` |
| `success` | `NSColor.systemGreen` |
| `divider` | `NSColor.separatorColor` |
| `textOnAccent` | `NSColor.white` (for text on accent/danger fills) |

### Typography

| Token | Font | Size | Weight |
|---|---|---|---|
| `largeTitle` | System | 26pt | Bold |
| `title` | System | 20pt | Semibold |
| `body` | System | 13pt | Regular |
| `caption` | System | 11pt | Regular |
| `mono` | Monospaced (SF Mono) | 13pt | Regular |

### Spacing

| Token | Value |
|---|---|
| `xs` | 4 pt |
| `sm` | 8 pt |
| `md` | 16 pt |
| `lg` | 24 pt |
| `xl` | 32 pt |

### IconSize

| Case | `points` |
|---|---|
| `sm` | 12 pt |
| `md` | 16 pt |
| `lg` | 24 pt |

## Component API surface (quick reference)

```swift
// Button
SDButton(_ label: String, style: SDButtonStyle = .primary, action: @escaping () -> Void)
enum SDButtonStyle: Sendable { case primary, secondary, destructive }

// Text input
SDTextField(_ placeholder: String, text: Binding<String>)
SDSearchField(text: Binding<String>)

// Progress
SDProgressBar(value: Double)  // clamped to 0…1

// List row
SDListRow(content: SDListRowContent, symbolName: String? = nil, isSelected: Bool = false)
enum SDListRowContent: Sendable {
    case singleLine(title: String)
    case doubleLine(title: String, subtitle: String)
}

// Label
SDLabel(_ text: String, variant: SDLabelVariant = .primary)
enum SDLabelVariant: Sendable { case primary, secondary, caption, mono }

// Icon
FileKindIcon(kind: FileKind, fileExtension: String? = nil, size: IconSize = .md)
IconRegistry.symbolName(for: FileKind) -> String
IconRegistry.symbolName(forExtension: String) -> String  // lowercased; fallback "doc"
```

## Theme environment injection

```swift
// Read theme in any view:
@Environment(\.theme) private var theme

// Override for a subtree (e.g. in App root or Settings):
someView.theme(myCustomTheme)

// Construct a custom theme:
let myTheme = Theme(colors: myColors, typography: myTypography)
```

## Instructions for downstream UI sessions

- **Import**: `import DesignSystem` — no other imports needed for tokens or components.
- **Colors**: Use `theme.colors.*` — never `Color(.red)`, `Color(red:green:blue:)`, or NSColor directly.
- **Fonts**: Use `theme.typography.*` — never `.font(.body)` or `Font.system(...)` inline.
- **Spacing**: Use `Spacing.xs/sm/md/lg/xl` — never hard-coded numeric padding values.
- **Icons**: Use `IconRegistry.symbolName(for:)` or `IconRegistry.symbolName(forExtension:)` to get SF Symbol names; wrap in `FileKindIcon` or `Image(systemName:)`.
- **List rows**: Use `SDListRow` rather than custom `HStack` + `Text` combinations.
- **Buttons**: Use `SDButton` for all three styles; use `.primary` for default affirmative actions,
  `.secondary` for cancels, `.destructive` for deletes.

## Open issues / risks

1. **Preview files compile into the production `DesignSystem` binary.** There is no separate
   preview-only target in `Package.swift` (which is frozen). If binary size becomes a concern in
   a downstream session, previews can be moved to a test-only target or behind an
   `#if DEBUG` / `canImport(DeveloperToolsSupport)` guard — record that refactor rather than acting
   on it now.
2. **`textOnAccent` is always `NSColor.white`.** On macOS, `controlAccentColor` is designed for
   white text legibility. If a future Settings session allows custom accent colors, a
   contrast-ratio check may be needed and `textOnAccent` may need to become theme-variant.
3. **`SDListRow.body` background uses `Color.clear` for the unselected state.** This is a
   transparency utility value, not a design token — it was not flagged by SwiftLint. Downstream
   sessions should not change this to a token.

## Next-session inputs

- `Sources/UI/DesignSystem/Theme/` — all token types and the `Theme` struct / `\.theme` key path.
- `Sources/UI/DesignSystem/Components/` — all atomic components.
- `Sources/UI/DesignSystem/Icons/` — `IconRegistry`, `FileKindIcon`, `IconSize`.
- `Sources/UI/DesignSystem/DesignSystemModule.swift` — sentinel (do not modify).
- This handoff, specifically the "Component API surface" and "Token palette" tables.

## Verification

All commands run from the worktree root.

```
swift build --target DesignSystem -Xswiftc -warnings-as-errors
```
→ Build of target 'DesignSystem' complete. 0 warnings.

```
swift test --filter DesignSystemTests
```
→ Executed 21 tests, with 0 failures (0 unexpected) in 0.047 seconds.

```
swiftformat Sources/UI/DesignSystem Tests/UITests/DesignSystemTests --lint
```
→ 0/27 files require formatting.

```
swiftlint lint --strict Sources/UI/DesignSystem
```
→ Found 0 violations, 0 serious in 114 files.

```
swift build
```
→ Build complete. 0 warnings.

```
swift test
```
→ Executed 67 tests, with 0 failures (0 unexpected). (46 from Session 01 + 21 new.)
