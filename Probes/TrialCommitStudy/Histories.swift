import Foundation

// An idealized crash-prefix exploration, not a native persistence implementation.
// Even perfect atomic writes and perfect surviving Keychain markers are assumed.
enum Action: String, Codable {
    case prepareRecoverableMedia, commitSQLiteCapture, reserveKeychain, consumeKeychain
    case commitKeychainReceipt, publishReceiptToBackup
}

enum Marker: String, Codable { case unused, pending, consumed }

struct State: Codable, Equatable {
    var preparedMedia = false
    var sqliteCapture = false
    var backupReceipt = false
    var keychain = Marker.unused
    var savedEver = false

    mutating func apply(_ action: Action) {
        switch action {
        case .prepareRecoverableMedia: preparedMedia = true
        case .commitSQLiteCapture:
            precondition(preparedMedia)
            sqliteCapture = true
            savedEver = true
        case .reserveKeychain: keychain = .pending
        case .consumeKeychain: keychain = .consumed
        case .commitKeychainReceipt:
            precondition(preparedMedia)
            keychain = .consumed
            // The proposed protocol's commit authority, not the current app's.
            savedEver = true
        case .publishReceiptToBackup:
            precondition(keychain == .consumed && preparedMedia)
            backupReceipt = true
            sqliteCapture = true
        }
    }
}

struct Observation: Codable, Equatable {
    let preparedMedia: Bool
    let sqliteCapture: Bool
    let backupReceipt: Bool
    let keychain: Marker

    init(_ state: State, uninstall: Bool) {
        preparedMedia = uninstall ? false : state.preparedMedia
        sqliteCapture = uninstall ? false : state.sqliteCapture
        backupReceipt = uninstall ? false : state.backupReceipt
        keychain = uninstall ? state.keychain : .unused
    }
}

struct History: Codable {
    let scheme: String
    let actions: [Action]
    let savedEver: Bool
    let reinstallObservation: Observation
    let verdict: String
}

let schemes: [(String, [Action])] = [
    ("current-file-first", [.prepareRecoverableMedia, .commitSQLiteCapture, .consumeKeychain]),
    ("marker-first", [.consumeKeychain, .prepareRecoverableMedia, .commitSQLiteCapture]),
    ("pending-two-phase", [.reserveKeychain, .prepareRecoverableMedia, .commitSQLiteCapture, .consumeKeychain]),
    ("prepared-media-keychain-receipt", [.prepareRecoverableMedia, .commitKeychainReceipt, .publishReceiptToBackup])
]
var histories: [History] = []
for (scheme, actions) in schemes {
    for length in 0...actions.count {
        var state = State()
        for action in actions.prefix(length) { state.apply(action) }
        let observation = Observation(state, uninstall: true)
        let verdict: String
        if observation.keychain == .pending {
            verdict = "ambiguous_after_app_storage_loss"
        } else if (observation.keychain == .consumed) == state.savedEver {
            verdict = "satisfied_in_idealized_reinstall_model_only"
        } else {
            verdict = state.savedEver ? "counterexample_second_trial" : "counterexample_failed_save_consumes_trial"
        }
        histories.append(History(scheme: scheme, actions: Array(actions.prefix(length)),
                                 savedEver: state.savedEver, reinstallObservation: observation, verdict: verdict))
    }
}

let pending = histories.filter { $0.scheme == "pending-two-phase" }
let pendingUnsaved = pending.first { !$0.savedEver && $0.reinstallObservation.keychain == .pending }!
let pendingSaved = pending.first { $0.savedEver && $0.reinstallObservation.keychain == .pending }!
precondition(pendingUnsaved.reinstallObservation == pendingSaved.reinstallObservation)

// A new-device backup drops the source's ThisDeviceOnly marker. Before publishing
// a filesystem receipt, these two histories have identical restorable files.
var beforeReceipt = State()
beforeReceipt.apply(.prepareRecoverableMedia)
var afterReceipt = beforeReceipt
afterReceipt.apply(.commitKeychainReceipt)
let beforeRestore = Observation(beforeReceipt, uninstall: false)
let afterRestore = Observation(afterReceipt, uninstall: false)
precondition(beforeRestore == afterRestore)
precondition(beforeReceipt.savedEver != afterReceipt.savedEver)

struct Report: Codable {
    let purpose: String
    let assumptions: [String]
    let histories: [History]
    let pendingPair: [History]
    let receiptBackupObservation: Observation
    let receiptBackupRequiredCaptureCounts: [Int]
    let conclusion: String
}
let report = Report(
    purpose: "Protocol disconfirmation only; no production or platform acceptance",
    assumptions: ["Each modeled write is atomic and durable", "Keychain survives reinstall perfectly",
                  "Uninstall removes app-controlled storage", "A new-device restore omits source Keychain",
                  "Backup may observe any completed filesystem-write prefix; no cross-store backup barrier is assumed"],
    histories: histories, pendingPair: [pendingUnsaved, pendingSaved],
    receiptBackupObservation: beforeRestore, receiptBackupRequiredCaptureCounts: [0, 1],
    conclusion: "Receipt authority fixes the modeled reinstall window, but not the demonstrated backup distinction. This is not a proof against all native protocols."
)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
print(String(decoding: try encoder.encode(report), as: UTF8.self))
