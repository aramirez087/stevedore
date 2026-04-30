---
session: 06
title: "Credentials & Keychain Service"
depends_on: [01]
touches:
  - Sources/Services/Credentials/**
  - Tests/ServicesTests/CredentialsTests/**
parallel_safe: true
---

# Session 06: Credentials & Keychain Service

Paste this into a new Claude Code session:

```md
Continuity
Continue from Session 01 artifacts. Read `docs/roadmap/stevedore-mvp/session-01-handoff.md`. The `CredentialStore` protocol is defined in `Sources/Core/Protocols`.

Mission
Provide a hardened Keychain-backed `CredentialStore` for password and key-based credentials, plus an in-memory variant (for tests / private browsing). Power the Connect-to-server dialog and the remote provider auth strategies.

Repository anchors
- Sources/Services/Credentials/KeychainCredentialStore.swift
- Sources/Services/Credentials/Credential.swift (typed: passwordCredential, sshKeyCredential, awsKeyCredential, oauthToken)
- Sources/Services/Credentials/InMemoryCredentialStore.swift (private-mode variant)
- Sources/Services/Credentials/KeychainQuery.swift (Security.framework wrapper)
- Sources/Services/Credentials/SSHKeyImporter.swift (import OpenSSH keys, optionally passphrase-protected)
- Tests/ServicesTests/CredentialsTests/*.swift

Tasks
1. Wrap `SecItemAdd`/`SecItemCopyMatching`/`SecItemUpdate`/`SecItemDelete` in `KeychainQuery` with strict typing, error mapping, and synchronous-only access (no `kSecAttrSynchronizable`).
2. `KeychainCredentialStore` actor: store/retrieve/list/delete `Credential` keyed by `RemoteHostDescriptor.id`. Use `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Tests run against the user's login keychain inside a temporary access group; they clean up in `tearDown`.
3. `Credential` enum with associated values, Codable. Sensitive fields are `String` but never logged; provide a `redacted` description.
4. `InMemoryCredentialStore` for private-mode browsing: actor-isolated dictionary; clears on dealloc/process exit.
5. `SSHKeyImporter`: parse OpenSSH private keys (PEM-style and OpenSSH new format); detect passphrase protection; re-encode for Citadel. Handle ed25519, rsa, ecdsa.
6. Tests: keychain happy path (add/get/delete), credential redaction, SSH key import round-trip including passphrase decryption with a fixture key (test-only fixture; never a real user's key).

Deliverables
- All source files with tests.
- `docs/roadmap/stevedore-mvp/session-06-handoff.md` covering keychain access groups, ACL strategy, and how downstream sessions should request credentials.

Quality gates
- `swift build --target ServicesCredentials`
- `swift test --filter CredentialsTests`
- `swiftformat --lint Sources/Services/Credentials Tests/ServicesTests/CredentialsTests`
- `swiftlint --strict --path Sources/Services/Credentials`

Exit criteria
- No credential value is ever printed via `os.Logger` or stringified into errors — verified by a unit test that exercises every error path and asserts the message contains no secret material.
- Keychain entries created during tests are removed on teardown — verified by a follow-up listing.
- All public API is `Sendable` and actor-isolated; no `@unchecked Sendable`.
```
