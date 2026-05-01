import AppKit
import Core
import Foundation

// MARK: - Language

/// File-scope enum to satisfy SwiftLint nesting rule.
enum Language: Hashable {
    case swift, python, javascript, typescript, java, go, rust
    case c, cpp, objc, ruby, shell, html, css, json, xml, yaml, sql, unknown

    var keywords: [String] {
        codeLanguageKeywords[self] ?? []
    }

    static func detect(extension ext: String) -> Self {
        codeLanguageExtensions[ext] ?? .unknown
    }
}

// MARK: - Extension → Language lookup

private let codeLanguageExtensions: [String: Language] = [
    "swift": .swift,
    "py": .python, "pyw": .python,
    "js": .javascript, "mjs": .javascript,
    "ts": .typescript, "tsx": .typescript,
    "java": .java,
    "go": .go,
    "rs": .rust,
    "c": .c,
    "cpp": .cpp, "cc": .cpp, "cxx": .cpp, "c++": .cpp,
    "m": .objc, "mm": .objc,
    "rb": .ruby,
    "sh": .shell, "bash": .shell, "zsh": .shell, "fish": .shell, "command": .shell,
    "html": .html, "htm": .html,
    "css": .css, "scss": .css, "less": .css,
    "json": .json,
    "xml": .xml, "plist": .xml,
    "yaml": .yaml, "yml": .yaml,
    "sql": .sql,
    "h": .c, "hpp": .cpp,
    "toml": .unknown, "makefile": .unknown, "dockerfile": .unknown,
]

// MARK: - Language → Keyword lookup

private let codeLanguageKeywords: [Language: [String]] = [
    .swift: [
        "actor", "any", "as", "associatedtype", "async", "await",
        "break", "case", "catch", "class", "continue",
        "defer", "deinit", "do",
        "else", "enum", "extension",
        "fallthrough", "false", "fileprivate", "final", "for", "func",
        "guard",
        "if", "import", "in", "init", "internal", "is",
        "lazy", "let",
        "mutating",
        "nil", "nonisolated",
        "open", "override",
        "private", "protocol", "public",
        "repeat", "return",
        "self", "some", "static", "struct", "subscript", "super", "switch",
        "throw", "throws", "true", "try", "typealias",
        "unowned",
        "var",
        "weak", "where", "while",
    ],
    .python: [
        "and", "as", "assert", "async", "await",
        "break",
        "class", "continue",
        "def", "del",
        "elif", "else", "except",
        "False", "finally", "for", "from",
        "global",
        "if", "import", "in", "is",
        "lambda",
        "None", "nonlocal", "not",
        "or",
        "pass",
        "raise", "return",
        "True", "try",
        "while", "with",
        "yield",
    ],
    .javascript: [
        "async", "await",
        "break",
        "case", "catch", "class", "const", "continue",
        "debugger", "default", "delete", "do",
        "else", "export", "extends",
        "false", "finally", "for", "function",
        "get",
        "if", "import", "in", "instanceof",
        "let",
        "new", "null",
        "of",
        "return",
        "set", "static", "super", "switch",
        "this", "throw", "true", "try", "typeof",
        "undefined",
        "var", "void",
        "while",
        "yield",
    ],
    .typescript: [
        "abstract", "any", "as", "async", "await",
        "boolean", "break",
        "case", "catch", "class", "const", "constructor", "continue",
        "debugger", "declare", "default", "delete", "do",
        "else", "enum", "export", "extends",
        "false", "finally", "for", "from", "function",
        "get",
        "if", "implements", "import", "in", "instanceof", "interface",
        "let",
        "module",
        "namespace", "new", "null", "number",
        "of",
        "override",
        "private", "protected", "public",
        "readonly", "return",
        "set", "static", "string", "super", "switch",
        "this", "throw", "true", "try", "type", "typeof",
        "undefined",
        "var", "void",
        "while",
        "yield",
    ],
    .java: [
        "abstract",
        "boolean", "break", "byte",
        "case", "catch", "char", "class", "continue",
        "default", "do", "double",
        "else", "enum", "extends",
        "false", "final", "finally", "float", "for",
        "if", "implements", "import", "instanceof", "int", "interface",
        "long",
        "native", "new", "null",
        "package", "private", "protected", "public",
        "return",
        "short", "static", "strictfp", "super", "switch", "synchronized",
        "this", "throw", "throws", "transient", "true", "try",
        "void", "volatile",
        "while",
    ],
    .go: [
        "append",
        "break",
        "cap", "case", "chan", "const", "continue",
        "default", "defer",
        "else",
        "false", "for", "func",
        "go", "goto",
        "if", "import", "interface",
        "len",
        "make", "map",
        "new", "nil",
        "package",
        "range", "return",
        "select", "struct", "switch",
        "true", "type",
        "var",
    ],
    .rust: [
        "as", "async", "await",
        "break",
        "const", "continue", "crate",
        "dyn",
        "else", "enum", "extern",
        "false", "fn", "for",
        "if", "impl", "in",
        "let", "loop",
        "match", "mod", "move", "mut",
        "pub",
        "ref", "return",
        "self", "Self", "static", "struct", "super",
        "trait", "true", "type",
        "union", "unsafe", "use",
        "where", "while",
    ],
    .c: [
        "auto", "break",
        "case", "char", "const", "continue",
        "default", "do", "double",
        "else", "enum", "extern",
        "float", "for",
        "goto",
        "if", "inline", "int",
        "long",
        "NULL",
        "register", "restrict", "return",
        "short", "signed", "sizeof", "static", "struct", "switch",
        "typedef",
        "union", "unsigned",
        "void", "volatile",
        "while",
    ],
    .cpp: [
        "alignas", "alignof", "auto",
        "bool", "break",
        "case", "catch", "char", "class", "const", "constexpr", "continue",
        "decltype", "default", "delete", "do", "double",
        "else", "enum", "explicit", "export", "extern",
        "false", "float", "for", "friend",
        "goto",
        "if", "inline", "int",
        "long",
        "namespace", "new", "noexcept", "nullptr",
        "operator", "override",
        "private", "protected", "public",
        "return",
        "short", "signed", "sizeof", "static", "struct", "switch",
        "template", "this", "throw", "true", "try", "typedef", "typeid", "typename",
        "union", "unsigned", "using",
        "virtual", "void", "volatile",
        "while",
    ],
    .objc: [
        "BOOL", "Class", "IMP", "NO", "NULL", "SEL", "YES",
        "auto", "break",
        "case", "char", "const", "continue",
        "default", "do", "double",
        "else", "enum", "extern",
        "float", "for",
        "goto",
        "id", "if", "in", "inline", "int",
        "long",
        "nil", "nonatomic",
        "oneway",
        "return",
        "self", "short", "signed", "sizeof", "static", "struct", "super", "switch",
        "typedef",
        "union", "unsigned",
        "void", "volatile",
        "while",
        "@class", "@end", "@implementation", "@interface", "@property", "@protocol",
        "@selector", "@synthesize",
    ],
    .ruby: [
        "BEGIN", "END",
        "alias", "and",
        "begin", "break",
        "case", "class",
        "def", "defined", "do",
        "else", "elsif", "end", "ensure", "extend",
        "false", "for",
        "if", "in", "include",
        "lambda",
        "module",
        "new", "nil", "not",
        "or",
        "proc",
        "raise", "require", "return",
        "self", "super",
        "then", "true",
        "undef", "unless", "until",
        "when", "while",
        "yield",
    ],
    .shell: [
        "case", "continue",
        "do", "done",
        "echo", "elif", "else", "esac", "exit", "export",
        "fi", "for", "function",
        "if",
        "local",
        "readonly", "return",
        "select", "set", "source",
        "then",
        "unset",
        "while",
    ],
]

// MARK: - CodePreviewRenderer

public enum CodePreviewRenderer {
    public static func render(item: FileItem) async -> PreviewPayload? {
        guard item.kind == .regularFile, item.path.scheme == .local else { return nil }
        let url = URL(fileURLWithPath: item.path.posixString)
        let ext = url.pathExtension.lowercased()
        return await Task.detached(priority: .utility) {
            guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
            let source = String(data: data.prefix(512 * 1024), encoding: .utf8)
                ?? String(data: data.prefix(512 * 1024), encoding: .isoLatin1)
                ?? ""
            let language = Language.detect(extension: ext)
            let attributed = Self.highlight(source: source, language: language)
            let nsSource = source as NSString
            guard let rtfData = attributed.rtf(
                from: NSRange(location: 0, length: nsSource.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            ) else { return nil }
            return PreviewPayload(mimeType: "text/rtf", data: rtfData)
        }.value
    }

    // MARK: - Highlighting

    static func highlight(source: String, language: Language) -> NSAttributedString {
        let result = NSMutableAttributedString(
            string: source,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
                .foregroundColor: NSColor.textColor,
            ]
        )
        Self.applyCommentColors(to: result, source: source)
        Self.applyStringColors(to: result, source: source)
        Self.applyKeywordColors(to: result, source: source, keywords: language.keywords)
        Self.applyNumberColors(to: result, source: source)
        return result
    }

    private static let keywordColor = NSColor.systemBlue
    private static let stringColor = NSColor.systemRed
    private static let commentColor = NSColor.systemGreen
    private static let numberColor = NSColor.systemPurple

    private static func applyKeywordColors(
        to attributed: NSMutableAttributedString,
        source: String,
        keywords: [String]
    ) {
        guard !keywords.isEmpty else { return }
        let escaped = keywords.map { NSRegularExpression.escapedPattern(for: $0) }
        let pattern = "\\b(" + escaped.joined(separator: "|") + ")\\b"
        Self.applyColor(Self.keywordColor, pattern: pattern, to: attributed, source: source)
    }

    private static func applyStringColors(
        to attributed: NSMutableAttributedString,
        source: String
    ) {
        self.applyColor(self.stringColor, pattern: #"\"(?:[^\"\\]|\\.)*\""#, to: attributed, source: source)
        self.applyColor(self.stringColor, pattern: #"'(?:[^'\\]|\\.)*'"#, to: attributed, source: source)
    }

    private static func applyCommentColors(
        to attributed: NSMutableAttributedString,
        source: String
    ) {
        self.applyColor(self.commentColor, pattern: "//[^\n]*", to: attributed, source: source)
        self.applyColor(self.commentColor, pattern: "#[^\n]*", to: attributed, source: source)
        self.applyColor(
            self.commentColor,
            pattern: #"/\*[\s\S]*?\*/"#,
            to: attributed,
            source: source,
            options: [.dotMatchesLineSeparators]
        )
    }

    private static func applyNumberColors(
        to attributed: NSMutableAttributedString,
        source: String
    ) {
        self.applyColor(self.numberColor, pattern: #"\b\d+(\.\d+)?\b"#, to: attributed, source: source)
    }

    private static func applyColor(
        _ color: NSColor,
        pattern: String,
        to attributed: NSMutableAttributedString,
        source: String,
        options: NSRegularExpression.Options = []
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
        let range = NSRange(source.startIndex..., in: source)
        let matches = regex.matches(in: source, range: range)
        for match in matches {
            attributed.addAttribute(.foregroundColor, value: color, range: match.range)
        }
    }
}
