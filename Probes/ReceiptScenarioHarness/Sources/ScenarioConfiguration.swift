import FilmDomain
import FilmPersistence
import Foundation

enum ReceiptBackend: String, Codable, CaseIterable { case security, injectedFile }
enum ReceiptFault: String, Codable, CaseIterable {
    case none, invalidMedia, lostReply, unknownApplied, unknownNotApplied
    case beforeMove, afterMove, afterCommit, corruptPending, legacyPending, legacyDeleted

    var projection: SaveFailureInjection? {
        switch self {
        case .beforeMove: .beforeDurableMove
        case .afterMove: .afterDurableMoveBeforeDebit
        case .afterCommit: .afterDatabaseCommitBeforeAcknowledgement
        default: nil
        }
    }
}

struct ScenarioConfiguration: Codable, Equatable, Sendable {
    let runID: UUID
    let cameraID: CameraID
    let backend: ReceiptBackend
    let fault: ReceiptFault
    let pauseAt: String

    var camera: CameraPackage { CameraCatalog.all.first { $0.id == cameraID }! }
    var name: String { "\(runID.uuidString)-\(cameraID.rawValue)-\(backend.rawValue)-\(fault.rawValue)-\(pauseAt)" }
    var service: String { "com.immerse.validation.receipt035.\(name)" }
    var directory: URL {
        URL.documentsDirectory.appendingPathComponent("ReceiptScenarios", isDirectory: true).appendingPathComponent(name)
    }
}

struct ScenarioManifest: Codable, Sendable {
    let configuration: ScenarioConfiguration
    let captureUUID: UUID
    let savedAt: Date
    var filmID: UUID?
    var sourcePath: String?
    var sourceHash: String?
    var duration: Double?
    var prepared = false
}

enum HarnessError: Error { case invalidConfiguration, alreadyPrepared, namespaceAlreadyExists, missingPreparation, busy, notPaused, evidenceMismatch }
