# Session 06 Handoff — Credentials & Keychain Service

## Scope

Implement a hardened, Keychain-backed `CredentialStore` for production use
(`KeychainCredentialStore`), an ephemeral in-memory variant for private-mode
browsing (`PrivateModeCredentialStore`), an SSH key importer
(`SSHKeyImporter`), and the credential redaction helpers — all within
`Sources/Services/Credentials/`. Comprehensive tests cover the Keychain happy
path, upsert semantics, SSH key format/passphrase detection, and every error
path to verify that no secret value ever appears in a log-safe description or
error message.

## What changed

### `Sources/Services/Credentials/`
- **`Placeholder.swift`** — deleted; replaced by the files below.
- **`Module.swift`** — preserves the `ServicesCredentialsModule.moduleName`
  sentinel required by the existing smoke test.
- **`CredentialRedaction.swift`** — adds `redactedDescription: String`
  extension properties to `Core.Credential` and `Core.CredentialMaterial`.
  Uses extension methods (not `CustomStringConvertible` conformances) to avoid
  retroactive conformance warnings under Swift 6 `-warnings-as-errors`.
- **`KeychainQuery.swift`** — internal `enum` with static wrappers around
  `SecItemAdd`, `SecItemCopyMatching`, `SecItemUpdate`, `SecItemDelete`.
  Maps `OSStatus` to `CredentialError` using only the numeric status code; the
  raw credential payload never appears in any error value. Exports an internal
  `KeychainError.duplicateItem` sentinel for upsert coordination.
- **`KeychainCredentialStore.swift`** — `public actor` implementing
  `CredentialStore`. JSON-encodes `Credential` values into `kSecValueData`.
  Uses `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Decoding failures
  are wrapped in `CredentialError.storageFailure` to keep the error type
  surface consistent.
- **`PrivateModeCredentialStore.swift`** — `public actor` backed by an
  in-memory `[UUID: Credential]` dictionary. Clears automatically when the
  actor is deallocated. Provides a `reset()` method for test teardown.
- **`SSHKeyImporter.swift`** — `public struct` with `detectFormat`,
  `isPassphraseProtected`, and `importKey`. Parses OpenSSH new-format binary
  header (magic + cipher field) and PEM `Proc-Type` headers without performing
  cryptographic decryption; returns `CredentialMaterial.privateKey` for the
  connection layer (Citadel) to decrypt at connect time.

### `Tests/ServicesTests/CredentialsTests/`
- **`Fixtures/SSHKeyFixtures.swift`** — synthetic, non-deployable key blobs
  built from correct binary structure (OpenSSH magic + cipher field) and
  PEM-style headers. Marked with FIXTURE ONLY comment.
- **`CredentialRedactionTests.swift`** — 7 tests covering all three
  `CredentialMaterial` variants.
- **`PrivateModeCredentialStoreTests.swift`** — 7 tests (store, get, remove,
  list, upsert, reset, noop-remove).
- **`SSHKeyImporterTests.swift`** — 10 tests covering format detection,
  passphrase detection (PEM and OpenSSH), and import round-trips.
- **`KeychainCredentialStoreTests.swift`** — 10 tests hitting the real macOS
  login Keychain with UUID-isolated service keys; `tearDown` verifies clean
  removal.
- **`KeychainNoLeakTests.swift`** — 9 tests asserting that no secret value
  appears in any error description or redacted representation.

## Decisions

- **`CredentialMaterial` not duplicated.** The session brief implied defining
  a second `Credential.swift` in `ServicesCredentials`; instead, we use
  `Core.Credential` / `Core.CredentialMaterial` as-is. The `awsKeyCredential`
  variant from the brief can be represented as `oauthToken` with a tagged
  service name — no type-system change required.

- **Retroactive conformance avoided.** Adding `CustomStringConvertible` to
  `Core.Credential` from another module triggers a compiler warning under
  `-warnings-as-errors`. Instead, `CredentialRedaction.swift` adds
  `var redactedDescription: String` as a plain extension method (no protocol
  conformance), which is fully legal and produces no warning.

- **`PrivateModeCredentialStore` not named `InMemoryCredentialStore`.** The
  Core fake already owns that name. Using `PrivateModeCredentialStore` makes
  the purpose clear (private-mode browsing session) and avoids type-name
  collision across modules.

- **No `kSecAttrSynchronizable` in any query.** All keychain items are
  device-local by omission of the synchronizable attribute, consistent with
  `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.

- **No explicit access group.** Items land in the app's default keychain
  access group. Cross-process sharing (e.g., helper daemons) would require an
  explicit group; that is a future concern and is noted below.

- **SSHKeyImporter is a pure parser, not a decryptor.** Decrypting AES-256-CTR
  key blobs requires Citadel (which is not a dependency of `ServicesCredentials`
  per `Package.swift`). The importer stores the PEM string and passphrase
  together; Citadel receives both at SSH connect time.

- **`wrapMultilineStatementBraces` vs `opening_brace` conflict.** SwiftFormat's
  `wrapMultilineStatementBraces` rule wants the opening brace on its own line
  for multi-line `if` conditions; SwiftLint's `opening_brace` wants it on the
  same line. Resolution: extract multi-line boolean expressions into `let`
  bindings so the resulting `if` condition is always single-line.

## Keychain access groups and ACL strategy

- **Access group**: not set (`kSecAttrAccessGroup` omitted). Items live in
  the app's default access group. If a future session introduces an XPC
  helper or a Safari extension that needs to share credentials, it must
  explicitly set a matching access group in both the main app entitlement and
  the helper's `KeychainCredentialStore(service:accessGroup:)` (a parameter
  that does not yet exist but is easy to add).
- **Accessibility**: `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` —
  survives device sleep/wake without user re-authentication, never syncs to
  iCloud Keychain, and is deleted if the device is restored from backup on
  another device.
- **ACL**: default ACL (app's Team ID). No custom `SecACL` or UI prompt for
  credential access.

## How downstream sessions should request credentials

```swift
// Production (Keychain-backed)
let store = KeychainCredentialStore()   // service defaults to "com.stevedore.credentials"
let credential = try await store.credential(for: hostDescriptor.id)

// Private-mode session
let store = PrivateModeCredentialStore()
let credential = try await store.credential(for: hostDescriptor.id)

// Tests (use Core fake — no Keychain access)
let store = InMemoryCredentialStore()   // from Core/Testing
```

Use the `CredentialStore` protocol type in all callers so the implementation
can be swapped without changing call sites.

## Open issues / risks

1. **Keychain availability in CI.** `KeychainCredentialStoreTests` hit the
   real macOS login Keychain. On headless CI the keychain may be locked or
   unavailable. The tests use a unique UUID-suffixed service key and clean
   up in `tearDown`, but may be skipped on locked-keychain CI agents. Add
   `XCTSkipIf(!keychainAvailable)` if CI failures appear.

2. **`--filter CredentialsTests` quality gate matches 0 tests.** Swift
   Package Manager's `--filter` applies the regex to the full test identifier
   (`ClassName/methodName`). None of the credential test class names contain
   the literal string "CredentialsTests". Use `swift test` (full suite) or
   `--filter CredentialStore` (matches `KeychainCredentialStoreTests` and
   `PrivateModeCredentialStoreTests`) instead.

3. **No explicit access group.** Downstream sessions that need cross-process
   credential sharing must add an `accessGroup: String?` parameter to
   `KeychainCredentialStore.init` and pass it through `KeychainQuery`.

4. **SSHKeyImporter does not validate key content.** The importer accepts any
   correctly-headered byte sequence as a valid key and returns it as
   `CredentialMaterial.privateKey`. Citadel will produce a clear error at
   connect time if the material is malformed. No change needed here.

5. **`PrivateModeCredentialStore` has no automatic expiry.** If the private
   browsing session object is referenced indefinitely, credentials accumulate
   in memory. Callers should call `reset()` when ending the session rather
   than relying solely on deallocation.

## Next-session inputs

- `Sources/Services/Credentials/KeychainCredentialStore.swift` — production
  credential store. Any session that opens a remote connection should inject
  this via the `CredentialStore` protocol.
- `Sources/Services/Credentials/PrivateModeCredentialStore.swift` — use
  for private-mode browsing sessions.
- `Sources/Services/Credentials/SSHKeyImporter.swift` — call from the
  Connect-to-server dialog or SSH key import flow to validate and store SSH
  keys before initiating a connection.
- `Sources/Core/Testing/InMemoryCredentialStore.swift` — use in unit tests
  for any component that takes a `CredentialStore` dependency.
- `Sources/Core/Protocols/CredentialStore.swift` — protocol surface; all four
  methods are async throws.

## Verification

All commands run from the worktree root.

```
swift build --target ServicesCredentials
```
Build of target: `ServicesCredentials` complete! (46.21s) — zero warnings.

```
swift build -Xswiftc -warnings-as-errors
```
Build complete! (9.03s) — zero own-target warnings across the full package.

```
swift test
```
Executed 89 tests, with 0 failures (0 unexpected) in 0.435 seconds.
(46 Session-01 tests + 43 new credential tests.)

```
swiftformat Sources/Services/Credentials Tests/ServicesTests/CredentialsTests --lint
```
0/12 files require formatting.

```
swiftlint --strict Sources/Services/Credentials
```
Done linting! Found 0 violations, 0 serious in 99 files.

**Note on `--filter CredentialsTests` quality gate**: this regex matches 0
tests with the current naming scheme (none of the test class or method names
contain the literal string "CredentialsTests"). All credential tests are
covered by the `swift test` (full suite) run above. See Open Issues #2.
