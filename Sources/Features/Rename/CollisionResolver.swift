public enum CollisionResolver {
    public enum Strategy: String, Sendable, Codable, Hashable, CaseIterable {
        case markInvalid
        case autoSuffix
    }

    public static func resolve(
        outcomes: [RenameOutcome],
        existingSiblings: Set<String>,
        strategy: Strategy
    ) -> [RenameOutcome] {
        var seen = existingSiblings
        var resolved: [RenameOutcome] = []

        for outcome in outcomes {
            guard outcome.status == .ok else {
                resolved.append(outcome)
                continue
            }
            if seen.contains(outcome.targetName) {
                switch strategy {
                case .markInvalid:
                    resolved.append(RenameOutcome(
                        item: outcome.item,
                        targetName: outcome.targetName,
                        status: .collision
                    ))
                case .autoSuffix:
                    let suffixed = Self.findAvailableSuffix(for: outcome.targetName, avoiding: seen)
                    seen.insert(suffixed)
                    resolved.append(RenameOutcome(
                        item: outcome.item,
                        targetName: suffixed,
                        status: .ok
                    ))
                }
            } else {
                seen.insert(outcome.targetName)
                resolved.append(outcome)
            }
        }
        return resolved
    }

    private static func findAvailableSuffix(for name: String, avoiding seen: Set<String>) -> String {
        var counter = 2
        while true {
            let candidate = Self.suffixed(name, counter)
            if !seen.contains(candidate) {
                return candidate
            }
            counter += 1
        }
    }

    private static func suffixed(_ name: String, _ n: Int) -> String {
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else {
            return "\(name) \(n)"
        }
        let stem = String(name[..<dot])
        let ext = String(name[dot...])
        return "\(stem) \(n)\(ext)"
    }
}
