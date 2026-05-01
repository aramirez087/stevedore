import Core
import Foundation

/// A single entry from a WebDAV 207 Multi-Status PROPFIND response.
public struct WebDAVEntry: Sendable, Hashable {
    public let href: String
    public let displayName: String?
    public let contentType: String?
    public let contentLength: Int64?
    public let lastModified: Date?
    public let etag: String?
    public let isCollection: Bool
    public let statusCode: Int

    public init(
        href: String,
        displayName: String? = nil,
        contentType: String? = nil,
        contentLength: Int64? = nil,
        lastModified: Date? = nil,
        etag: String? = nil,
        isCollection: Bool = false,
        statusCode: Int = 200
    ) {
        self.href = href
        self.displayName = displayName
        self.contentType = contentType
        self.contentLength = contentLength
        self.lastModified = lastModified
        self.etag = etag
        self.isCollection = isCollection
        self.statusCode = statusCode
    }
}

/// SAX-style XML parser for WebDAV 207 Multi-Status bodies.
///
/// Uses `@unchecked Sendable` because `NSObject` / `XMLParserDelegate` cannot
/// be retroactively `Sendable`. The parser is stateful only during `parse(data:)`
/// which creates a fresh instance per call and never escapes `self` beyond that
/// call stack — there is no actual cross-thread sharing.
public final class PropFindParser: NSObject, XMLParserDelegate, @unchecked Sendable {
    // MARK: - Public API

    /// Parse a WebDAV 207 XML body and return successfully-responded entries.
    public static func parse(data: Data) throws -> [WebDAVEntry] {
        let instance = PropFindParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = instance
        guard xmlParser.parse() else {
            throw StevedoreError.remote(.protocolMismatch(detail: "Invalid PROPFIND XML"))
        }
        return instance.entries.filter { $0.statusCode == 200 }
    }

    // MARK: - Mutable parser state

    private var entries: [WebDAVEntry] = []
    private var currentHref: String?
    private var currentDisplayName: String?
    private var currentContentType: String?
    private var currentContentLength: Int64?
    private var currentLastModified: Date?
    private var currentETag: String?
    private var currentIsCollection = false
    private var currentStatusCode = 200
    private var currentText = ""
    private var insideResponse = false
    private var insidePropstat = false

    private static let httpDateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        return fmt
    }()

    // MARK: - XMLParserDelegate

    public func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let localName = elementName.components(separatedBy: ":").last ?? elementName
        self.currentText = ""

        switch localName {
        case "response":
            self.insideResponse = true
            self.currentHref = nil
            self.currentDisplayName = nil
            self.currentContentType = nil
            self.currentContentLength = nil
            self.currentLastModified = nil
            self.currentETag = nil
            self.currentIsCollection = false
            self.currentStatusCode = 200
        case "propstat":
            self.insidePropstat = true
        case "collection":
            self.currentIsCollection = true
        default:
            break
        }
    }

    public func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let localName = elementName.components(separatedBy: ":").last ?? elementName
        let text = self.currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        self.applyEndElement(localName: localName, text: text)
    }

    private func applyEndElement(localName: String, text: String) {
        switch localName {
        case "response": self.finalizeResponse()
        case "propstat": self.insidePropstat = false
        case "href": self.applyHref(text)
        case "displayname": self.currentDisplayName = text.isEmpty ? nil : text
        case "getcontenttype": self.currentContentType = text.isEmpty ? nil : text
        case "getcontentlength": self.currentContentLength = Int64(text)
        case "getlastmodified": self.currentLastModified = Self.httpDateFormatter.date(from: text)
        case "getetag": self.currentETag = text.isEmpty ? nil : text
        case "status": self.applyStatus(text)
        default: break
        }
    }

    private func finalizeResponse() {
        if let href = currentHref {
            self.entries.append(WebDAVEntry(
                href: href,
                displayName: self.currentDisplayName,
                contentType: self.currentContentType,
                contentLength: self.currentContentLength,
                lastModified: self.currentLastModified,
                etag: self.currentETag,
                isCollection: self.currentIsCollection,
                statusCode: self.currentStatusCode
            ))
        }
        self.insideResponse = false
        self.insidePropstat = false
    }

    private func applyHref(_ text: String) {
        guard self.insideResponse, !self.insidePropstat else { return }
        self.currentHref = text.isEmpty ? nil : text
    }

    private func applyStatus(_ text: String) {
        let parts = text.components(separatedBy: " ")
        if parts.count >= 2, let code = Int(parts[1]) {
            self.currentStatusCode = code
        }
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        self.currentText += string
    }
}
