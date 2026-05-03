# Session 01 — Charter / Audit Handoff

> Read-only audit of bugs #054 (back navigation broken), #055 (home sidebar
> wrong path), and #056 (3 s spinner on a single-file folder). No source
> changes were made in this session. This document is the input for the three
> parallel fix sessions (02, 03, 04) and the CI gate (05).

## 1. Mission Recap

Trace the navigation, sidebar, and local-FS-enumeration subsystems end-to-end,
identify the lines responsible for each of the three reported bugs, and write
file-and-line citations + suggested fix shapes that downstream sessions can
act on without re-auditing. Sessions 02–04 each touch a narrow file set
declared in their frontmatter; this audit must call out any case where the
suggested fix exceeds that scope.

## 2. Build / Baseline

- `swift build` (SwiftPM, root) — **passed** (`Build complete! (72.89s)`,
  exit 0). All targets compile cleanly on the audit branch.
- The audit makes **zero** edits under `Sources/`, `Tests/`, or `App/`. Only
  `docs/claude-sessions/bugs-054-056-navigation-and-loading/{.session-01-plan,
  session-01-handoff}.md` and `.wolf/{memory.md, cerebrum.md, buglog.json}`
  are touched.

## 3. Architecture Map

```
                        SwiftUI Commands
                         (menu bar tree)
                              │
                              ▼
          AppCommands { GoMenuCommands … }
                              │
              @FocusedValue(\.paneCommandProxy)
                              │
                              ▼
                    ┌──── PaneCommandProxy ────┐
                    │ (struct of @escaping     │
                    │  () -> Void closures,    │
                    │  rebuilt on every        │
                    │  PaneHost render)        │
                    └─────────────┬────────────┘
                                  │
PaneHost.body  ── .focusedValue(\.paneCommandProxy, isActive ? buildProxy() : nil)
       │                         │
       │      buildProxy() captures `session` and forwards directly to
       │      `session.toolbarViewModel.{goBack,goForward}`,
       │      `session.navigate(to:)`, etc. (PaneHost.swift:60-115).
       │
       ├── PaneToolbar(viewModel: session.toolbarViewModel)
       │     ├── chevron.left  → viewModel.goBack()    (PaneToolbar.swift:44-46)
       │     ├── chevron.right → viewModel.goForward() (PaneToolbar.swift:47-49)
       │     ├── arrow.up      → viewModel.goUp()      (PaneToolbar.swift:50-52)
       │     └── PathBar       → viewModel.navigate(to:) (PaneToolbar.swift:33-36)
       │
       ├── PaneTabStrip(session)
       └── FileBrowserView(session)
             └── .task(id: session.currentPath) { await loadItems() }
                   └── for try await item in
                         session.provider.enumerate(at:, options: .default)
                       (PaneHost.swift:301-322)

PaneSession  (@Observable, @MainActor)
  ├── currentPath, tabs, activeTabID                 (PaneSession.swift:14-17)
  ├── toolbarViewModel: PaneToolbarViewModel         (PaneSession.swift:20)
  │       └── init wires `toolbarViewModel.onNavigate = { self.updatePath(to:) }`
  │           (PaneSession.swift:30-33)
  ├── navigate(to:) → toolbarViewModel.navigate(to:) (PaneSession.swift:39-41)
  └── private updatePath(to:) — only called from onNavigate, must NOT
      re-enter toolbar to avoid the documented reentrancy loop
      (PaneSession.swift:70-77)

PaneToolbarViewModel  (@Observable, @MainActor)
  ├── history: HistoryStack                          (PaneToolbarViewModel.swift:14)
  ├── navigate(to:): history.navigate; current=path; onNavigate?(path)
  │                                                  (PaneToolbarViewModel.swift:57-62)
  ├── goBack():      guard let p = history.goBack(); current=p; onNavigate?(p)
  │                                                  (PaneToolbarViewModel.swift:64-68)
  ├── goForward():   symmetric to goBack             (PaneToolbarViewModel.swift:70-74)
  └── goUp(): currentPath.parent → navigate(to:)     (PaneToolbarViewModel.swift:76-79)

HistoryStack  (struct, Sendable)
  ├── navigate(to:) appends to backStack, clears forward (HistoryStack.swift:33-37)
  ├── goBack()      pops to forwardStack, returns new top (HistoryStack.swift:39-45)
  └── canGoBack:    backStack.count > 1                  (HistoryStack.swift:25-27)

Sidebar
  Sidebar (SwiftUI List, selection binding)         (Sidebar.swift:15-28)
    └── DevicesSection iterates SidebarViewModel.volumes (DevicesSection.swift:8-32)
            row .tag(SidebarItemID.volume(volume.url))   (DevicesSection.swift:29)
  ↳ MainWindowView.routeSidebarSelection(id)         (MainWindowView.swift:84-87)
       → filePath(for: id):
            .volume(url)   → FilePath(scheme:.local, posix: url.path) (MainWindowView.swift:91-92)
            .bookmark(id)  → bookmarks lookup
            .connection,.tag → nil
       → activePaneSession.navigate(to: path)

SidebarViewModel  (@Observable, @MainActor)
  ├── start():
  │     volumes = try? await volumeDiscovery.currentVolumes()  (SidebarViewModel.swift:53-57)
  │     volumeTask consumes volumeDiscovery.volumeEvents()      (SidebarViewModel.swift:62-77)
  │       .mounted → append (dedup by url)
  │       .unmounted → remove by url
  └── (no synthetic "Home" item; the sidebar exposes only mounted volumes,
       favorites/bookmarks, connections, and tags.)

LocalFileSystemProvider  (actor)
  ├── enumerate(at:options:) — nonisolated                  (LocalFileSystemProvider.swift:41-56)
  │     guards scheme == .local, builds URL, delegates to
  │     LocalDirectoryEnumerator.stream(at:options:).
  └── attributes(at:) — actor-isolated, hops to Task.detached(.utility)
                                                            (LocalFileSystemProvider.swift:29-39)

LocalDirectoryEnumerator
  └── stream(at:options:): AsyncThrowingStream wrapper
        Task.detached(priority: .utility) {                 (LocalDirectoryEnumerator.swift:12-26)
          try enumerate(...) — fileExists, isReadableFile,
          fm.enumerator(at: includingPropertiesForKeys: URLResourceMapperKeys, ...),
          per-item url.resourceValues(forKeys: URLResourceMapperKeys),
          continuation.yield(item)
        }                                                   (LocalDirectoryEnumerator.swift:31-89)

AppEnvironment.init()
  ├── localProvider = LocalFileSystemProvider()
  ├── home = FilePath(scheme: .local, posix: NSHomeDirectory())  (AppEnvironment.swift:49)
  ├── leftSession  = PaneSession(id: .left,  initialPath: home, provider: localProvider)
  ├── rightSession = PaneSession(id: .right, initialPath: home, provider: localProvider)
  ├── volumeAdapter = VolumeDiscoveryAdaptor(VolumeDiscovery())
  └── sidebarVM    = SidebarViewModel(bookmarks, volumeAdapter, …)

VolumeDiscovery.currentVolumes()
  └── FileManager().mountedVolumeURLs(includingResourceValuesForKeys:
                                      options: [.skipHiddenVolumes])
                                                             (VolumeDiscovery.swift:36-41)
      → resourceValues for volumeName / isEjectable / isRemovable / isLocal
        per URL                                              (VolumeDiscovery.swift:42-51)
```

## 4. Bug-by-bug Findings

### Bug #054 — Back navigation does not navigate

**Symptom (from charter):** Toolbar back button, Go ▸ Back, and ⌘[ all fail
to return the pane to the previous directory after navigating into Desktop.

**Why the unit-level logic is fine.** `HistoryStack.navigate` and
`HistoryStack.goBack` are tested and correct
(`HistoryStack.swift:33-45`, `ToolbarTests.swift:9-72`).
`PaneSession.navigate(to:)` delegates to
`PaneToolbarViewModel.navigate(to:)` which pushes onto the history stack and
fires `onNavigate?(path)` (`PaneSession.swift:39-41` →
`PaneToolbarViewModel.swift:57-62`). `onNavigate` is wired in
`PaneSession.init` to `updatePath(to:)`
(`PaneSession.swift:30-33`), and `updatePath` is comment-marked as
`MUST NOT call navigate` — that contract is honored. So the back-stack does
get populated when the user navigates into a folder.

**Root-cause hypothesis (multiple).** The bug is in the menu/shortcut
plumbing, not in the view-model. Three concrete failure surfaces, in order
of likelihood:

1. **`PaneCommandProxy` never reaches the menu.** `PaneHost` exposes the
   proxy via SwiftUI's `FocusedValue`:
   ```swift
   // Sources/UI/MainWindow/PaneHost.swift:50
   .focusedValue(\.paneCommandProxy, self.isActive ? self.buildProxy() : nil)
   ```
   `FocusedValue` only propagates when a focused element exists **inside the
   pane's view subtree**. The pane's "active" state is driven by
   `model.windowState.activePaneID == .left/.right`
   (`MainWindowView.swift:67-79`), which is updated on tap
   (`MainWindowView.swift:69`, `MainWindowView.swift:75`) — i.e. it is a
   custom non-SwiftUI focus model. Nothing in `PaneToolbar` or
   `PaneTabStrip` is `.focusable()`. The only inherently-focusable element
   is the `List` inside `FileBrowserView` (`PaneHost.swift:212`), but it
   is only focused after a user clicks a row. After a tap-on-folder or a
   sidebar selection, focus may still be on the `Sidebar` `List` (which
   lives outside `PaneHost`) or nowhere, so
   `@FocusedValue(\.paneCommandProxy)` resolves to `nil` in
   `GoMenuCommands` (`Sources/UI/Menus/Sections/GoMenu.swift:5`).
   Consequence: `Button("Back") { proxy?.goBack() }`
   (`GoMenu.swift:17-21`) is `.disabled(self.proxy?.canGoBack != true)`,
   making both Go ▸ Back and ⌘[ no-op.

2. **The toolbar chevron's disabled state may flicker.** `buildProxy` in
   `PaneHost.swift:60` reads `session.toolbarViewModel.canGoBack`
   (line 64) into a struct value. The struct is rebuilt on every `body`
   re-render (the file's class doc-comment claims this), but
   `PaneCommandProxy` is a value type — `Button`'s `.disabled` reads the
   stored `canGoBack`, not a live binding, so it only updates when the
   surrounding view re-renders. This is **not** the same as the chevron in
   `PaneToolbar` (which uses `@Bindable var viewModel`, so its `.disabled`
   is live). The chevron path therefore likely works, while the menu path
   likely does not.

3. **Reentrancy guard side-effects.** The `navigate → onNavigate →
   updatePath` contract relies on `updatePath` *not* writing to
   `toolbarViewModel.history`. That contract is honored
   (`PaneSession.swift:70-77`), so this is not the bug — but it constrains
   any fix: Session 02 must not bypass the contract.

**Suggested fix shape (scoped to Session 02 `touches:`
`PaneSession.swift`, `PaneCommandProxy.swift`).**

- **In scope (PaneSession.swift):** Promote `goBack`, `goForward`, `goUp`,
  `goHome`, `goToComputer`, `refresh` to first-class `@MainActor` methods on
  `PaneSession` so callers don't have to reach into
  `session.toolbarViewModel`. Routes all entry points through a single
  surface. Example shape (illustrative — Session 02 writes the actual code):
  ```swift
  public func goBack()          { self.toolbarViewModel.goBack() }
  public func goForward()       { self.toolbarViewModel.goForward() }
  public var canGoBack: Bool    { self.toolbarViewModel.canGoBack }
  public var canGoForward: Bool { self.toolbarViewModel.canGoForward }
  ```
  This makes the proxy independent of `toolbarViewModel` and reduces the
  coupling that the proxy currently has to internal types.

- **In scope (PaneCommandProxy.swift):** Already a value-type bag; no API
  change needed beyond consuming the new `PaneSession` methods if Session 02
  also touches `PaneHost` (out of scope).

- ⚠ **Scope concern.** If the actual bug is the `FocusedValue` plumbing —
  i.e. the proxy never reaches `GoMenuCommands` — the fix lives in
  `PaneHost.swift` (e.g. add `.focusable()` to the `VStack` in
  `PaneHost.body`, gate it on `isActive`, or use `.focusedSceneValue`
  instead of `.focusedValue`) **and** possibly in `MainWindowView.swift`.
  Session 02's frontmatter only allows `PaneSession.swift` and
  `PaneCommandProxy.swift`. Session 02 must either (a) add `PaneHost.swift`
  to its `touches:` set with operator approval, or (b) document that it can
  only repair the toolbar chevron path and that the menu/shortcut paths
  require a follow-up.

**Manual-repro guidance for Session 02:** With the app launched at home,
double-click `Desktop` and observe `currentPath`. Then exercise each of:
- toolbar `chevron.left`
- Go ▸ Back menu item
- ⌘[ keyboard shortcut

Record which entry points succeed and which fail. The split between
"chevron works, menu/shortcut don't" vs "all three fail" determines whether
the fix is purely in `PaneSession`/`PaneCommandProxy` or also in
`PaneHost`'s focus wiring.

---

### Bug #055 — Home sidebar item navigates to `/System/Volumes/Data/home`

**Symptom (from charter):** Clicking the "home" entry in the sidebar
navigates to `/System/Volumes/Data/home` (the macOS automounted `/home`
firmlink) instead of the user's actual home directory under `/Users/<name>`.

**Trace.**

1. `Sidebar` is a single SwiftUI `List` whose selection is a
   `SidebarItemID` (`Sources/UI/Sidebar/Sidebar.swift:15-19`).
2. The only sources of `SidebarItemID.volume(_)` rows are produced in
   `DevicesSection.body`:
   ```swift
   // Sources/UI/Sidebar/Sections/DevicesSection.swift:9-30
   ForEach(self.viewModel.volumes) { volume in
       HStack { … }.tag(SidebarItemID.volume(volume.url))
   }
   ```
3. `volumes` is populated by `SidebarViewModel.start()`:
   ```swift
   // Sources/UI/Sidebar/SidebarViewModel.swift:52-57
   if let initial = try? await volumeDiscovery.currentVolumes() {
       self.volumes = initial
   }
   ```
4. `volumeDiscovery` is `VolumeDiscoveryAdaptor`
   (`App/Stevedore/AppEnvironment.swift:55,116-132`) which forwards 1:1 to
   `FileSystem/Local/VolumeDiscovery.currentVolumes()`:
   ```swift
   // Sources/FileSystem/Local/VolumeDiscovery.swift:36-51
   FileManager().mountedVolumeURLs(
       includingResourceValuesForKeys: keys,
       options: [.skipHiddenVolumes]
   )
   ```
5. On macOS, `mountedVolumeURLs(...)` returns the autofs mount at
   `/System/Volumes/Data/home` whose `volumeName` is `"home"`. The
   resulting `SidebarVolume.name == "home"` is what the user perceives as
   the "Home" entry.
6. Selection routes to `MainWindowView.filePath(for:)`:
   ```swift
   // Sources/UI/MainWindow/MainWindowView.swift:91-92
   case .volume(let url):
       FilePath(scheme: .local, posix: url.path)
   ```
   The pane is asked to navigate to `/System/Volumes/Data/home`. There is
   no resolution of firmlinks anywhere in the path — and there should not
   be at this layer, because the sidebar should never have surfaced this
   entry as "home" in the first place.

**There is no synthetic `Home` sidebar item anywhere.** The closest
references in the codebase are:
- `AppEnvironment.swift:49` — `let home = FilePath(scheme: .local, posix:
  NSHomeDirectory())` (used as the pane's *initial* path; not a sidebar
  entry).
- `PaneHost.swift:74-76` — Go ▸ Home menu action:
  `session.navigate(to: FilePath(scheme: .local, posix: NSHomeDirectory()))`.

So `goHome` works correctly in the menu; the bug is exclusively that the
sidebar's `home` row (which is actually a mounted-volume row labeled
`home`) points at the wrong `URL`.

**Suggested fix shape (scoped to Session 03 `touches:`
`SidebarViewModel.swift`).** Two viable approaches; pick one in Session 03:

- **A — Drop the `/home` autofs entry and inject a synthetic Home volume
  whose URL is `FileManager.default.homeDirectoryForCurrentUser`.** Inside
  `start()` and inside the `mounted` event branch:
  ```swift
  // Pseudocode — Session 03 writes the real code
  let raw = (try? await volumeDiscovery.currentVolumes()) ?? []
  let cleaned = raw.filter { $0.url.path != "/System/Volumes/Data/home" }
  let home = SidebarVolume(
      url: FileManager.default.homeDirectoryForCurrentUser,
      name: "Home",
      isEjectable: false,
      isRemovable: false
  )
  self.volumes = [home] + cleaned
  ```
- **B — Filter out the `/home` mount only; rely on a Favorites/bookmark
  for Home.** Less work but doesn't actually fix the user's perception of
  "Home is broken."

**Recommended:** Option A. The fix sits entirely inside
`SidebarViewModel.swift` (in scope), uses
`FileManager.default.homeDirectoryForCurrentUser` per the operator-rule
constraint ("Always use `FileManager.default.homeDirectoryForCurrentUser`
as the canonical source"), and matches what the user expects the sidebar
to show.

⚠ **Scope concern.** Filtering inside `VolumeDiscoveryAdaptor`
(`App/Stevedore/AppEnvironment.swift`) would be cleaner architecturally
(keeps `VolumeDiscovery` honest and lets multiple sidebars share the
behavior), but `AppEnvironment.swift` is not in Session 03's `touches:`
list. Recommend Session 03 do the in-scope fix in `SidebarViewModel.swift`
and leave a `// TODO(orchestrator): consider moving to VolumeDiscoveryAdaptor`
note for a future cleanup.

**Manual-repro guidance for Session 03:** Click the entry labeled "home"
in the sidebar Devices section. The pane must navigate to
`FileManager.default.homeDirectoryForCurrentUser.path`, e.g.
`/Users/aramirez`, not `/System/Volumes/Data/home` and not `/home`.

---

### Bug #056 — 3 s spinner on a single-file folder

**Symptom (from charter):** Opening a folder containing a single file (e.g.
`Desktop` with one `.md` file) shows the `ProgressView` for 3+ seconds.

**Trace and suspected delays.**

1. `FileBrowserView.loadItems` shows the spinner for the **entire** stream
   lifetime:
   ```swift
   // Sources/UI/MainWindow/PaneHost.swift:301-322
   private func loadItems() async {
       self.isLoading = true
       …
       for try await item in self.session.provider.enumerate(
           at: self.session.currentPath, options: .default
       ) {
           collected.append(item)
           if Task.isCancelled { break }
       }
       …
       self.isLoading = false
   }
   ```
   The view does not render rows until the loop terminates. Even if the
   first (and only) item is yielded in <100 ms, the spinner persists until
   `continuation.finish()`.

2. `LocalDirectoryEnumerator.stream` wraps everything in
   `Task.detached(priority: .utility)`:
   ```swift
   // Sources/FileSystem/Local/LocalDirectoryEnumerator.swift:12-26
   AsyncThrowingStream { continuation in
       let task = Task.detached(priority: .utility) {
           do {
               try Self.enumerate(at:, options:, continuation: continuation)
               continuation.finish()
           } catch {
               continuation.finish(throwing: error)
           }
       }
       continuation.onTermination = { _ in task.cancel() }
   }
   ```
   `.utility` QoS is below `.userInitiated`. On a busy main run loop the
   detached task may not be scheduled immediately — observed startup
   latencies of hundreds of milliseconds are normal.
   `LocalFileSystemProvider.attributes(_:)` makes the same choice
   (`LocalFileSystemProvider.swift:36`).

3. `fm.enumerator(at: includingPropertiesForKeys: URLResourceMapperKeys,
   options:)` (LocalDirectoryEnumerator.swift:58-62) is asked for the full
   URLResourceMapperKeys set:
   ```swift
   // Sources/FileSystem/Local/URLResourceMapper.swift:5-18
   private let resourceKeys: Set<URLResourceKey> = [
       .nameKey, .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey,
       .fileResourceTypeKey, .fileSizeKey, .totalFileSizeKey,
       .contentModificationDateKey, .creationDateKey, .fileSecurityKey,
       .isHiddenKey, .isPackageKey,
   ]
   ```
   `.fileSecurityKey` and `.isPackageKey` are notably more expensive than
   the type/size keys. Forcing prefetch of `.fileSecurityKey` for every
   entry asks the kernel to materialize an ACL for each path.

4. **Duplicate resource-value fetch.** The enumerator's prefetch already
   populates the keys above, but the per-item loop fetches them again:
   ```swift
   // Sources/FileSystem/Local/LocalDirectoryEnumerator.swift:78-81
   let values = try url.resourceValues(forKeys: URLResourceMapperKeys)
   let item = URLResourceMapper.fileItem(url: url, values: values)
   continuation.yield(item)
   ```
   The second fetch is unnecessary and forces another kernel round-trip
   per file.

5. **macOS TCC consent prompt.** Folders like `Desktop`, `Documents`, and
   `Downloads` are gated by Transparency-Consent-Control. The first read
   after install or after changing app metadata blocks behind a system
   dialog ("would like to access files in your Desktop folder"). That
   dialog is synchronous from the kernel's perspective and may account for
   multi-second first-touch latency. Subsequent (warm-cache) accesses
   bypass it and should be fast.

6. **Symlink check is per-item.** Even when `options.followsSymbolicLinks`
   is false, the loop fires an extra `resourceValues(forKeys:
   [.isSymbolicLinkKey])` (LocalDirectoryEnumerator.swift:71-76). That key
   is already in `URLResourceMapperKeys`, so this is another redundant
   kernel call.

**Suggested fix shape (scoped to Session 04 `touches:`
`LocalFileSystemProvider.swift`, `LocalDirectoryEnumerator.swift`).**

- **Bump priority from `.utility` to `.userInitiated`** in
  `LocalDirectoryEnumerator.stream` (line 13) and in
  `LocalFileSystemProvider.attributes` (line 36). User-driven directory
  loads are not background work.
- **Eliminate the duplicate resource-values fetch.** Read the values once
  off the prefetched enumerator (the values returned by the enumerator
  iterator already include the prefetched keys when accessed via
  `URLResourceValues`) or, fetch once and reuse for the symlink branch.
- **Trim the prefetch set.** Drop `.fileSecurityKey` from the prefetch in
  `URLResourceMapper.swift` (out of scope — see ⚠) **or** introduce a
  smaller `enumerationKeys` set inside `LocalDirectoryEnumerator.swift`
  and read `fileSecurityKey` lazily from
  `LocalFileSystemProvider.attributes(at:)` only when a caller asks for
  attributes. (The minimum the row UI in `FileBrowserView` actually reads
  is name, isDirectory, fileSize, contentModificationDate.)
- **Document the TCC caveat** in the handoff: the first-launch latency is
  partly out of the app's control.

⚠ **Scope concern.** `URLResourceMapperKeys` lives in
`Sources/FileSystem/Local/URLResourceMapper.swift`, which is **not** in
Session 04's `touches:` list. If Session 04 wants to trim that set, it
needs scope-extension. Otherwise it can locally redefine a smaller key set
inside `LocalDirectoryEnumerator.swift` for prefetch, while keeping the
existing `URLResourceMapperKeys` for the (less frequent) attributes path.

⚠ **Out-of-scope follow-up suggestion.** Even with the enumerator faster,
`FileBrowserView.loadItems` (`PaneHost.swift:301-322`) only flips
`isLoading = false` after the loop terminates. A user-perceptible win
would be to flip it after the first yielded item (or after a small batch
or short timeout), so a single-file folder renders instantly. That fix
lives in `PaneHost.swift`, outside Session 04's scope. Recommend the
orchestrator schedule a follow-up session or extend Session 04's `touches:`.

**Manual-repro / measurement guidance for Session 04:** Clean-build, then
launch the app fresh. From the home pane, double-click `Desktop`. Time the
spinner from appear to disappear with a stopwatch (or a screen recording
at 60 fps). Repeat ×3. Then quit and relaunch (warm TCC cache). Repeat
×3. Report cold and warm timings separately. Acceptance: warm-cache time
on a single-file folder should be < 200 ms.

## 5. Manual repro evidence

This audit ran in a non-interactive worktree without a UI session. The
repros are documented in §4 as guidance for the fix sessions, not executed
here. Build cleanliness is the only verification this session ran (see §2).
Downstream sessions are required by their own charters to manually exercise
the bug before claiming the fix works.

## 6. Inputs for downstream sessions

### Session 02 — Bug #054
- **In-scope files:** `PaneSession.swift`, `PaneCommandProxy.swift`.
- **Primary task:** Promote navigation actions to first-class
  `PaneSession` methods; ensure `PaneCommandProxy` consumes them.
- **Scope-widening required?** Likely yes if the failure mode is
  `FocusedValue` not propagating — that's `PaneHost.swift`. Reproduce
  first; only request scope extension if the toolbar chevron works but
  Go ▸ Back / ⌘[ don't.
- **Cross-references:** `PaneSession.swift:30-77`,
  `PaneToolbarViewModel.swift:57-79`, `HistoryStack.swift:33-53`,
  `PaneHost.swift:50,60-115`, `PaneToolbar.swift:42-54`,
  `GoMenu.swift:5,17-27`, `Shortcuts.swift:30-31`.
- **Don't break:** the documented `navigate → onNavigate → updatePath`
  reentrancy contract on `PaneSession.swift:8-10,70-77`. Any new
  `goBack()` method on `PaneSession` must delegate to
  `toolbarViewModel.goBack()` rather than mutate state directly.

### Session 03 — Bug #055
- **In-scope file:** `SidebarViewModel.swift`.
- **Primary task:** In `start()` and the `.mounted` event branch, drop the
  autofs `/home` entry and inject a synthetic
  `SidebarVolume(name: "Home", url: FileManager.default
  .homeDirectoryForCurrentUser, …)` at the head of `volumes`.
- **Scope-widening required?** No.
- **Cross-references:** `SidebarViewModel.swift:52-77`,
  `DevicesSection.swift:8-32`, `MainWindowView.swift:84-99`,
  `VolumeDiscovery.swift:29-52`, `AppEnvironment.swift:49,116-132`.
- **Operator-rule reminder:** Use
  `FileManager.default.homeDirectoryForCurrentUser`, never a string-built
  `/Users/<name>` path.

### Session 04 — Bug #056
- **In-scope files:** `LocalFileSystemProvider.swift`,
  `LocalDirectoryEnumerator.swift`.
- **Primary task:** Bump QoS to `.userInitiated` and remove the duplicate
  `resourceValues(forKeys:)` fetch per item. Optionally introduce a
  smaller prefetch key set inside `LocalDirectoryEnumerator` (defining a
  local `enumerationKeys` constant); avoid touching
  `URLResourceMapper.swift` to stay in scope.
- **Scope-widening required?** No, if the in-file local-key-set approach
  is taken. Yes if the team wants to trim the global
  `URLResourceMapperKeys`.
- **Cross-references:** `LocalDirectoryEnumerator.swift:8-89`,
  `LocalFileSystemProvider.swift:29-56`, `URLResourceMapper.swift:5-21`,
  `PaneHost.swift:301-322` (the consumer).
- **Out-of-scope follow-up to flag:** First-yield-clears-spinner in
  `FileBrowserView.loadItems` (`PaneHost.swift:301-322`).

### Session 05 — CI gate
- Re-run `swift build`, `swift test`, and the manual repros for #054, #055,
  #056. Smoke-test `goUp`, `goForward`, `goHome`, sidebar bookmarks
  (favorites are unaffected), and ensure no regression in `PathBar`
  navigation (`PaneToolbar.swift:33-36`).

## 7. Open issues / deferred

- **`PaneCommandProxy: @unchecked Sendable`** (`PaneCommandProxy.swift:124`):
  worth revisiting once Swift 6 strict-concurrency lands fully. Out of
  scope here.
- **`SidebarViewModel.start()` skip on error** (`SidebarViewModel.swift:55`):
  if `currentVolumes()` throws, `volumes` stays empty and the user sees no
  Devices section at all. Out of scope; flag for a future hardening pass.
- **`FileBrowserView.loadItems` doesn't progressive-render** — see Bug #056
  follow-up note above.
- **TCC first-launch latency** for `Desktop`/`Documents`/`Downloads` cannot
  be eliminated by application code; document it in user-facing release
  notes.

## 8. Decisions made in this session

- Audit recommends Option A (synthetic Home volume) over Option B (filter
  only) for Bug #055 because it preserves the user's mental model that
  "Home" is a clickable sidebar item.
- Audit recommends in-file local key set for Bug #056 over editing
  `URLResourceMapper.swift` so Session 04 stays inside its declared
  `touches:`. The orchestrator can broaden scope later if a global trim
  is preferred.
- Audit explicitly leaves `PaneHost.swift` out of Session 02's scope as
  delivered, but flags that the bug is most likely there. Session 02 must
  reproduce before deciding.
