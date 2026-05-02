import FeaturesUninstaller

public enum ScanState: Sendable {
    case idle
    case scanning
    case ready([AssociatedFile])
    case failed(String)
}
