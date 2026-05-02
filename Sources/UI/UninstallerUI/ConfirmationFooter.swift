import DesignSystem
import SwiftUI

public struct ConfirmationFooter: View {
    private let confirmationText: String
    private let isEnabled: Bool
    private let isExecuting: Bool
    private let onConfirm: () -> Void
    private let onCancel: () -> Void

    public init(
        confirmationText: String,
        isEnabled: Bool,
        isExecuting: Bool,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.confirmationText = confirmationText
        self.isEnabled = isEnabled
        self.isExecuting = isExecuting
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    public var body: some View {
        HStack {
            Spacer()
            SDButton("Cancel", style: .secondary, action: self.onCancel)
                .disabled(self.isExecuting)
            SDButton(self.confirmationText, style: .destructive, action: self.onConfirm)
                .disabled(!self.isEnabled || self.isExecuting)
        }
        .padding(Spacing.md)
    }
}
