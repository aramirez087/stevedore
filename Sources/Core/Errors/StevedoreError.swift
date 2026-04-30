import Foundation

/// Root error type. Every public-facing API surfaces failures through this
/// tree so the UI can route uniformly to dialogs and the logger.
public enum StevedoreError: Error, Sendable, Hashable {
    case fileSystem(FileSystemError)
    case remote(RemoteError)
    case archive(ArchiveError)
    case credential(CredentialError)
    case settings(SettingsError)
    case cancelled
    case invalidArgument(String)
    case unsupported(String)
}

extension StevedoreError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .fileSystem(let error): error.errorDescription
        case .remote(let error): error.errorDescription
        case .archive(let error): error.errorDescription
        case .credential(let error): error.errorDescription
        case .settings(let error): error.errorDescription
        case .cancelled: "The operation was cancelled."
        case .invalidArgument(let detail): "Invalid argument: \(detail)"
        case .unsupported(let detail): "Unsupported operation: \(detail)"
        }
    }

    /// Maps to the logging category suitable for the failing subsystem.
    public var category: LogCategory {
        switch self {
        case .fileSystem: .fileSystem
        case .remote: .remote
        case .archive: .archive
        case .credential: .credentials
        case .settings: .settings
        case .cancelled, .invalidArgument, .unsupported: .app
        }
    }
}

/// Errors raised by any `FileSystemProvider` or `FileOperationExecutor`.
public enum FileSystemError: Error, Sendable, Hashable, LocalizedError {
    case notFound(FilePath)
    case permissionDenied(FilePath)
    case alreadyExists(FilePath)
    case notADirectory(FilePath)
    case notAFile(FilePath)
    case ioFailure(detail: String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let path): "Not found: \(path.posixString)"
        case .permissionDenied(let path): "Permission denied: \(path.posixString)"
        case .alreadyExists(let path): "Already exists: \(path.posixString)"
        case .notADirectory(let path): "Not a directory: \(path.posixString)"
        case .notAFile(let path): "Not a file: \(path.posixString)"
        case .ioFailure(let detail): "I/O failure: \(detail)"
        }
    }
}

/// Errors raised by `RemoteConnector` or remote `FileSystemProvider`s.
public enum RemoteError: Error, Sendable, Hashable, LocalizedError {
    case authenticationFailed
    case connectionFailed(detail: String)
    case timeout
    case protocolMismatch(detail: String)

    public var errorDescription: String? {
        switch self {
        case .authenticationFailed: "Authentication failed."
        case .connectionFailed(let detail): "Connection failed: \(detail)"
        case .timeout: "Connection timed out."
        case .protocolMismatch(let detail): "Protocol error: \(detail)"
        }
    }
}

/// Errors raised by `ArchiveBrowser`.
public enum ArchiveError: Error, Sendable, Hashable, LocalizedError {
    case unsupportedFormat
    case corruptedEntry(detail: String)
    case passwordRequired

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat: "Unsupported archive format."
        case .corruptedEntry(let detail): "Corrupted archive entry: \(detail)"
        case .passwordRequired: "Archive requires a password."
        }
    }
}

/// Errors raised by `CredentialStore`.
public enum CredentialError: Error, Sendable, Hashable, LocalizedError {
    case notFound
    case storageFailure(detail: String)

    public var errorDescription: String? {
        switch self {
        case .notFound: "Credential not found."
        case .storageFailure(let detail): "Credential storage failure: \(detail)"
        }
    }
}

/// Errors raised by `SettingsStore`.
public enum SettingsError: Error, Sendable, Hashable, LocalizedError {
    case decodingFailed(key: String, detail: String)
    case storageFailure(detail: String)

    public var errorDescription: String? {
        switch self {
        case .decodingFailed(let key, let detail): "Failed to decode setting \(key): \(detail)"
        case .storageFailure(let detail): "Settings storage failure: \(detail)"
        }
    }
}
