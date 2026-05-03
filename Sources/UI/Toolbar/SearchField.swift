import DesignSystem
import SwiftUI

/// Search bar wired to a `SearchDebouncer`. The clear button resets term immediately.
public struct SearchField: View {
    @Bindable private var debouncer: SearchDebouncer

    @Environment(\.theme) private var theme

    public init(debouncer: SearchDebouncer) {
        self.debouncer = debouncer
    }

    public var body: some View {
        HStack(spacing: 0) {
            SDSearchField(text: Binding(
                get: { self.debouncer.term },
                set: { self.debouncer.update($0) }
            ))
            if !self.debouncer.term.isEmpty {
                Button(
                    action: { self.debouncer.clear() },
                    label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(self.theme.colors.textSecondary)
                    }
                )
                .buttonStyle(.plain)
                .padding(.trailing, Spacing.xs)
            }
        }
    }
}
