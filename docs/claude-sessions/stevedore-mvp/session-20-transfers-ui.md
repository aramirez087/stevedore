---
session: 20
title: "Transfer Queue UI"
depends_on: [01, 02, 08, 10]
touches:
  - Sources/UI/Transfers/**
  - Tests/UITests/TransfersTests/**
parallel_safe: true
---

# Session 20: Transfer Queue UI

Paste this into a new Claude Code session:

```md
Continuity
Continue from Session 01, 02, 08, 10 artifacts. Read each handoff. Use `import FeaturesOperations`, `import DesignSystem`.

Mission
Build the Transfers panel — a live list of pending/active/completed operations with progress, ETA, throughput, pause/resume, and conflict prompts. Drives off the Operations engine's published state.

Repository anchors
- Sources/UI/Transfers/TransfersPanel.swift
- Sources/UI/Transfers/TransfersViewModel.swift
- Sources/UI/Transfers/TransferRow.swift
- Sources/UI/Transfers/AggregateBar.swift
- Sources/UI/Transfers/ConflictPromptView.swift
- Sources/UI/Transfers/EmptyState.swift
- Tests/UITests/TransfersTests/*.swift

Tasks
1. `TransfersViewModel` (`@MainActor`, `@Observable`) consumes the `OperationQueue`'s observation API and projects per-op + aggregate state to the view. Throttle UI updates to ~10 Hz.
2. `TransferRow` shows: kind icon, source→dest, progress bar, throughput (e.g., "12.3 MB/s"), ETA, pause/resume button, cancel.
3. `AggregateBar` at the top shows total bytes done / total bytes pending and a single ETA. Hidden when the queue is empty.
4. `ConflictPromptView`: when an operation suspends with `.ask`, surface a sheet with Skip / Replace / Rename(N) / Apply to All. Resolution flows back to the engine via a continuation handed in by the view-model.
5. `EmptyState` shows a friendly hint ("No transfers — drag files between panes to start") when the queue is empty.
6. Live region accessibility: the aggregate bar announces progress changes with appropriate `.accessibilityValue` updates throttled to once per second.
7. Tests: feed synthetic queue states; assert rendered text, button enablement, conflict resolution callback. Use injected fakes — no real Operations engine I/O.

Deliverables
- All source files with tests.
- `docs/roadmap/stevedore-mvp/session-20-handoff.md` covering the view-model→engine subscription model and conflict-prompt continuation handshake.

Quality gates
- `swift build --target UITransfers`
- `swift test --filter TransfersTests`
- `swiftformat --lint Sources/UI/Transfers Tests/UITests/TransfersTests`
- `swiftlint --strict --path Sources/UI/Transfers`

Exit criteria
- Subscriber tasks are cancelled when the panel disappears — verified by a leak-detection test.
- Conflict prompt round-trips a decision back to the engine in <50ms after user click in a synthetic test.
- ETA displays render correctly across edge values (zero throughput → "—", >1 day → "1 day+").
```
