import Foundation

public extension AsyncSequence where Element: Sendable, Self: Sendable {
    /// Collects up to `size` elements and yields them as `[Element]` batches.
    /// A partial batch is emitted when the upstream finishes.
    /// - Precondition: `size >= 1`
    func chunked(by size: Int) -> AsyncThrowingStream<[Element], any Error> {
        precondition(size >= 1, "chunked(by:) size must be >= 1")
        let upstream = self
        return AsyncThrowingStream { continuation in
            let task = Task<Void, Never> {
                var buffer: [Element] = []
                buffer.reserveCapacity(size)
                do {
                    for try await element in upstream {
                        buffer.append(element)
                        if buffer.count == size {
                            continuation.yield(buffer)
                            buffer.removeAll(keepingCapacity: true)
                        }
                    }
                    if !buffer.isEmpty { continuation.yield(buffer) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Rate-limiter: yields the most-recent element seen in each `interval` window.
    /// The final trailing element is always forwarded when the stream ends.
    func throttled(for interval: Duration) -> AsyncThrowingStream<Element, any Error> {
        let upstream = self
        return AsyncThrowingStream { continuation in
            let state = ThrottleState<Element>()

            let upstreamTask = Task<Void, Never> {
                do {
                    for try await element in upstream {
                        await state.setLatest(element)
                    }
                    if let last = await state.takeLatest() {
                        continuation.yield(last)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            let timerTask = Task<Void, Never> {
                while !Task.isCancelled {
                    try? await Task.sleep(for: interval)
                    guard !Task.isCancelled else { break }
                    if let value = await state.takeLatest() {
                        continuation.yield(value)
                    }
                }
            }

            continuation.onTermination = { _ in
                upstreamTask.cancel()
                timerTask.cancel()
            }
        }
    }

    /// Forwards every element unchanged, calling `report` with a `Progress`
    /// snapshot after each observed element.
    ///
    /// - When `Element == FileItem` and `attributes.sizeInBytes` is non-nil,
    ///   `bytesDone` accumulates actual byte counts.
    /// - Otherwise `bytesDone` carries the item count (non-obvious invariant:
    ///   documented in session-02-handoff).
    func withProgress(
        bytesTotal: Int64? = nil,
        phase: Progress.Phase = .transferring,
        report: @escaping @Sendable (Progress) async -> Void
    ) -> AsyncThrowingStream<Element, any Error> {
        let upstream = self
        return AsyncThrowingStream { continuation in
            let task = Task<Void, Never> {
                var bytesDone: Int64 = 0
                var itemsSeen = 0
                do {
                    for try await element in upstream {
                        itemsSeen += 1
                        let sizeIncrement = (element as? FileItem).flatMap(\.attributes.sizeInBytes)
                        if let sizeIncrement {
                            bytesDone += sizeIncrement
                        } else {
                            bytesDone = Int64(itemsSeen)
                        }
                        let progress = Progress(
                            bytesDone: bytesDone,
                            bytesTotal: bytesTotal,
                            phase: phase
                        )
                        await report(progress)
                        continuation.yield(element)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

// MARK: - Private helpers

/// Actor-isolated mutable cell used by `throttled(for:)`.
private actor ThrottleState<Element: Sendable> {
    private var latest: Element?

    func setLatest(_ value: Element) {
        self.latest = value
    }

    func takeLatest() -> Element? {
        defer { self.latest = nil }
        return self.latest
    }
}
