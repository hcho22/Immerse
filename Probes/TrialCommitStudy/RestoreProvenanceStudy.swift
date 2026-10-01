import Foundation

// Nonshipping counterexample model. Atomic snapshots, verified complete media and
// surviving authoritative device storage are assumptions, not platform results.
// History/actualReceipt are proof oracles, never inputs to proposedRecovery.
enum Provenance: String, Codable { case requiresMatchingReceipt, existingFilmGrant }
enum Readability: String, Codable { case valid, unavailable, future, malformed }
enum Outcome: String, Codable { case project, wait, publishThenRead, alreadyProjected, ignoreDeleted }
struct StudyReceipt: Codable, Equatable {
    let device: String
    let film: String?
    let capture: String?
    let date: Int?
    var consumed: Bool { film != nil }
}
struct Pending: Codable, Equatable {
    let capture: String
    let date: Int
    let verifiedMediaHash: String
    var provenance: Provenance?
}
struct Image: Codable, Equatable {
    var filmExists = true
    let film: String
    let origin: String?
    var pending: Pending?
    var projected: [String] = []
}
struct Visible: Codable, Equatable {
    var image: Image
    let readability: Readability
    let returned: StudyReceipt
}
struct Witness: Codable {
    let name: String
    let history: [String]
    let visible: Visible
    let actualReceipt: StudyReceipt
    let requiredByCombinedContracts: Outcome
    let proposedOutcome: Outcome
    let proposedOutcomeMeetsRequirement: Bool
}

let origin = "synthetic-source-device"
let unused = StudyReceipt(device: origin, film: nil, capture: nil, date: nil)
let a = StudyReceipt(device: origin, film: "Film-F", capture: "Capture-A", date: 20)
let b = StudyReceipt(device: origin, film: "Film-F", capture: "Capture-B", date: 10)
let otherFilm = StudyReceipt(device: origin, film: "Film-G", capture: "Capture-C", date: 20)
let empty = Image(film: "Film-F", origin: origin)
let mediaHash = "5048c474cddba881a0416ce92cc4fe8757bcbbeba57eb69401a3d0950aef9a55"

func prepare(_ image: Image, reading: StudyReceipt, capture: String = "Capture-B", date: Int = 10) -> Image {
    precondition(image.filmExists && image.pending == nil && image.projected.isEmpty)
    var result = image
    result.pending = Pending(capture: capture, date: date, verifiedMediaHash: mediaHash,
        provenance: reading.device == image.origin && !reading.consumed ? .requiresMatchingReceipt : .existingFilmGrant)
    return result
}

struct History {
    var image = empty
    var actual = unused
    var steps: [String] = []
    var snapshots: [String: Image] = [:]
    var receiptWrites = 0
    mutating func snapshot(_ name: String) {
        precondition(snapshots[name] == nil)
        snapshots[name] = image; steps.append("Snapshot \(name)")
    }
    mutating func restore(_ name: String) {
        image = snapshots[name]!; steps.append("Restore \(name); device receipt unchanged")
    }
    mutating func begin(_ capture: String, at date: Int) {
        image = prepare(image, reading: actual, capture: capture, date: date)
        steps.append("Prepare \(capture) with \(image.pending!.provenance!.rawValue)")
    }
    mutating func publish(applies: Bool, returning: StudyReceipt? = nil) {
        let pending = image.pending!
        precondition(!actual.consumed && image.filmExists && image.projected.isEmpty)
        let attempted = StudyReceipt(device: actual.device, film: image.film, capture: pending.capture, date: pending.date)
        if applies { actual = attempted; receiptWrites += 1 }
        let readback = returning ?? actual
        if readback == attempted {
            image.projected = [pending.capture]; image.pending = nil
        }
        steps.append("Write \(pending.capture): applies=\(applies), matchingReadback=\(readback == attempted)")
    }
    mutating func deleteEmptyFilmAndStart(_ film: String) {
        precondition(!actual.consumed && image.projected.isEmpty)
        image.filmExists = false; image.pending = nil
        steps.append("Delete zero-save current Film without consuming or refunding")
        image = Image(film: film, origin: actual.device)
        steps.append("Start \(film) using still-unused eligibility")
    }
}

func proposedRecovery(_ input: Visible) -> Outcome {
    guard input.image.filmExists else { return .ignoreDeleted }
    guard let pending = input.image.pending else { return .alreadyProjected }
    guard !input.image.projected.contains(pending.capture) else { return .alreadyProjected }
    if input.image.origin == nil { return .project }
    guard input.readability == .valid else { return .wait }
    if input.returned.device != input.image.origin { return .project }
    if pending.provenance == .existingFilmGrant { return .project }
    // Conservatively classify a legacy journal as requiring a matching receipt.
    // The equal-input proof below also defeats the opposite legacy default.
    guard input.returned.consumed else { return .publishThenRead }
    return input.returned.film == input.image.film && input.returned.capture == pending.capture
        && input.returned.date == pending.date ? .project : .wait
}

func witness(_ name: String, _ history: [String], image: Image, returned: StudyReceipt,
             actual: StudyReceipt, expected: Outcome, readability: Readability = .valid) -> Witness {
    let input = Visible(image: image, readability: readability, returned: returned)
    let observed = proposedRecovery(input)
    return Witness(name: name, history: history, visible: input, actualReceipt: actual,
        requiredByCombinedContracts: expected, proposedOutcome: observed,
        proposedOutcomeMeetsRequirement: observed == expected)
}

let prepared = prepare(empty, reading: unused)
var m = History()
m.begin("Capture-B", at: 10)
m.publish(applies: true, returning: a)
precondition(m.actual == b && m.image == prepared && m.receiptWrites == 1)

var r = History()
r.snapshot("E0-empty")
r.begin("Capture-A", at: 20)
r.publish(applies: true)
r.restore("E0-empty")
r.begin("Capture-B", at: 10)
precondition(r.actual == a && r.receiptWrites == 1)

var rows: [Witness] = []
rows.append(witness("empty-backup-R", r.steps,
    image: r.image, returned: r.actual, actual: r.actual, expected: .project))
rows.append(witness("fresh-mismatch-M", m.steps,
    image: m.image, returned: a, actual: m.actual, expected: .wait))
rows.append(witness("exact-control-E", ["Same pending B and actual B as M", "Read exact B"],
    image: prepared, returned: b, actual: b, expected: .project))
precondition(rows[0].visible != rows[1].visible)
precondition(rows.allSatisfy(\.proposedOutcomeMeetsRequirement))

// Decisive pending-backup witness: no consumption occurs before restoring empty
// F. Saving A from that empty image consumes the one eligibility, not a second.
var r2 = History()
r2.snapshot("E0-empty")
r2.begin("Capture-B", at: 10)
r2.snapshot("P0-pending-before-write")
r2.restore("E0-empty")
r2.begin("Capture-A", at: 20)
r2.publish(applies: true)
r2.restore("P0-pending-before-write")
precondition(r2.actual == a && r2.receiptWrites == 1)
let restoredPending = witness("pending-backup-R2", r2.steps,
    image: r2.image, returned: r2.actual, actual: r2.actual, expected: .project)
let conflictedPending = rows[1]
precondition(restoredPending.visible == conflictedPending.visible)
precondition(restoredPending.requiredByCombinedContracts != conflictedPending.requiredByCombinedContracts)
precondition(!restoredPending.proposedOutcomeMeetsRequirement)
rows.append(restoredPending)

var r3 = History()
r3.snapshot("E0-empty")
r3.begin("Capture-B", at: 10)
r3.publish(applies: false)
r3.snapshot("P0-unresolved-unapplied")
r3.restore("E0-empty")
r3.begin("Capture-A", at: 20)
r3.publish(applies: true)
r3.restore("P0-unresolved-unapplied")
precondition(r3.actual == a && r3.receiptWrites == 1)
rows.append(witness("unresolved-unapplied-backup-R3", r3.steps,
    image: r3.image, returned: r3.actual, actual: r3.actual, expected: .project))
precondition(rows.last!.visible == conflictedPending.visible)

var r4 = History()
r4.begin("Capture-B", at: 10)
r4.snapshot("P0-pending-before-write")
r4.deleteEmptyFilmAndStart("Film-G")
r4.begin("Capture-C", at: 20)
r4.publish(applies: true)
r4.restore("P0-pending-before-write")
precondition(r4.actual == otherFilm && r4.receiptWrites == 1)
rows.append(witness("pending-backup-different-film-R4", r4.steps,
    image: r4.image, returned: r4.actual, actual: r4.actual, expected: .project))
rows.append(witness("fresh-different-film-mismatch-M4", [
    "Prepare B; update actual B but return conflicting C for G", "Initial rejection then reopen"
], image: prepared, returned: otherFilm, actual: b, expected: .wait))
precondition(rows[5].visible == rows[6].visible)

var notApplied = History()
notApplied.begin("Capture-B", at: 10)
notApplied.publish(applies: false, returning: a)
precondition(notApplied.actual == unused && notApplied.receiptWrites == 0)
let fabricatedConsumed = witness("unapplied-fabricated-consumed-M5", notApplied.steps,
    image: notApplied.image, returned: a, actual: notApplied.actual, expected: .wait)
precondition(fabricatedConsumed.visible == restoredPending.visible)
rows.append(fabricatedConsumed)

for name in ["after-prepare-before-write", "unresolved-applied", "readable-receipt-before-SQL"] {
    rows.append(witness(name, ["Snapshot pending B with requiresMatchingReceipt", "Actual receipt eventually B", "Reopen with exact B"],
        image: prepared, returned: b, actual: b, expected: .project))
}
rows.append(witness("pending-same-device-unused", ["Snapshot prepared B before write", "Reopen with unused source receipt"],
    image: prepared, returned: unused, actual: unused, expected: .publishThenRead))

for consumed in [false, true] {
    let destination = StudyReceipt(device: "synthetic-foreign-device", film: consumed ? "Destination-Film" : nil,
        capture: consumed ? "Destination-Capture" : nil, date: consumed ? 30 : nil)
    rows.append(witness("foreign-destination-\(consumed ? "used" : "unused")", ["Restore pending B onto foreign device", "Do not consume destination entitlement"],
        image: prepared, returned: destination, actual: destination, expected: .project))
}

var legacy = prepared
legacy.pending!.provenance = nil
let legacyR = witness("legacy-restored-pending", ["Same R2 history but old journal has no provenance field"],
    image: legacy, returned: a, actual: a, expected: .project)
let legacyM = witness("legacy-conflicted-pending", ["Same M history but old journal has no provenance field"],
    image: legacy, returned: a, actual: b, expected: .wait)
precondition(legacyR.visible == legacyM.visible)
rows += [legacyR, legacyM]
let historical = StudyReceipt(device: origin, film: "Film-F", capture: nil, date: 20)
rows.append(witness("historical-consumed-no-capture-receipt", ["Legacy pending restored Film", "Versionless consumed record contains no opaque capture receipt"],
    image: legacy, returned: historical, actual: historical, expected: .project))

for readability in [Readability.unavailable, .future, .malformed] {
    rows.append(witness("blocked-\(readability.rawValue)", ["No authoritative usable receipt record"],
        image: prepared, returned: b, actual: b, expected: .wait, readability: readability))
}
var deleted = prepared
deleted.filmExists = false; deleted.pending = nil
rows.append(witness("deleted-current-stale-callback", ["Quiescent deletion removes current Film and pending", "Stale callback cannot recreate it"],
    image: deleted, returned: b, actual: b, expected: .ignoreDeleted))
var paid = Image(film: "Paid-Film", origin: nil)
paid.pending = prepared.pending
rows.append(witness("paid-isolation", ["Existing paid Film is independent of unreadable Trial"],
    image: paid, returned: b, actual: b, expected: .project, readability: .unavailable))

// Logical repeatability check only. No model branch rewrites or clears a receipt.
// The unsafe alternative project decision cannot be accepted merely because it
// preserves media and is idempotent: M requires an unresolved result.
var projected = prepared
projected.projected = ["Capture-B"]
projected.pending = nil
precondition(proposedRecovery(Visible(image: projected, readability: .valid, returned: b)) == .alreadyProjected)
precondition(prepared.pending?.verifiedMediaHash == mediaHash && prepared.projected.isEmpty)

struct Report: Codable {
    let purpose: String
    let proposedPersistentState: String
    let candidateSatisfiesBothContracts: Bool
    let equalInputPairs: [[String]]
    let rows: [Witness]
    let assumptionsAndLimits: [String]
}
let report = Report(purpose: "Counterexample consistency, not production or native acceptance",
    proposedPersistentState: "Optional per-pending pre-write provenance: requiresMatchingReceipt or existingFilmGrant; not implemented in shipping code",
    candidateSatisfiesBothContracts: false,
    equalInputPairs: [["pending-backup-R2", "fresh-mismatch-M"], ["unresolved-unapplied-backup-R3", "fresh-mismatch-M"],
        ["pending-backup-different-film-R4", "fresh-different-film-mismatch-M4"], ["legacy-restored-pending", "legacy-conflicted-pending"],
        ["pending-backup-R2", "unapplied-fabricated-consumed-M5"]],
    rows: rows, assumptionsAndLimits: [
        "Logical model with atomic complete snapshots and verified source hash assumed; 037 retains actual native/SQLite witnesses",
        "No trusted restore detector, monotonic clock, external historical ledger, native Security, accounts or server",
        "Actual receipt, applied/unapplied history and required outcome are oracles, not production recovery inputs",
        "Foreign device identity is modeled as already readable; actual migration and same-device Keychain retention remain untested",
        "No filesystem, Keychain, migration, privacy or power-loss guarantee follows from a zero exit",
        "Original 036/037 production regressions remain failed; no resolver is changed by this executable"
    ])
let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
print(String(decoding: try encoder.encode(report), as: UTF8.self))
