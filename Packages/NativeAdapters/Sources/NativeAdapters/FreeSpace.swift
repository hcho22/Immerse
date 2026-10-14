import Foundation

/// The free space the low-storage warning reads. The app reads it through this seam, so a test sets the reading
/// instead of filling a disk.
public protocol FreeSpaceReading: Sendable {
    /// The bytes the app can use for a save the person asked for. Throws when the system gives no reading.
    func availableBytes() throws -> Int64
}

public enum FreeSpaceError: Error, Equatable {
    /// The volume reports no capacity for important usage.
    case noReading
}

/// Free space on the volume that holds `url`, as the system reports it for important usage: the space an app can
/// really use for something the person asked for, which counts what iOS can clear to make room (purgeable caches
/// and the like). The plain available capacity leaves that out and reads lower than a save can use, so it would
/// warn on an iPhone that still has room.
public struct VolumeFreeSpaceReader: FreeSpaceReading {
    private let url: URL

    public init(url: URL) { self.url = url }

    public func availableBytes() throws -> Int64 {
        var url = url
        url.removeAllCachedResourceValues()
        let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        guard let bytes = values.volumeAvailableCapacityForImportantUsage else { throw FreeSpaceError.noReading }
        return bytes
    }
}

/// When free space counts as low (DEC-12: "Preflight warns below 2 GB free").
public enum LowStorage {
    /// 2 GB as iPhone Settings counts it, in decimal units: 2,000,000,000 bytes, not 2 × 1024³ (2,147,483,648). A
    /// person checks the warning against iPhone Storage, which shows decimal gigabytes, so the warning stops when
    /// Settings shows 2 GB free.
    public static let thresholdBytes: Int64 = 2_000_000_000

    /// Less than the threshold is low; exactly the threshold is not.
    public static func isLow(availableBytes: Int64) -> Bool { availableBytes < thresholdBytes }
}
