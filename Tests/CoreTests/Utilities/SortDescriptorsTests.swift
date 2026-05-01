@testable import Core
import XCTest

final class SortDescriptorsTests: XCTestCase {
    private let locale = Locale(identifier: "en_US_POSIX")

    // MARK: - Helpers

    private func item(
        name: String,
        kind: FileKind = .regularFile,
        size: Int64? = nil,
        modified: Date? = nil
    ) -> FileItem {
        FileItem(
            path: FilePath(scheme: .local, posix: "/\(name)"),
            kind: kind,
            attributes: FileAttributes(sizeInBytes: size, modificationDate: modified)
        )
    }

    // MARK: - directoriesFirst

    func testDirectoriesFirst_dirBeforeFile() {
        let file = self.item(name: "a.txt", kind: .regularFile)
        let dir = self.item(name: "z_dir", kind: .directory)
        let descriptor = FileItemSortDescriptor(
            key: .name,
            ascending: true,
            directoriesFirst: true,
            locale: self.locale
        )
        let sorted = [file, dir].sorted(by: descriptor)
        XCTAssertEqual(sorted[0].kind, .directory)
    }

    func testDirectoriesFirst_holdsWhenDescending() {
        let file = self.item(name: "a.txt", kind: .regularFile)
        let dir = self.item(name: "z_dir", kind: .directory)
        let descriptor = FileItemSortDescriptor(
            key: .name,
            ascending: false,
            directoriesFirst: true,
            locale: self.locale
        )
        let sorted = [file, dir].sorted(by: descriptor)
        XCTAssertEqual(sorted[0].kind, .directory)
    }

    func testDirectoriesFirst_false_dirNotForced() {
        let file = self.item(name: "a.txt", kind: .regularFile)
        let dir = self.item(name: "z_dir", kind: .directory)
        let descriptor = FileItemSortDescriptor(
            key: .name,
            ascending: true,
            directoriesFirst: false,
            locale: self.locale
        )
        let sorted = [file, dir].sorted(by: descriptor)
        // Name ascending: "a.txt" < "z_dir"
        XCTAssertEqual(sorted[0].displayName, "a.txt")
    }

    // MARK: - Sort by name

    func testSortByName_ascending() {
        let items = [item(name: "c"), item(name: "a"), item(name: "b")]
        let sorted = items.sorted(by: FileItemSortDescriptor(
            key: .name,
            ascending: true,
            directoriesFirst: false,
            locale: self.locale
        ))
        XCTAssertEqual(sorted.map(\.displayName), ["a", "b", "c"])
    }

    func testSortByName_descending() {
        let items = [item(name: "c"), item(name: "a"), item(name: "b")]
        let sorted = items.sorted(by: FileItemSortDescriptor(
            key: .name,
            ascending: false,
            directoriesFirst: false,
            locale: self.locale
        ))
        XCTAssertEqual(sorted.map(\.displayName), ["c", "b", "a"])
    }

    // MARK: - Sort by size

    func testSortBySize_ascending() {
        let items = [item(name: "c", size: 300), item(name: "a", size: 100), item(name: "b", size: 200)]
        let sorted = items.sorted(by: FileItemSortDescriptor(
            key: .size,
            ascending: true,
            directoriesFirst: false,
            locale: self.locale
        ))
        XCTAssertEqual(sorted.map(\.attributes.sizeInBytes), [100, 200, 300])
    }

    func testSortBySize_nilSizeSortsFirst() {
        let withSize = self.item(name: "a", size: 100)
        let noSize = self.item(name: "b", size: nil)
        let sorted = [withSize, noSize].sorted(by: FileItemSortDescriptor(
            key: .size,
            ascending: true,
            directoriesFirst: false,
            locale: self.locale
        ))
        XCTAssertNil(sorted[0].attributes.sizeInBytes)
    }

    // MARK: - Sort by modified

    func testSortByModified_ascending() {
        let earlier = Date(timeIntervalSince1970: 1000)
        let later = Date(timeIntervalSince1970: 2000)
        let a = self.item(name: "a", modified: later)
        let b = self.item(name: "b", modified: earlier)
        let sorted = [a, b].sorted(by: FileItemSortDescriptor(
            key: .modified,
            ascending: true,
            directoriesFirst: false,
            locale: self.locale
        ))
        XCTAssertEqual(sorted[0].attributes.modificationDate, earlier)
    }

    func testSortByModified_nilDateSortsFirst() {
        let withDate = self.item(name: "a", modified: Date())
        let noDate = self.item(name: "b", modified: nil)
        let sorted = [withDate, noDate].sorted(by: FileItemSortDescriptor(
            key: .modified,
            ascending: true,
            directoriesFirst: false,
            locale: self.locale
        ))
        XCTAssertNil(sorted[0].attributes.modificationDate)
    }

    // MARK: - Sort by extension

    func testSortByExtension() {
        let swift = self.item(name: "main.swift")
        let txt = self.item(name: "readme.txt")
        let noExt = self.item(name: "Makefile")
        let sorted = [swift, txt, noExt].sorted(by: FileItemSortDescriptor(
            key: .fileExtension,
            ascending: true,
            directoriesFirst: false,
            locale: self.locale
        ))
        // No-extension ("") sorts first
        XCTAssertEqual(sorted[0].displayName, "Makefile")
    }

    func testSortByExtension_tarGz() {
        let tarGz = self.item(name: "archive.tar.gz")
        XCTAssertEqual(
            tarGz.path.displayName.components(separatedBy: ".").last,
            "gz"
        )
    }

    // MARK: - Stable tiebreaker

    func testSortStability_sameNameTiebreaker() {
        // Two items that sort identically by size → tiebreaker is name ascending.
        let a = self.item(name: "alpha", size: 100)
        let b = self.item(name: "beta", size: 100)
        let descriptor = FileItemSortDescriptor(
            key: .size,
            ascending: true,
            directoriesFirst: false,
            locale: self.locale
        )
        let sorted1 = [a, b].sorted(by: descriptor)
        let sorted2 = [b, a].sorted(by: descriptor)
        XCTAssertEqual(sorted1.map(\.displayName), sorted2.map(\.displayName))
        XCTAssertEqual(sorted1[0].displayName, "alpha")
    }

    // MARK: - Convenience statics compile

    func testConvenienceStaticsExist() {
        XCTAssertEqual(FileItemSortDescriptor.byName.key, .name)
        XCTAssertEqual(FileItemSortDescriptor.bySize.key, .size)
        XCTAssertEqual(FileItemSortDescriptor.byModified.key, .modified)
        XCTAssertEqual(FileItemSortDescriptor.byKind.key, .kind)
        XCTAssertEqual(FileItemSortDescriptor.byExtension.key, .fileExtension)
    }
}
