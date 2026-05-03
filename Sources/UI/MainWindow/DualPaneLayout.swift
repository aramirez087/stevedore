import AppKit
import DesignSystem
import SwiftUI

/// Custom horizontal split that exposes `splitFraction` as a `Binding`.
///
/// `HSplitView` (AppKit `NSSplitView`) is intentionally NOT used: it manages its own
/// divider position internally and does not expose a binding, making round-trip
/// persistence via `WindowState` impossible.
public struct DualPaneLayout<Left: View, Right: View>: View {
    @Binding var splitFraction: Double
    let left: Left
    let right: Right

    public init(
        splitFraction: Binding<Double>,
        @ViewBuilder left: () -> Left,
        @ViewBuilder right: () -> Right
    ) {
        self._splitFraction = splitFraction
        self.left = left()
        self.right = right()
    }

    public var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                self.left
                    .frame(width: self.leftWidth(in: geo.size.width))
                PaneDividerStrip(splitFraction: self.$splitFraction, totalWidth: geo.size.width)
                self.right
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func leftWidth(in total: CGFloat) -> CGFloat {
        guard total > 0 else { return 0 }
        let clamped = max(WindowState.minFraction, min(WindowState.maxFraction, self.splitFraction))
        // Subtract half the divider strip (8 pt) so left + divider + right = total.
        let width = total * clamped - 4
        return max(0, width)
    }
}

// MARK: - PaneDividerStrip

private struct PaneDividerStrip: View {
    @Binding var splitFraction: Double
    let totalWidth: CGFloat

    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.12))
            .frame(width: 8)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let newFraction = Double((value.location.x + self.totalWidth * self.splitFraction) / self
                            .totalWidth)
                        self.splitFraction = max(WindowState.minFraction, min(WindowState.maxFraction, newFraction))
                    }
            )
            .onHover { inside in
                if inside {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}
