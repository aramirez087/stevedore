import CoreGraphics

public enum IconSize: Sendable {
    case sm
    case md
    case lg

    public var points: CGFloat {
        switch self {
        case .sm: 12
        case .md: 16
        case .lg: 24
        }
    }
}
