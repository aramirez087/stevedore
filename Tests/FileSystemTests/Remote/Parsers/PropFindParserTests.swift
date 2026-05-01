import Core
@testable import FileSystemRemote
import XCTest

final class PropFindParserTests: XCTestCase {
    private func parse(_ xml: String) throws -> [WebDAVEntry] {
        try PropFindParser.parse(data: Data(xml.utf8))
    }

    // MARK: - Basic parsing

    func testSingleFileEntry() throws {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <D:multistatus xmlns:D="DAV:">
          <D:response>
            <D:href>/files/readme.txt</D:href>
            <D:propstat>
              <D:prop>
                <D:getcontentlength>1024</D:getcontentlength>
                <D:getcontenttype>text/plain</D:getcontenttype>
                <D:getetag>"abc123"</D:getetag>
              </D:prop>
              <D:status>HTTP/1.1 200 OK</D:status>
            </D:propstat>
          </D:response>
        </D:multistatus>
        """
        let entries = try parse(xml)
        XCTAssertEqual(entries.count, 1)
        let entry = entries[0]
        XCTAssertEqual(entry.href, "/files/readme.txt")
        XCTAssertEqual(entry.contentLength, 1024)
        XCTAssertEqual(entry.contentType, "text/plain")
        XCTAssertEqual(entry.etag, "\"abc123\"")
        XCTAssertFalse(entry.isCollection)
        XCTAssertEqual(entry.statusCode, 200)
    }

    func testCollectionEntry() throws {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <D:multistatus xmlns:D="DAV:">
          <D:response>
            <D:href>/files/Documents/</D:href>
            <D:propstat>
              <D:prop>
                <D:resourcetype><D:collection/></D:resourcetype>
                <D:displayname>Documents</D:displayname>
              </D:prop>
              <D:status>HTTP/1.1 200 OK</D:status>
            </D:propstat>
          </D:response>
        </D:multistatus>
        """
        let entries = try parse(xml)
        XCTAssertEqual(entries.count, 1)
        XCTAssertTrue(entries[0].isCollection)
        XCTAssertEqual(entries[0].displayName, "Documents")
    }

    func testMultipleEntries() throws {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <D:multistatus xmlns:D="DAV:">
          <D:response>
            <D:href>/files/</D:href>
            <D:propstat>
              <D:prop><D:resourcetype><D:collection/></D:resourcetype></D:prop>
              <D:status>HTTP/1.1 200 OK</D:status>
            </D:propstat>
          </D:response>
          <D:response>
            <D:href>/files/a.txt</D:href>
            <D:propstat>
              <D:prop><D:getcontentlength>10</D:getcontentlength></D:prop>
              <D:status>HTTP/1.1 200 OK</D:status>
            </D:propstat>
          </D:response>
          <D:response>
            <D:href>/files/b.txt</D:href>
            <D:propstat>
              <D:prop><D:getcontentlength>20</D:getcontentlength></D:prop>
              <D:status>HTTP/1.1 200 OK</D:status>
            </D:propstat>
          </D:response>
        </D:multistatus>
        """
        let entries = try parse(xml)
        XCTAssertEqual(entries.count, 3)
    }

    func testNon200EntriesExcluded() throws {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <D:multistatus xmlns:D="DAV:">
          <D:response>
            <D:href>/files/ok.txt</D:href>
            <D:propstat>
              <D:prop><D:getcontentlength>10</D:getcontentlength></D:prop>
              <D:status>HTTP/1.1 200 OK</D:status>
            </D:propstat>
          </D:response>
          <D:response>
            <D:href>/files/missing.txt</D:href>
            <D:propstat>
              <D:prop/>
              <D:status>HTTP/1.1 404 Not Found</D:status>
            </D:propstat>
          </D:response>
        </D:multistatus>
        """
        let entries = try parse(xml)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].href, "/files/ok.txt")
    }

    func testLastModifiedParsed() throws {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <D:multistatus xmlns:D="DAV:">
          <D:response>
            <D:href>/files/dated.txt</D:href>
            <D:propstat>
              <D:prop>
                <D:getlastmodified>Wed, 01 Jan 2025 12:00:00 GMT</D:getlastmodified>
              </D:prop>
              <D:status>HTTP/1.1 200 OK</D:status>
            </D:propstat>
          </D:response>
        </D:multistatus>
        """
        let entries = try parse(xml)
        XCTAssertEqual(entries.count, 1)
        XCTAssertNotNil(entries[0].lastModified)
    }

    func testInvalidXMLThrows() {
        XCTAssertThrowsError(try self.parse("not xml at all <<<"))
    }

    func testEmptyMultistatus() throws {
        let xml = """
        <?xml version="1.0"?>
        <D:multistatus xmlns:D="DAV:"></D:multistatus>
        """
        let entries = try parse(xml)
        XCTAssertTrue(entries.isEmpty)
    }
}
