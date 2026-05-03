import Core
@testable import FileSystemArchive
import Foundation
import XCTest
import ZIPFoundation

// MARK: - RecordingProgressReporter

actor RecordingProgressReporter: OperationProgressReporting {
    private(set) var reports: [Core.Progress] = []

    func report(_ progress: Core.Progress) async {
        self.reports.append(progress)
    }
}

// MARK: - Fixtures

enum Fixtures {
    /// Files seeded into every zip/tar fixture: a.txt, dir/b.txt, dir/c.bin
    static let seedFiles: [(String, Data)] = [
        ("a.txt", Data("hello world".utf8)),
        ("dir/b.txt", Data("file b contents".utf8)),
        ("dir/c.bin", Data(repeating: 0xAB, count: 128)),
    ]

    /// Write fixture source files under `root` and return the root URL.
    static func seedDirectory(at root: URL) throws -> URL {
        for (relativePath, contents) in self.seedFiles {
            let dest = root.appendingPathComponent(relativePath)
            try FileManager.default.createDirectory(
                at: dest.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try contents.write(to: dest)
        }
        return root
    }

    /// Build a ZIP fixture at `root`/fixture.zip and return its URL.
    static func zipFixture(at root: URL) async throws -> URL {
        let srcRoot = root.appendingPathComponent("src", isDirectory: true)
        try FileManager.default.createDirectory(at: srcRoot, withIntermediateDirectories: true)
        _ = try self.seedDirectory(at: srcRoot)

        let archiveURL = root.appendingPathComponent("fixture.zip")
        let zip = try Archive(url: archiveURL, accessMode: .create)
        for (relativePath, _) in self.seedFiles {
            let fileURL = srcRoot.appendingPathComponent(relativePath)
            try zip.addEntry(with: relativePath, fileURL: fileURL, compressionMethod: .deflate)
        }
        return archiveURL
    }

    /// Build a tar fixture (`.tar`, `.tar.gz`, or `.tar.bz2`) and return its URL.
    static func tarFixture(format: ArchiveFormat, at root: URL) async throws -> URL {
        let srcRoot = root.appendingPathComponent("src-tar-\(format.rawValue)", isDirectory: true)
        try FileManager.default.createDirectory(at: srcRoot, withIntermediateDirectories: true)
        _ = try self.seedDirectory(at: srcRoot)

        let ext: String
        let flags: [String]
        switch format {
        case .tar: ext = "tar"
            flags = ["-cf"]
        case .tarGzip: ext = "tar.gz"
            flags = ["-czf"]
        case .tarBzip2: ext = "tar.bz2"
            flags = ["-cjf"]
        case .zip: ext = "tar"
            flags = ["-cf"]
        }

        let archiveURL = root.appendingPathComponent("fixture.\(ext)")
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        proc.arguments = flags + [archiveURL.path, "-C", srcRoot.path, "."]
        try proc.run()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else {
            throw XCTestError(.timeoutWhileWaiting, userInfo: [:])
        }
        return archiveURL
    }

    /// Build a ZIP whose entries contain path-traversal components.
    static func maliciousZipFixture(at root: URL) async throws -> URL {
        let archiveURL = root.appendingPathComponent("malicious.zip")
        let zip = try Archive(url: archiveURL, accessMode: .create)
        // Entry with traversal in relative path.
        let payload = Data("evil".utf8)
        try zip.addEntry(
            with: "../escape.txt",
            type: .file,
            uncompressedSize: Int64(payload.count),
            provider: { position, size -> Data in
                payload.subdata(in: Int(position) ..< min(Int(position) + size, payload.count))
            }
        )
        // Entry with absolute path.
        try zip.addEntry(
            with: "/abs/path.txt",
            type: .file,
            uncompressedSize: Int64(payload.count),
            provider: { position, size -> Data in
                payload.subdata(in: Int(position) ..< min(Int(position) + size, payload.count))
            }
        )
        return archiveURL
    }

    /// Build a tar archive whose first entry has path `../escape.txt` using
    /// hand-rolled POSIX ustar headers. No `Process` is used so it works even
    /// if BSD tar strips traversal paths on create.
    static func maliciousTarFixture(at root: URL) async throws -> URL {
        let archiveURL = root.appendingPathComponent("malicious.tar")
        let data = self.buildMaliciousTar()
        try data.write(to: archiveURL)
        return archiveURL
    }

    // MARK: - Private helpers

    private static func buildMaliciousTar() -> Data {
        let payload = Data("evil content".utf8)
        var tarData = Data()
        tarData.append(Self.tarHeader(name: "../escape.txt", size: payload.count))
        // Pad payload to 512-byte block boundary.
        var paddedPayload = payload
        let rem = payload.count % 512
        if rem > 0 { paddedPayload.append(Data(count: 512 - rem)) }
        tarData.append(paddedPayload)
        // Two zero-blocks = end-of-archive.
        tarData.append(Data(count: 1024))
        return tarData
    }

    /// Build a 512-byte ustar tar header for a regular file.
    private static func tarHeader(name: String, size: Int) -> Data {
        var block = [UInt8](repeating: 0, count: 512)
        // Name field: bytes 0-99.
        let nameBytes = Array(name.utf8.prefix(100))
        block.replaceSubrange(0 ..< nameBytes.count, with: nameBytes)
        // Mode: bytes 100-107 (0o644).
        let modeStr = String(format: "%07o\0", 0o644)
        block.replaceSubrange(100 ..< 100 + modeStr.utf8.count, with: Array(modeStr.utf8))
        // UID/GID 108-115, 116-123: zeros (already zero).
        // Size: bytes 124-135.
        let sizeStr = String(format: "%011o\0", size)
        block.replaceSubrange(124 ..< 124 + sizeStr.utf8.count, with: Array(sizeStr.utf8))
        // Mtime: bytes 136-147 (0).
        let mtimeStr = String(format: "%011o\0", 0)
        block.replaceSubrange(136 ..< 136 + mtimeStr.utf8.count, with: Array(mtimeStr.utf8))
        // Type flag: byte 156 = '0' for regular file.
        block[156] = UInt8(ascii: "0")
        // Magic: bytes 257-262 = "ustar\0".
        let magic = Array("ustar\0".utf8)
        block.replaceSubrange(257 ..< 257 + magic.count, with: magic)
        // Version: bytes 263-264 = "00".
        block[263] = UInt8(ascii: "0")
        block[264] = UInt8(ascii: "0")
        // Checksum: bytes 148-155. Fill with spaces first, then compute.
        block.replaceSubrange(148 ..< 156, with: Array(repeating: UInt8(ascii: " "), count: 8))
        let checksum = block.reduce(0) { $0 + Int($1) }
        let checksumStr = String(format: "%06o\0 ", checksum)
        block.replaceSubrange(148 ..< 148 + checksumStr.utf8.count, with: Array(checksumStr.utf8))
        return Data(block)
    }
}

// MARK: - Temp dir helpers

func makeTempDir(label: String = "ArchiveTests") throws -> URL {
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(label)-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    return tmp
}

func assertFileEqual(_ lhs: URL, _ rhs: URL, file: StaticString = #filePath, line: UInt = #line) throws {
    let lhsData = try Data(contentsOf: lhs)
    let rhsData = try Data(contentsOf: rhs)
    XCTAssertEqual(lhsData, rhsData, "File contents differ: \(lhs.lastPathComponent)", file: file, line: line)
}
