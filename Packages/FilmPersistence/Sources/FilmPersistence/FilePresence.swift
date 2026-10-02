import Foundation

/// `fileExists(atPath:)` also returns false when an existing item cannot be inspected.
/// Recovery and privacy removal treat only a confirmed-missing item as absent; every
/// other inspection failure throws so it can never read as empty or as removed.
extension FileManager {
    public func itemExists(at url: URL) throws -> Bool {
        do { return try url.checkResourceIsReachable() }
        catch CocoaError.fileReadNoSuchFile { return false }
    }

    public func contentsOfDirectoryIfPresent(at url: URL) throws -> [URL] {
        do { return try contentsOfDirectory(at: url, includingPropertiesForKeys: nil) }
        catch CocoaError.fileReadNoSuchFile { return [] }
    }

    public func removeItemIfPresent(at url: URL) throws {
        do { try removeItem(at: url) }
        catch CocoaError.fileNoSuchFile {}
    }
}
