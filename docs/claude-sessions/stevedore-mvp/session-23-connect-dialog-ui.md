---
session: 23
title: "Connect-to-Server Dialog"
depends_on: [01, 02, 04, 06, 08]
touches:
  - Sources/UI/ConnectDialog/**
  - Tests/UITests/ConnectDialogTests/**
parallel_safe: true
---

# Session 23: Connect-to-Server Dialog

Paste this into a new Claude Code session:

```md
Continuity
Continue from Session 01, 02, 04, 06, 08 artifacts. Read each handoff. Use `import FileSystemRemote`, `import ServicesCredentials`, `import DesignSystem`.

Mission
Build the modal that lets the user create or edit a remote connection (SFTP, FTP, WebDAV, S3, SMB), test it, save credentials in Keychain, and open the connection.

Repository anchors
- Sources/UI/ConnectDialog/ConnectDialog.swift
- Sources/UI/ConnectDialog/ConnectDialogViewModel.swift
- Sources/UI/ConnectDialog/Forms/SFTPForm.swift
- Sources/UI/ConnectDialog/Forms/FTPForm.swift
- Sources/UI/ConnectDialog/Forms/WebDAVForm.swift
- Sources/UI/ConnectDialog/Forms/S3Form.swift
- Sources/UI/ConnectDialog/Forms/SMBForm.swift
- Sources/UI/ConnectDialog/AuthSelector.swift (password vs key vs IAM)
- Sources/UI/ConnectDialog/TestConnectionButton.swift
- Tests/UITests/ConnectDialogTests/*.swift

Tasks
1. `ConnectDialogViewModel` (`@MainActor`, `@Observable`) tracks the selected scheme, form fields, auth selection, validation state, test-connection status, and the host-provided save/connect callbacks.
2. Per-scheme forms with field validation: hostname/port range/path, username, password (SecureField), key picker (file URL via NSOpenPanel), region picker (S3), bucket (S3).
3. `AuthSelector` switches between password, SSH key, IAM, anonymous as appropriate per scheme.
4. `TestConnectionButton` runs the `RemoteConnector.test(_:)` from Session 04 with an injected protocol; surfaces success/failure with a clear message; never reveals secrets.
5. Save flow: validate → store credentials via `CredentialStore` (injected) → call host `save(_: RemoteHostDescriptor)` callback. Connect flow: same as save, then host `open(_:)` callback.
6. "Show password" toggle is opt-in and never persisted.
7. Tests: each scheme form validates; test-connection calls the injected connector; save flow invokes credential store with redaction-safe payload; cancel discards changes.

Deliverables
- All source files with tests.
- `docs/roadmap/stevedore-mvp/session-23-handoff.md` covering the form schema per scheme and the save/connect callback contracts.

Quality gates
- `swift build --target UIConnectDialog`
- `swift test --filter ConnectDialogTests`
- `swiftformat --lint Sources/UI/ConnectDialog Tests/UITests/ConnectDialogTests`
- `swiftlint --strict --path Sources/UI/ConnectDialog`

Exit criteria
- No real network or keychain I/O in tests — only injected fakes.
- Validation errors are surfaced inline next to the offending field with `.accessibilityValue` set for screen readers.
- Test-connection failure messages contain no credential material — verified by a redaction test that exercises every error path.
```
