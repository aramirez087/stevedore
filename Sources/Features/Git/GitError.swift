/// Typed errors surfaced by the Git module.
public enum GitError: Error, Sendable, Equatable {
    /// `/usr/bin/git` is not present on this machine.
    case gitNotFound
    /// The git process did not complete within the allotted seconds.
    case timeout
    /// git exited with a non-zero status code.
    case nonZeroExit(code: Int32)
    /// Porcelain v2 output could not be parsed.
    case parseFailure(String)
}
