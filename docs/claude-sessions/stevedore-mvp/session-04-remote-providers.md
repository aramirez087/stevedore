---
session: 04
title: "Remote Filesystem Providers"
depends_on: [01]
touches:
  - Sources/FileSystem/Remote/**
  - Tests/FileSystemTests/RemoteTests/**
parallel_safe: true
---

# Session 04: Remote Filesystem Providers

Paste this into a new Claude Code session:

```md
Continuity
Continue from Session 01 artifacts. Read `docs/roadmap/stevedore-mvp/session-01-handoff.md`. Citadel and Soto are already declared as Package.swift dependencies on the FileSystemRemote target.

Mission
Implement remote `FileSystemProvider`s for SFTP, FTP, WebDAV, and Amazon S3 — each behind the same Core protocol so the UI can treat any volume identically. Provide a registry that resolves a `RemoteHostDescriptor` to a concrete provider.

Repository anchors
- Sources/FileSystem/Remote/RemoteProviderRegistry.swift
- Sources/FileSystem/Remote/SFTP/SFTPProvider.swift (Citadel-backed)
- Sources/FileSystem/Remote/FTP/FTPProvider.swift (URLSession-backed; passive-mode aware)
- Sources/FileSystem/Remote/WebDAV/WebDAVProvider.swift (URLSession + PROPFIND XML parsing)
- Sources/FileSystem/Remote/S3/S3Provider.swift (Soto-backed)
- Sources/FileSystem/Remote/Common/RemoteSession.swift (connection lifecycle, retry, backoff)
- Sources/FileSystem/Remote/Common/RemoteAuth.swift (auth strategies — password, key, bearer, AWS sig)
- Tests/FileSystemTests/RemoteTests/*.swift

Tasks
1. `RemoteSession` actor encapsulating connection pooling, exponential backoff with jitter, cancellation, and idle-timeout disconnect.
2. SFTP provider via Citadel: list, stat, read, write, mkdir, rename, delete, chmod. Stream large files. Resume interrupted transfers via `restartFrom:` byte offset where supported.
3. FTP provider: passive mode by default; LIST + MLSD parsing; UTF-8 + Latin-1 fallback. STOR/RETR with progress callbacks. EPSV on dual-stack hosts.
4. WebDAV provider: PROPFIND with depth 1, MKCOL, MOVE, COPY, DELETE, GET, PUT. Handle 207 Multi-Status XML. Honor If-Match/ETag for conditional writes.
5. S3 provider via Soto: list (paginated), head, get, put with multipart for >8MB, delete, bucket discovery. Region resolution via virtual-host style. Pre-signed URL helper for previews.
6. `RemoteProviderRegistry`: maps `ConnectionScheme` to a provider factory; injectable so tests can register fakes.
7. Tests: unit-level for parsers (PROPFIND XML, FTP LIST grammar) using fixtures; integration-level via local in-process fakes (no real networking). Conformance suite from `Sources/Core/Testing` runs against each provider's fake transport.

Deliverables
- All source files above with tests.
- `docs/roadmap/stevedore-mvp/session-04-handoff.md` covering supported auth modes per scheme, known protocol limitations, retry policy, and how to extend the registry for new schemes.

Quality gates
- `swift build --target FileSystemRemote`
- `swift test --filter RemoteTests`
- `swiftformat --lint Sources/FileSystem/Remote Tests/FileSystemTests/RemoteTests`
- `swiftlint --strict --path Sources/FileSystem/Remote`

Exit criteria
- All four providers pass the shared conformance suite using their respective fake transports.
- No real network I/O in tests; every test runs in <500ms locally.
- Cancellation propagates from the calling Task to the underlying transport (verified by tests using `Task { ... }.cancel()`).
- No `Sendable` warnings under strict concurrency.
```
