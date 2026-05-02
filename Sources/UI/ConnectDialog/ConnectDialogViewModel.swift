import AppKit
import Core
import Foundation
import Observation

/// Injectable closure that presents a file-picker and returns the chosen URL.
/// Default implementation opens an NSOpenPanel on the main actor.
public typealias KeyPickerHandler = @MainActor @Sendable () async -> URL?

/// Drives the connect-to-server dialog.
///
/// All mutable state lives here; form views read from and bind to this object.
/// Session 26 constructs the production instance with real store/connector
/// implementations; tests inject fakes.
@MainActor
@Observable
public final class ConnectDialogViewModel {
    // MARK: - Scheme

    public var selectedScheme: ConnectionScheme {
        didSet { self.resetAuthModeIfNeeded() }
    }

    // MARK: - Common fields

    public var displayName: String = ""
    public var hostname: String = ""
    public var portString: String = ""
    public var remotePath: String = ""

    // MARK: - Auth fields

    public var username: String = ""
    public var authMode: AuthMode = .password
    public var password: String = ""
    public var showPassword: Bool = false
    public var sshKeyURL: URL?
    public var sshKeyPassphrase: String = ""

    // MARK: - S3-specific

    public var s3Bucket: String = ""
    public var s3Region: String = "us-east-1"
    public var awsAccessKeyID: String = ""
    public var awsSecretKey: String = ""

    // MARK: - State

    public private(set) var validationErrors: [ValidationError] = []
    public private(set) var testStatus: TestConnectionStatus = .idle
    public private(set) var isSaving: Bool = false

    // MARK: - Callbacks

    public var onSave: (@MainActor (RemoteHostDescriptor) -> Void)?
    public var onConnect: (@MainActor (RemoteHostDescriptor) -> Void)?
    public var onCancel: (@MainActor () -> Void)?

    // MARK: - Injected dependencies

    @ObservationIgnored private let credentialStore: any CredentialStore
    @ObservationIgnored private let connector: any RemoteConnector
    @ObservationIgnored private let keyPickerHandler: KeyPickerHandler
    @ObservationIgnored private let id: UUID

    // MARK: - Init (create mode)

    public init(
        credentialStore: any CredentialStore,
        connector: any RemoteConnector,
        keyPickerHandler: @escaping KeyPickerHandler = ConnectDialogViewModel.defaultKeyPickerHandler
    ) {
        self.id = UUID()
        self.selectedScheme = .sftp
        self.credentialStore = credentialStore
        self.connector = connector
        self.keyPickerHandler = keyPickerHandler
    }

    // MARK: - Init (edit mode)

    public init(
        editing descriptor: RemoteHostDescriptor,
        credentialStore: any CredentialStore,
        connector: any RemoteConnector,
        keyPickerHandler: @escaping KeyPickerHandler = ConnectDialogViewModel.defaultKeyPickerHandler
    ) {
        self.id = descriptor.id
        self.selectedScheme = descriptor.scheme
        self.displayName = descriptor.displayName
        self.hostname = descriptor.host
        self.portString = descriptor.port.map(String.init) ?? ""
        self.username = descriptor.username ?? ""
        self.remotePath = descriptor.initialPath?.posixString ?? ""
        self.credentialStore = credentialStore
        self.connector = connector
        self.keyPickerHandler = keyPickerHandler
    }

    // MARK: - Static helpers

    public static func availableModes(for scheme: ConnectionScheme) -> [AuthMode] {
        switch scheme {
        case .sftp:
            [.password, .sshKey]
        case .ftp:
            [.password, .anonymous]
        case .webdav, .smb:
            [.password]
        case .s3:
            [.iam, .password]
        case .local:
            []
        }
    }

    public static func defaultPort(for scheme: ConnectionScheme) -> Int? {
        switch scheme {
        case .sftp: 22
        case .ftp: 21
        case .webdav: 443
        case .smb: 445
        case .s3, .local: nil
        }
    }

    // MARK: - Validation

    @discardableResult
    public func validate() -> Bool {
        self.validationErrors = []
        switch self.selectedScheme {
        case .sftp:
            self.validateSFTP()
        case .ftp:
            self.validateFTP()
        case .webdav:
            self.validateWebDAV()
        case .s3:
            self.validateS3()
        case .smb:
            self.validateSMB()
        case .local:
            break
        }
        return self.validationErrors.isEmpty
    }

    // MARK: - Build helpers

    public func buildDescriptor() -> RemoteHostDescriptor {
        let name = self.displayName.trimmingCharacters(in: .whitespaces).isEmpty
            ? self.hostname.trimmingCharacters(in: .whitespaces)
            : self.displayName.trimmingCharacters(in: .whitespaces)
        let port = Int(portString.trimmingCharacters(in: .whitespaces))
        let trimmedPath = self.remotePath.trimmingCharacters(in: .whitespaces)
        let path: FilePath? = trimmedPath.isEmpty
            ? nil
            : FilePath(scheme: self.selectedScheme, posix: trimmedPath)
        return RemoteHostDescriptor(
            id: self.id,
            displayName: name,
            scheme: self.selectedScheme,
            host: self.hostname.trimmingCharacters(in: .whitespaces),
            port: port,
            username: self.username.trimmingCharacters(in: .whitespaces).isEmpty ? nil : self.username,
            initialPath: path
        )
    }

    public func buildCredential() throws -> Credential? {
        switch self.selectedScheme {
        case .sftp: try self.buildSFTPCredential()
        case .ftp: self.buildFTPCredential()
        case .webdav, .smb: self.passwordCredential()
        case .s3: self.buildS3Credential()
        case .local: nil
        }
    }

    private func buildSFTPCredential() throws -> Credential? {
        switch self.authMode {
        case .password:
            return self.passwordCredential()
        case .sshKey:
            guard let url = self.sshKeyURL else { return nil }
            let pem = try String(contentsOf: url, encoding: .utf8)
            let passphrase = self.sshKeyPassphrase.isEmpty ? nil : self.sshKeyPassphrase
            return Credential(username: self.username, material: .privateKey(pem: pem, passphrase: passphrase))
        default:
            return nil
        }
    }

    private func buildFTPCredential() -> Credential? {
        self.authMode == .anonymous ? nil : self.passwordCredential()
    }

    private func buildS3Credential() -> Credential? {
        self.authMode == .iam ? nil : Credential(username: self.awsAccessKeyID, material: .password(self.awsSecretKey))
    }

    private func passwordCredential() -> Credential {
        Credential(username: self.username, material: .password(self.password))
    }

    // MARK: - Actions

    public func testConnection() async {
        self.testStatus = .testing
        let descriptor = self.buildDescriptor()
        let credential = try? self.buildCredential()
        let connector = self.connector
        do {
            let result = try await connector.test(descriptor, credential: credential)
            self.testStatus = Self.mapResult(result)
        } catch {
            self.testStatus = .failure(message: "An unknown error occurred.")
        }
    }

    public func save() async {
        guard self.validate() else { return }
        self.isSaving = true
        defer { isSaving = false }
        let descriptor = self.buildDescriptor()
        await self.storeCredentialIfNeeded(for: descriptor.id)
        self.onSave?(descriptor)
    }

    public func connect() async {
        guard self.validate() else { return }
        self.isSaving = true
        defer { isSaving = false }
        let descriptor = self.buildDescriptor()
        await self.storeCredentialIfNeeded(for: descriptor.id)
        self.onSave?(descriptor)
        self.onConnect?(descriptor)
    }

    public func pickSSHKey() async {
        let url = await keyPickerHandler()
        if let url {
            self.sshKeyURL = url
        }
    }

    public func cancel() {
        self.validationErrors.removeAll()
        self.onCancel?()
    }

    // MARK: - Default key picker

    public static let defaultKeyPickerHandler: KeyPickerHandler = {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Select SSH private key file"
        let response = await MainActor.run { panel.runModal() }
        return response == .OK ? panel.url : nil
    }

    // MARK: - Private helpers

    private func resetAuthModeIfNeeded() {
        let allowed = Self.availableModes(for: self.selectedScheme)
        if !allowed.contains(self.authMode) {
            self.authMode = allowed.first ?? .password
        }
    }

    private func storeCredentialIfNeeded(for hostID: RemoteHostDescriptor.ID) async {
        guard let credential = try? buildCredential() else { return }
        try? await self.credentialStore.store(credential, for: hostID)
    }

    private func validateSFTP() {
        self.validateHostname()
        self.validatePort()
        switch self.authMode {
        case .password, .sshKey:
            self.validateUsername()
        default:
            break
        }
        if self.authMode == .sshKey, self.sshKeyURL == nil {
            self.validationErrors.append(ValidationError(field: .sshKeyURL, message: "Select an SSH private key file."))
        }
    }

    private func validateFTP() {
        self.validateHostname()
        self.validatePort()
        if self.authMode == .password {
            self.validateUsername()
        }
    }

    private func validateWebDAV() {
        self.validateHostname()
        self.validatePort()
        self.validateUsername()
    }

    private func validateS3() {
        if self.s3Bucket.trimmingCharacters(in: .whitespaces).isEmpty {
            self.validationErrors.append(ValidationError(field: .s3Bucket, message: "Bucket name is required."))
        }
        if self.s3Region.trimmingCharacters(in: .whitespaces).isEmpty {
            self.validationErrors.append(ValidationError(field: .s3Region, message: "Region is required."))
        }
        if self.authMode == .password {
            if self.awsAccessKeyID.trimmingCharacters(in: .whitespaces).isEmpty {
                self.validationErrors.append(ValidationError(
                    field: .awsAccessKeyID,
                    message: "Access key ID is required."
                ))
            }
            if self.awsSecretKey.trimmingCharacters(in: .whitespaces).isEmpty {
                self.validationErrors.append(ValidationError(
                    field: .awsSecretKey,
                    message: "Secret access key is required."
                ))
            }
        }
    }

    private func validateSMB() {
        self.validateHostname()
        self.validatePort()
        self.validateUsername()
    }

    private func validateHostname() {
        if self.hostname.trimmingCharacters(in: .whitespaces).isEmpty {
            self.validationErrors.append(ValidationError(field: .hostname, message: "Server address is required."))
        }
    }

    private func validatePort() {
        let trimmed = self.portString.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if let value = Int(trimmed) {
            if !(1 ... 65535).contains(value) {
                self.validationErrors.append(ValidationError(
                    field: .port,
                    message: "Port must be between 1 and 65535."
                ))
            }
        } else {
            self.validationErrors.append(ValidationError(field: .port, message: "Port must be a number."))
        }
    }

    private func validateUsername() {
        if self.username.trimmingCharacters(in: .whitespaces).isEmpty {
            self.validationErrors.append(ValidationError(field: .username, message: "Username is required."))
        }
    }

    private static func mapResult(_ result: ConnectionTestResult) -> TestConnectionStatus {
        switch result.status {
        case .success:
            .success(latencyMilliseconds: result.latencyMilliseconds)
        case .authenticationFailed:
            .failure(message: "Authentication failed. Check your credentials.")
        case .unreachable:
            .failure(message: "Server is unreachable. Check the hostname and port.")
        case .timeout:
            .failure(message: "Connection timed out.")
        case .unsupported:
            .failure(message: "This protocol is not supported.")
        case .unknown:
            .failure(message: "An unknown error occurred.")
        }
    }
}
