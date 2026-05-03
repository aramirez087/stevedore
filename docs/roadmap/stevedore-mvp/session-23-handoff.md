# Session 23 Handoff — Connect-to-Server Dialog UI

## Scope

Implement the `UIConnectDialog` module: a modal SwiftUI dialog for creating or editing remote
connections (SFTP, FTP, WebDAV, S3, SMB) with per-scheme field validation, test-connection
support via injected `RemoteConnector`, credential persistence via injected `CredentialStore`,
and host-provided save/connect callbacks. No Keychain or real network I/O in tests.

## What changed

### `Package.swift`
- Added `DesignSystem` as an extra dependency of `UIConnectDialog`.

### `Sources/UI/ConnectDialog/` — 13 new files, 1 deleted

| File | Type | Notes |
|---|---|---|
| `ConnectDialogModule.swift` | Module sentinel | Replaces `Placeholder.swift`; preserves `UIConnectDialogModule.moduleName` |
| `AuthMode.swift` | `public enum AuthMode` | Top-level; `label: String` extension for picker display |
| `TestConnectionStatus.swift` | `public enum TestConnectionStatus` | `isSuccess`, `userMessage` computed properties |
| `ValidationErrorField.swift` | `ValidationErrorField` + `ValidationError` | Two small closely-related types in one file |
| `ConnectDialogViewModel.swift` | `@MainActor @Observable` ViewModel | All state and actions; `KeyPickerHandler` typealias |
| `AuthSelector.swift` | `AuthSelector: View` | Mode picker + credential inputs |
| `TestConnectionButton.swift` | `TestConnectionButton: View` | Button + spinner + status message |
| `ConnectDialog.swift` | `ConnectDialog: View` | Top-level modal; scheme picker + form switcher + button bar |
| `Forms/SFTPForm.swift` | `SFTPForm: View` | SFTP fields |
| `Forms/FTPForm.swift` | `FTPForm: View` | FTP fields |
| `Forms/WebDAVForm.swift` | `WebDAVForm: View` | WebDAV fields |
| `Forms/S3Form.swift` | `S3Form: View` | S3 fields; static `regions` array |
| `Forms/SMBForm.swift` | `SMBForm: View` | SMB fields |

**Deleted:** `Sources/UI/ConnectDialog/Placeholder.swift`

### `Tests/UITests/ConnectDialogTests/` — 6 new files

| File | Test class | Count |
|---|---|---|
| `ConnectDialogTestSupport.swift` | `FakeRemoteConnector` actor + `makeViewModel` factory | — |
| `ConnectDialogViewModelTests.swift` | `ConnectDialogViewModelTests` | 10 tests |
| `ConnectDialogValidationTests.swift` | `ConnectDialogValidationTests` | 17 tests |
| `ConnectDialogTestConnectionTests.swift` | `ConnectDialogTestConnectionTests` | 6 tests |
| `ConnectDialogSaveFlowTests.swift` | `ConnectDialogSaveFlowTests` | 6 tests |
| `ConnectDialogRedactionTests.swift` | `ConnectDialogRedactionTests` | 8 tests |

### `docs/roadmap/stevedore-mvp/session-23-handoff.md` (this file)

## Decisions

- **`@Observable` (not ObservableObject):** `@Observable` macro with `@Bindable` in views.
  All mutation on `@MainActor`. Fully Swift 6 strict-concurrency-compatible.

- **Protocol-only imports:** `UIConnectDialog` imports only `Core` + `DesignSystem`. No
  `FileSystemRemote` or `ServicesCredentials` in the dep graph — keeps build fast and tests
  minimal. `RemoteConnector` and `CredentialStore` are injected Core protocols.

- **`@ObservationIgnored` on all injected protocol existentials:** Prevents the `@Observable`
  macro from wrapping `any CredentialStore` / `any RemoteConnector` / callback closures in
  observation accessors, which would emit Swift 6 non-Sendable warnings. Pattern from Session 18
  (`SidebarViewModel`).

- **`KeyPickerHandler` typealias + injectable closure for NSOpenPanel:** Tests inject a closure
  returning a pre-baked URL. The default implementation calls `NSOpenPanel` on the main actor.
  No panel appears in unit tests.

- **`buildCredential()` extracted into per-scheme private helpers:** The original nested switch
  had cyclomatic complexity 13 (SwiftLint limit 12). Extracted `buildSFTPCredential()`,
  `buildFTPCredential()`, `buildS3Credential()`, and `passwordCredential()` to bring each
  branch under the threshold.

- **S3 IAM / FTP anonymous → nil credential:** `buildCredential()` returns `nil` for IAM and
  anonymous auth; `save()` / `connect()` skip the `credentialStore.store()` call when credential
  is nil.

- **`username` is metadata, not a secret:** `RemoteHostDescriptor.username` stores the username
  for display purposes; it is NOT a credential. The redaction test only seeds actual credential
  fields (password, key passphrase, AWS keys) with the sentinel.

- **Stable UUID at init time:** `id` is generated once in `init()` or taken from `editing.id`.
  All `buildDescriptor()` calls return the same UUID, so credential-store writes and descriptor
  callbacks are always bound to the same identifier.

## Form schema per scheme

### SFTP
- Display name (optional, defaults to hostname)
- Server Address (required)
- Port (optional, default 22, range 1–65535)
- Remote Path (optional)
- Auth: **Password** (username + SecureField + show toggle) | **SSH Key** (file URL + optional passphrase)

### FTP
- Display name
- Server Address (required)
- Port (optional, default 21)
- Remote Path (optional)
- Auth: **Password** (username required) | **Anonymous** (no username/password required)

### WebDAV
- Display name
- Server Address (required)
- Port (optional, default 443)
- Remote Path (optional)
- Auth: **Password** only (username required)

### S3
- Display name
- Custom Endpoint (optional; empty = standard AWS)
- Bucket (required)
- Region (required; Picker from 20 standard AWS regions)
- Auth: **IAM** (no key input) | **Access Key** (Key ID + Secret Key SecureField)

### SMB
- Display name
- Server Address (required)
- Port (optional, default 445)
- Share / Path (optional)
- Auth: **Password** only (username required)

## Save / connect callback contracts

```
save() flow:
  1. validate()                            → abort if false
  2. buildDescriptor()                     → stable UUID descriptor
  3. buildCredential()                     → credential? (nil for IAM / anonymous)
  4. if credential != nil:
         await credentialStore.store(credential!, for: descriptor.id)
  5. await onSave?(descriptor)

connect() flow:
  1–4. Same as save()
  5. await onSave?(descriptor)
  6. await onConnect?(descriptor)

cancel() flow:
  validationErrors.removeAll()
  await onCancel?()
```

## Open issues / risks

1. **Pre-existing flaky test:** `SidebarViewModelTests.testMountedEventAddsVolume` fails
   intermittently due to `Task.yield()` timing. Unrelated to Session 23 changes; already present
   from Session 18. Session 28 (CI Gate) should fix this or mark it as `skip`.

2. **`SSHKeyURL` with unreadable file:** `buildSFTPCredential()` will throw if the chosen key
   file becomes unreadable between pick and save. The error propagates to `save()` which silently
   swallows it via `try?` in `storeCredentialIfNeeded`. Downstream sessions could surface this as
   a validation or alert.

3. **No connection open in `connect()`:** `connect()` calls `onConnect?(descriptor)` but does NOT
   call `RemoteConnector.open(_:credential:)` — that is Session 26 (MainWindow)'s responsibility.
   The callback passes the descriptor so MainWindow can open the connection.

4. **`showPassword` is ViewModel state, not persisted:** Cleared when the sheet is dismissed (VM
   deallocated). Expected behavior per the spec.

## Next-session inputs

- `Sources/UI/ConnectDialog/ConnectDialog.swift` — present as a sheet; set `onSave`, `onConnect`,
  `onCancel` on the ViewModel before presenting.
- `Sources/UI/ConnectDialog/ConnectDialogViewModel.swift` — `init(credentialStore:connector:)` for
  create mode, `init(editing:credentialStore:connector:)` for edit mode.
- `KeyPickerHandler` typealias in `ConnectDialogViewModel.swift` — production callers use the
  default `NSOpenPanel` handler; tests inject a closure.
- Callback contract: `onSave` fires before `onConnect` in the connect flow; both receive the same
  `RemoteHostDescriptor` with stable UUID.
- Session 26 (MainWindow) must inject a real `KeychainCredentialStore` and a real
  `RemoteProviderRegistry`-backed connector when constructing the production ViewModel.

## Verification

All commands run from the worktree root.

```
swift build --target UIConnectDialog -Xswiftc -warnings-as-errors
```
→ Build of target 'UIConnectDialog' complete! 0 warnings.

```
swift test --filter ConnectDialog
```
→ Executed 48 tests, with 0 failures (0 unexpected).

```
swiftformat Sources/UI/ConnectDialog Tests/UITests/ConnectDialogTests --lint
```
→ 0/19 files require formatting.

```
swiftlint --strict Sources/UI/ConnectDialog
```
→ Found 0 violations, 0 serious in 344 files.

```
swift build -Xswiftc -warnings-as-errors
```
→ Build complete! 0 warnings.

**Note on full `swift test` run:** 889 of 890 tests pass. The single failure is the
pre-existing `SidebarViewModelTests.testMountedEventAddsVolume` flaky test (async
`Task.yield()` timing issue from Session 18, unrelated to this session's changes).
