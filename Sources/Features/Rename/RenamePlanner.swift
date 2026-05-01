import Core
import Foundation

public enum RenamePlanner {
    public static func plan(
        items: [FileItem],
        recipe: RenameRecipe,
        existingSiblings: Set<String> = [],
        collisionStrategy: CollisionResolver.Strategy = .markInvalid
    ) -> [RenameOutcome] {
        guard !items.isEmpty else { return [] }

        if let invalidReason = validateRecipe(recipe) {
            return items.map { item in
                RenameOutcome(item: item, targetName: item.displayName, status: .invalid(reason: invalidReason))
            }
        }

        var outcomes: [RenameOutcome] = []
        for (index, item) in items.enumerated() {
            let parts = renameSplitStemExt(item.displayName)
            var stem = parts.stem
            var ext = parts.ext
            var failed: String?
            for step in recipe.steps {
                do {
                    try step.apply(to: &stem, ext: &ext, index: index)
                } catch {
                    failed = error.localizedDescription
                    break
                }
            }
            if let reason = failed {
                outcomes.append(RenameOutcome(
                    item: item,
                    targetName: item.displayName,
                    status: .invalid(reason: reason)
                ))
            } else {
                let targetName = renameAssembled(stem: stem, ext: ext)
                outcomes.append(RenameOutcome(item: item, targetName: targetName, status: .ok))
            }
        }

        return CollisionResolver.resolve(
            outcomes: outcomes,
            existingSiblings: existingSiblings,
            strategy: collisionStrategy
        )
    }

    private static func validateRecipe(_ recipe: RenameRecipe) -> String? {
        for step in recipe.steps {
            if case .regex(let pattern, _) = step {
                do {
                    _ = try NSRegularExpression(pattern: pattern)
                } catch {
                    return "Invalid regex pattern '\(pattern)': \(error.localizedDescription)"
                }
            }
        }
        return nil
    }
}
