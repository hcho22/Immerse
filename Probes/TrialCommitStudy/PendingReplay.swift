import Foundation

// Follow-up to Histories.swift: restoration can finish an unresolved operation.
// This model assumes atomic durable actions, verified bytes and serial execution;
// it neither implements nor proves those properties on a native device.
enum Phase: String, Codable { case absent, preparing, pending, rejected, projected }
enum ReceiptOutcome: String, Codable { case notAttempted, rejected, unknown, acknowledged }
enum Event: String, Codable {
    case beginPreparation, finishVerifiedMedia, receiptRejected
    case receiptAcknowledged, receiptUnknownCommitted, receiptUnknownNotCommitted
    case project, persistDefinitiveRejection, cleanup, deleteFilm
}

struct PendingImage: Codable, Equatable {
    var filmExists = true
    var phase = Phase.absent
    var preparedMedia = false
    var projectedCaptureIDs: [String] = []
}

struct Machine {
    var image = PendingImage()
    var sourceReceipt = false
    var knownOutcome = ReceiptOutcome.notAttempted

    mutating func apply(_ event: Event) {
        switch event {
        case .beginPreparation: image.phase = .preparing
        case .finishVerifiedMedia:
            precondition(image.phase == .preparing)
            image.phase = .pending; image.preparedMedia = true
        case .receiptRejected:
            precondition(image.phase == .pending)
            knownOutcome = .rejected
        case .receiptAcknowledged, .receiptUnknownCommitted, .receiptUnknownNotCommitted:
            precondition(image.phase == .pending && image.preparedMedia)
            sourceReceipt = event != .receiptUnknownNotCommitted
            knownOutcome = event == .receiptAcknowledged ? .acknowledged : .unknown
        case .project:
            precondition(sourceReceipt && image.preparedMedia && image.filmExists)
            image.phase = .projected; image.projectedCaptureIDs = ["first-operation"]
        case .persistDefinitiveRejection:
            precondition(!sourceReceipt && knownOutcome != .unknown)
            image.phase = .rejected
        case .cleanup:
            precondition(image.phase == .rejected || image.phase == .projected)
            image.preparedMedia = false
        case .deleteFilm:
            image.filmExists = false
            image.preparedMedia = false
            image.projectedCaptureIDs = []
        }
    }
}

struct Restored: Codable {
    var image: PendingImage
    var destinationTrialConsumed = false

    mutating func replay() {
        guard image.filmExists, image.phase == .pending, image.preparedMedia else { return }
        if !image.projectedCaptureIDs.contains("first-operation") {
            image.projectedCaptureIDs.append("first-operation")
        }
        image.phase = .projected
    }
}

let paths: [(String, [Event])] = [
    ("acknowledged", [.beginPreparation, .finishVerifiedMedia, .receiptAcknowledged, .project, .cleanup]),
    ("unknown-committed", [.beginPreparation, .finishVerifiedMedia, .receiptUnknownCommitted, .project, .cleanup]),
    ("unknown-not-committed", [.beginPreparation, .finishVerifiedMedia, .receiptUnknownNotCommitted]),
    ("rejected-attempt-still-retryable", [.beginPreparation, .finishVerifiedMedia, .receiptRejected]),
    ("definitively-rejected", [.beginPreparation, .finishVerifiedMedia, .receiptRejected, .persistDefinitiveRejection, .cleanup]),
    ("uncommitted-Film-deleted", [.beginPreparation, .finishVerifiedMedia, .deleteFilm]),
    ("committed-Film-deleted", [.beginPreparation, .finishVerifiedMedia, .receiptUnknownCommitted, .deleteFilm])
]

struct Row: Codable {
    let history: String
    let prefix: [Event]
    let sourceReceiptCommitted: Bool
    let restorableImage: PendingImage
    let captureCountAfterTwoReplays: Int
    let destinationTrialConsumed: Bool
}

var rows: [Row] = []
for (history, path) in paths {
    for length in 0...path.count {
        var source = Machine()
        for event in path.prefix(length) { source.apply(event) }
        var destination = Restored(image: source.image)
        destination.replay()
        destination.replay()
        let eligible = source.image.filmExists && (source.image.phase == .pending || source.image.phase == .projected)
        precondition(destination.image.projectedCaptureIDs.count == (eligible ? 1 : 0))
        precondition(!destination.destinationTrialConsumed)
        rows.append(Row(history: history, prefix: Array(path.prefix(length)),
                        sourceReceiptCommitted: source.sourceReceipt, restorableImage: source.image,
                        captureCountAfterTwoReplays: destination.image.projectedCaptureIDs.count,
                        destinationTrialConsumed: destination.destinationTrialConsumed))
    }
}

var beforeReceipt = Machine()
beforeReceipt.apply(.beginPreparation)
beforeReceipt.apply(.finishVerifiedMedia)
var afterReceipt = beforeReceipt
afterReceipt.apply(.receiptUnknownCommitted)
precondition(beforeReceipt.image == afterReceipt.image)
var a = Restored(image: beforeReceipt.image)
var b = Restored(image: afterReceipt.image)
a.replay(); b.replay()
precondition(a.image == b.image && a.image.projectedCaptureIDs.count == 1)

var rejected = beforeReceipt
rejected.apply(.receiptRejected)
rejected.apply(.persistDefinitiveRejection)
var current = Restored(image: rejected.image)
current.replay()
precondition(current.image.projectedCaptureIDs.isEmpty)
// Disconfirm the weaker protocol that only reports rejection in volatile state.
var lostRejection = Restored(image: beforeReceipt.image)
lostRejection.replay()
precondition(lostRejection.image.projectedCaptureIDs.count == 1)

let olderBackup = beforeReceipt.image
var deleted = beforeReceipt
deleted.apply(.deleteFilm)
var currentDeleted = Restored(image: deleted.image)
currentDeleted.replay()
precondition(currentDeleted.image.projectedCaptureIDs.isEmpty)
var olderRestored = Restored(image: olderBackup)
olderRestored.replay()
precondition(olderRestored.image.projectedCaptureIDs.count == 1)

struct Report: Codable {
    let purpose: String
    let rows: [Row]
    let correctedInference: String
    let rejectedCaptureCounterexample: String
    let privacyBoundary: String
    let unprovedConditions: [String]
}
let report = Report(
    purpose: "Pending-replay interpretation study, not native Trial acceptance",
    rows: rows,
    correctedInference: "Identical pending snapshots need not restore distinct counts immediately: both may complete the same verified pending operation later under restored Film rights.",
    rejectedCaptureCounterexample: "If rejection is only volatile and pending bytes remain, replay saves a definitively rejected capture. Persist an abort before reporting final rejection; cleanup must be resumable.",
    privacyBoundary: "Current deleted Film never replays; an older snapshot can restore it under DEC-17. No external historical removal log is added.",
    unprovedConditions: ["Atomic durable receipt semantics and unknown OSStatus resolution", "Prepared-media durability and integrity before receipt", "Serialized first save, abort and privacy removal", "Backup consistency and authoritative Film/capture manifests", "Native Movie budgets, fault timing and device performance", "Real Keychain reinstall and same-device older-backup behavior"]
)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
print(String(decoding: try encoder.encode(report), as: UTF8.self))
