/// Marker protocol for custom asynchronous sequences of `FileItem` values.
///
/// Concrete providers conform their iterator type to this protocol when they
/// want to expose a typed `AsyncSequence`. `FileSystemProvider.enumerate`
/// returns the concrete `AsyncThrowingStream<FileItem, any Error>` so call
/// sites do not have to dance around constrained existentials, but providers
/// remain free to back the stream with a `FileEnumeration` value internally.
public protocol FileEnumeration: AsyncSequence, Sendable where Element == FileItem {}
