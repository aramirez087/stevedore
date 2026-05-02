import Foundation

public enum MatchScorer {
    public static func score(url: URL, metadata: AppMetadata) -> (score: Double, reason: String) {
        let urlPath = url.path(percentEncoded: false).lowercased()
        let idComponent = metadata.bundleID.components(separatedBy: ".").last ?? ""
        if idComponent.count >= 4, urlPath.contains(idComponent.lowercased()) {
            return (0.9, "Bundle ID match")
        }
        let name = metadata.bundleName.lowercased()
        if name.count >= 3, urlPath.contains(name) {
            return (0.7, "App name match")
        }
        let exe = metadata.executableName.lowercased()
        if exe.count >= 3, urlPath.contains(exe) {
            return (0.5, "Executable name match")
        }
        return (0.1, "Partial match")
    }

    public static func confidence(url: URL, metadata: AppMetadata) -> (Confidence, String) {
        let (score, reason) = Self.score(url: url, metadata: metadata)
        return (Confidence.from(score: score), reason)
    }
}
