@testable import FileSystemRemote
import XCTest

final class FTPListParserTests: XCTestCase {
    // MARK: - Unix LIST

    func testUnixFileEntry() {
        let response = "-rw-r--r-- 1 user group 4096 Jan  1 12:00 notes.txt"
        let entries = FTPListParser.parseListResponse(response)
        XCTAssertEqual(entries.count, 1)
        let entry = entries[0]
        XCTAssertEqual(entry.name, "notes.txt")
        XCTAssertFalse(entry.isDirectory)
        XCTAssertEqual(entry.sizeInBytes, 4096)
    }

    func testUnixDirectoryEntry() {
        let response = "drwxr-xr-x 2 user group 4096 Jan  1 12:00 Documents"
        let entries = FTPListParser.parseListResponse(response)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].name, "Documents")
        XCTAssertTrue(entries[0].isDirectory)
    }

    func testUnixMultipleEntries() {
        let response = """
        drwxr-xr-x 2 user group 4096 Jan  1 12:00 Documents
        -rw-r--r-- 1 user group  512 Feb 15 08:30 readme.txt
        -rwxr-xr-x 1 user group 1024 Mar 20 15:45 script.sh
        """
        let entries = FTPListParser.parseListResponse(response)
        XCTAssertEqual(entries.count, 3)
        XCTAssertTrue(entries[0].isDirectory)
        XCTAssertFalse(entries[1].isDirectory)
        XCTAssertFalse(entries[2].isDirectory)
    }

    func testUnixDotEntriesAreSkipped() {
        let response = """
        drwxr-xr-x 2 user group 4096 Jan  1 12:00 .
        drwxr-xr-x 2 user group 4096 Jan  1 12:00 ..
        -rw-r--r-- 1 user group  100 Jan  1 12:00 file.txt
        """
        let entries = FTPListParser.parseListResponse(response)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].name, "file.txt")
    }

    func testUnixSymlinkEntry() {
        let response = "lrwxrwxrwx 1 user group 7 Jan  1 12:00 link -> target"
        let entries = FTPListParser.parseListResponse(response)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].name, "link")
    }

    func testEmptyResponse() {
        XCTAssertTrue(FTPListParser.parseListResponse("").isEmpty)
    }

    func testWhitespaceOnlyResponse() {
        XCTAssertTrue(FTPListParser.parseListResponse("   \n\t\n  ").isEmpty)
    }

    // MARK: - Windows LIST

    func testWindowsDirectoryEntry() {
        let response = "05-01-24  12:00PM       <DIR>          Documents"
        let entries = FTPListParser.parseListResponse(response)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].name, "Documents")
        XCTAssertTrue(entries[0].isDirectory)
    }

    func testWindowsFileEntry() {
        let response = "05-01-24  12:00PM              4096 notes.txt"
        let entries = FTPListParser.parseListResponse(response)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].name, "notes.txt")
        XCTAssertFalse(entries[0].isDirectory)
        XCTAssertEqual(entries[0].sizeInBytes, 4096)
    }

    // MARK: - MLSD

    func testMLSDFileEntry() {
        let response = "type=file;size=1024;modify=20240101120000; readme.txt"
        let entries = FTPListParser.parseMLSDResponse(response)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].name, "readme.txt")
        XCTAssertFalse(entries[0].isDirectory)
        XCTAssertEqual(entries[0].sizeInBytes, 1024)
    }

    func testMLSDDirectoryEntry() {
        let response = "type=dir;size=0;modify=20240101120000; Documents"
        let entries = FTPListParser.parseMLSDResponse(response)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].name, "Documents")
        XCTAssertTrue(entries[0].isDirectory)
    }

    func testMLSDCurrentDirSkipped() {
        let response = """
        type=cdir;size=0;modify=20240101120000; .
        type=pdir;size=0;modify=20240101120000; ..
        type=file;size=512;modify=20240101120000; file.txt
        """
        let entries = FTPListParser.parseMLSDResponse(response)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].name, "file.txt")
    }

    func testMLSDMultipleEntries() {
        let response = """
        type=dir;size=0;modify=20240601000000; Photos
        type=file;size=2048;modify=20240602000000; notes.md
        """
        let entries = FTPListParser.parseMLSDResponse(response)
        XCTAssertEqual(entries.count, 2)
        XCTAssertTrue(entries[0].isDirectory)
        XCTAssertFalse(entries[1].isDirectory)
    }

    func testMLSDDate() throws {
        let response = "type=file;size=1;modify=20240715093045; test.txt"
        let entries = FTPListParser.parseMLSDResponse(response)
        XCTAssertEqual(entries.count, 1)
        let date = entries[0].modificationDate
        XCTAssertNotNil(date)
        let comps = try Calendar(identifier: .gregorian)
            .dateComponents(in: XCTUnwrap(TimeZone(identifier: "UTC")), from: XCTUnwrap(date))
        XCTAssertEqual(comps.year, 2024)
        XCTAssertEqual(comps.month, 7)
        XCTAssertEqual(comps.day, 15)
    }

    func testMLSDEmptyResponse() {
        XCTAssertTrue(FTPListParser.parseMLSDResponse("").isEmpty)
    }
}
