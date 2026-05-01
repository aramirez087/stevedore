import Core
import Foundation
import os

public actor JSONFileStore {
    private struct MigrationEntry: Sendable {
        let from: Int
        let to: Int
        let transform: @Sendable (Data) throws -> Data
    }

    private let fileURL: URL
    private let tmpURL: URL
    private let schemaVersion: Int
    private var migrations: [MigrationEntry] = []
    private let logger: Logger
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(directory: URL, filename: String, schemaVersion: Int = 1) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)

        self.fileURL = directory.appendingPathComponent(filename + ".json")
        self.tmpURL = directory.appendingPathComponent(filename + ".json.tmp")
        self.schemaVersion = schemaVersion
        self.logger = Logger(subsystem: "com.stevedore", category: "JSONFileStore.\(filename)")

        if fm.fileExists(atPath: self.tmpURL.path) {
            try? fm.removeItem(at: self.tmpURL)
        }
    }

    public func registerMigration(
        from: Int,
        to: Int,
        transform: @escaping @Sendable (Data) throws -> Data
    ) {
        self.migrations.append(MigrationEntry(from: from, to: to, transform: transform))
    }

    public func read<T: Codable>(_ type: T.Type) async -> T? {
        guard FileManager.default.fileExists(atPath: self.fileURL.path) else { return nil }

        guard let data = try? Data(contentsOf: self.fileURL) else {
            self.logger.warning("Could not read \(self.fileURL.lastPathComponent, privacy: .public)")
            return nil
        }

        guard let probe = try? self.decoder.decode(VersionProbe.self, from: data) else {
            self.logger.warning("Corrupt envelope in \(self.fileURL.lastPathComponent, privacy: .public)")
            return nil
        }

        if probe.schemaVersion > self.schemaVersion {
            let file = self.fileURL.lastPathComponent
            let stored = probe.schemaVersion
            let want = self.schemaVersion
            self.logger.warning(
                "Schema downgrade in \(file, privacy: .public): stored=\(stored) want=\(want)"
            )
            return nil
        }

        if probe.schemaVersion == self.schemaVersion {
            guard let envelope = try? self.decoder.decode(Envelope<T>.self, from: data) else {
                self.logger.warning("Failed to decode payload in \(self.fileURL.lastPathComponent, privacy: .public)")
                return nil
            }
            return envelope.payload
        }

        // Migration path: version < schemaVersion
        do {
            let payloadData = try Self.extractPayloadData(from: data)
            let migratedData = try self.applyMigrations(to: payloadData, fromVersion: probe.schemaVersion)
            return try self.decoder.decode(T.self, from: migratedData)
        } catch {
            let file = self.fileURL.lastPathComponent
            let detail = error.localizedDescription
            self.logger.warning(
                "Migration failed for \(file, privacy: .public): \(detail, privacy: .public)"
            )
            return nil
        }
    }

    public func write(_ value: some Codable) async throws {
        let payloadData = try self.encoder.encode(value)
        guard let payloadJSON = try? JSONSerialization.jsonObject(with: payloadData) else {
            throw SettingsError
                .storageFailure(detail: "Failed to serialize payload for \(self.fileURL.lastPathComponent)")
        }
        let envelope: [String: Any] = [
            "schemaVersion": self.schemaVersion,
            "payload": payloadJSON,
        ]
        let data = try JSONSerialization.data(withJSONObject: envelope)
        try data.write(to: self.tmpURL)

        let fm = FileManager.default
        if fm.fileExists(atPath: self.fileURL.path) {
            try fm.replaceItem(
                at: self.fileURL,
                withItemAt: self.tmpURL,
                backupItemName: nil,
                options: [],
                resultingItemURL: nil
            )
        } else {
            try fm.moveItem(at: self.tmpURL, to: self.fileURL)
        }
    }

    private func applyMigrations(to data: Data, fromVersion: Int) throws -> Data {
        var currentData = data
        var version = fromVersion
        while version < self.schemaVersion {
            guard let entry = self.migrations.first(where: { $0.from == version }) else { break }
            currentData = try entry.transform(currentData)
            version = entry.to
        }
        return currentData
    }

    private static func extractPayloadData(from data: Data) throws -> Data {
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let payloadAny = json["payload"]
        else {
            throw SettingsError.decodingFailed(key: "envelope", detail: "Missing payload key")
        }
        return try JSONSerialization.data(withJSONObject: payloadAny, options: .fragmentsAllowed)
    }
}

private struct VersionProbe: Decodable {
    let schemaVersion: Int
}

private struct Envelope<T: Codable>: Codable {
    let schemaVersion: Int
    let payload: T
}
