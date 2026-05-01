import SwiftUI

public struct SDProgressBar: View {
    private let value: Double

    @Environment(\.theme) private var theme

    public init(value: Double) {
        self.value = min(1, max(0, value))
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(self.theme.colors.divider)
                Rectangle()
                    .fill(self.theme.colors.accent)
                    .frame(width: geometry.size.width * self.value)
            }
        }
        .frame(height: 4)
        .clipShape(Capsule())
    }
}
