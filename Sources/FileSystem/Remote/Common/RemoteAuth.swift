import Core

/// Auth strategy passed to each concrete transport.
public enum RemoteAuthStrategy: Sendable, Hashable {
    case password(username: String, password: String)
    case privateKey(username: String, pem: String, passphrase: String?)
    case bearerToken(String)
    case awsSig4(accessKeyID: String, secretAccessKey: String, region: String)
    case anonymous
}

/// Maps a `Credential` and `RemoteHostDescriptor` to the auth strategy the
/// transport should use.
public enum RemoteAuth {
    public static func strategy(
        for credential: Credential?,
        host: RemoteHostDescriptor,
        region: String = "us-east-1"
    ) -> RemoteAuthStrategy {
        switch host.scheme {
        case .sftp: self.sftpStrategy(credential: credential, host: host)
        case .ftp: self.ftpStrategy(credential: credential, host: host)
        case .webdav: self.webdavStrategy(credential: credential, host: host)
        case .s3: self.s3Strategy(credential: credential, host: host, region: region)
        case .local, .smb: .anonymous
        }
    }

    private static func sftpStrategy(credential: Credential?, host: RemoteHostDescriptor) -> RemoteAuthStrategy {
        guard let cred = credential else { return .anonymous }
        let user = cred.username ?? host.username ?? "anonymous"
        switch cred.material {
        case .password(let pw):
            return .password(username: user, password: pw)
        case .privateKey(let pem, let passphrase):
            return .privateKey(username: user, pem: pem, passphrase: passphrase)
        case .oauthToken:
            return .anonymous
        }
    }

    private static func ftpStrategy(credential: Credential?, host: RemoteHostDescriptor) -> RemoteAuthStrategy {
        guard let cred = credential else { return .anonymous }
        let user = cred.username ?? host.username ?? "anonymous"
        if case .password(let pw) = cred.material {
            return .password(username: user, password: pw)
        }
        return .anonymous
    }

    private static func webdavStrategy(credential: Credential?, host: RemoteHostDescriptor) -> RemoteAuthStrategy {
        guard let cred = credential else { return .anonymous }
        let user = cred.username ?? host.username ?? ""
        switch cred.material {
        case .password(let pw):
            return .password(username: user, password: pw)
        case .oauthToken(let token):
            return .bearerToken(token)
        case .privateKey:
            return .anonymous
        }
    }

    private static func s3Strategy(
        credential: Credential?,
        host: RemoteHostDescriptor,
        region: String
    ) -> RemoteAuthStrategy {
        guard let cred = credential else { return .anonymous }
        let keyID = cred.username ?? ""
        if case .password(let secret) = cred.material {
            return .awsSig4(accessKeyID: keyID, secretAccessKey: secret, region: region)
        }
        return .anonymous
    }
}
