import Foundation

struct KeychainProbeRecord: Codable, Equatable {
    var markerID: UUID
    var consumed: Bool
    var writtenAt: Date
    var appBuild: String

    static func fresh(appBuild: String) -> KeychainProbeRecord {
        KeychainProbeRecord(
            markerID: UUID(),
            consumed: false,
            writtenAt: Date(),
            appBuild: appBuild
        )
    }
}
