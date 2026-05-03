import Foundation

// MARK: - Supporting enums

public enum CaseTransform: String, Sendable, Codable, Hashable, CaseIterable {
    case lower, upper, title, preserve
}

public enum TrimPosition: String, Sendable, Codable, Hashable, CaseIterable {
    case leading, trailing, both
}

public enum SequencePosition: String, Sendable, Codable, Hashable, CaseIterable {
    case prefix, suffix, replace
}

public enum ExtensionTransform: String, Sendable, Codable, Hashable, CaseIterable {
    case lower, upper, preserve
}

public enum InsertPosition: Sendable, Codable, Hashable {
    case prefix
    case suffix
    case beforeExtension
    case index(Int)

    private enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    private enum TypeDiscriminator: String, Codable {
        case prefix
        case suffix
        case beforeExtension
        case index
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let discriminator = try container.decode(TypeDiscriminator.self, forKey: .type)
        switch discriminator {
        case .prefix:
            self = .prefix
        case .suffix:
            self = .suffix
        case .beforeExtension:
            self = .beforeExtension
        case .index:
            let value = try container.decode(Int.self, forKey: .value)
            self = .index(value)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .prefix:
            try container.encode(TypeDiscriminator.prefix, forKey: .type)
        case .suffix:
            try container.encode(TypeDiscriminator.suffix, forKey: .type)
        case .beforeExtension:
            try container.encode(TypeDiscriminator.beforeExtension, forKey: .type)
        case .index(let value):
            try container.encode(TypeDiscriminator.index, forKey: .type)
            try container.encode(value, forKey: .value)
        }
    }
}

// MARK: - RenameStep

public enum RenameStep: Sendable, Hashable, Codable {
    case find(text: String, replace: String, caseSensitive: Bool)
    case regex(pattern: String, replacement: String)
    case `case`(CaseTransform)
    case sequence(start: Int, padding: Int, position: SequencePosition)
    case trim(TrimPosition)
    case insert(text: String, at: InsertPosition)
    case `extension`(ExtensionTransform)
}

// MARK: - Step application

public extension RenameStep {
    func apply(to stem: inout String, ext: inout String?, index: Int) throws {
        switch self {
        case .find(let text, let replace, let caseSensitive):
            let options: String.CompareOptions = caseSensitive ? [] : [.caseInsensitive]
            let fullName = renameAssembled(stem: stem, ext: ext)
            let newName = fullName.replacingOccurrences(of: text, with: replace, options: options)
            let parts = renameSplitStemExt(newName)
            stem = parts.stem
            ext = parts.ext

        case .regex(let pattern, let replacement):
            let fullName = renameAssembled(stem: stem, ext: ext)
            let regex = try NSRegularExpression(pattern: pattern)
            let range = NSRange(fullName.startIndex..., in: fullName)
            let newName = regex.stringByReplacingMatches(in: fullName, range: range, withTemplate: replacement)
            let parts = renameSplitStemExt(newName)
            stem = parts.stem
            ext = parts.ext

        case .case(let transform):
            stem = transform.applied(to: stem)

        case .sequence(let start, let padding, let position):
            let number = String(format: "%0\(padding)d", start + index)
            position.apply(number: number, to: &stem)

        case .trim(let position):
            position.apply(to: &stem)

        case .insert(let text, let at):
            at.apply(text: text, to: &stem)

        case .extension(let transform):
            if let current = ext {
                ext = transform.applied(to: current)
            }
        }
    }
}

// MARK: - CaseTransform helpers

extension CaseTransform {
    func applied(to string: String) -> String {
        switch self {
        case .lower:
            string.lowercased()
        case .upper:
            string.uppercased()
        case .title:
            string.capitalized
        case .preserve:
            string
        }
    }
}

// MARK: - ExtensionTransform helpers

extension ExtensionTransform {
    func applied(to string: String) -> String {
        switch self {
        case .lower:
            string.lowercased()
        case .upper:
            string.uppercased()
        case .preserve:
            string
        }
    }
}

// MARK: - TrimPosition helpers

extension TrimPosition {
    func apply(to stem: inout String) {
        switch self {
        case .leading:
            stem = String(stem.drop(while: { $0.isWhitespace }))
        case .trailing:
            if let lastIdx = stem.lastIndex(where: { !$0.isWhitespace }) {
                stem = String(stem[...lastIdx])
            } else {
                stem = ""
            }
        case .both:
            stem = stem.trimmingCharacters(in: .whitespaces)
        }
    }
}

// MARK: - SequencePosition helpers

extension SequencePosition {
    func apply(number: String, to stem: inout String) {
        switch self {
        case .prefix:
            stem = number + stem
        case .suffix:
            stem += number
        case .replace:
            stem = number
        }
    }
}

// MARK: - InsertPosition helpers

extension InsertPosition {
    func apply(text: String, to stem: inout String) {
        switch self {
        case .prefix:
            stem = text + stem
        case .suffix, .beforeExtension:
            stem += text
        case .index(let i):
            let offset = min(i, stem.count)
            let idx = stem.index(stem.startIndex, offsetBy: offset)
            stem.insert(contentsOf: text, at: idx)
        }
    }
}

// MARK: - Private filename helpers

func renameSplitStemExt(_ filename: String) -> (stem: String, ext: String?) {
    guard let dot = filename.lastIndex(of: "."), dot != filename.startIndex else {
        return (stem: filename, ext: nil)
    }
    let stem = String(filename[..<dot])
    let ext = String(filename[filename.index(after: dot)...])
    return (stem: stem, ext: ext)
}

func renameAssembled(stem: String, ext: String?) -> String {
    guard let ext else { return stem }
    return stem + "." + ext
}
