import Darwin
import FilmDomain
import FilmPersistence
import Foundation

// This separate ordinary file stands in for the study's surviving atomic store.
// It is not Keychain and proves no system-store survival or cross-store barrier.
struct FileReceiptStore: ReceiptStoring {
    let url: URL
    init(url: URL) throws {
        self.url = url
        if !FileManager.default.fileExists(atPath: url.path) {
            try write(ReceiptRecord(deviceID: UUID(), receipt: nil))
        }
    }
    func read() throws -> ReceiptRecord {
        try JSONDecoder().decode(ReceiptRecord.self, from: Data(contentsOf: url))
    }
    func publish(_ receipt: Receipt) throws {
        let record = try read()
        if let existing = record.receipt {
            guard existing == receipt else { throw ReceiptFailure.conflict }
            return
        }
        try write(ReceiptRecord(deviceID: record.deviceID, receipt: receipt))
    }
    private func write(_ record: ReceiptRecord) throws {
        try JSONEncoder().encode(record).write(to: url, options: .atomic)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.synchronize()
    }
}

package func runCrashWorker(arguments: [String]) async throws {
    guard arguments.count == 6, let point = Boundary(rawValue: arguments[5]),
          let camera = CameraCatalog.all.first(where: { $0.id.rawValue == arguments[4] }) else {
        throw StudyError.invalidOperation
    }
    let root = URL(fileURLWithPath: arguments[1])
    let store = try FileReceiptStore(url: URL(fileURLWithPath: arguments[2]))
    let source = URL(fileURLWithPath: arguments[3])
    let coordinator = try ReceiptCoordinator(root: root, store: store, boundary: { boundary in
        if boundary == point { _exit(77) }
    })
    let film = try await coordinator.start(camera: camera)
    let kind: CaptureKind
    if camera.medium == .photo { kind = .photo }
    else {
        let verification = try await VerifiedMedia.movie(at: source)
        guard let seconds = verification.durationSeconds else { throw StudyError.invalidOperation }
        kind = .movieClip(seconds: seconds, orientation: .landscape)
    }
    try await coordinator.save(CaptureInput(id: UUID(uuidString: "00000000-0000-0000-0000-000000000456")!,
        filmID: film.id, url: source, kind: kind, savedAt: Date(timeIntervalSince1970: 1_790_870_000)))
    throw StudyError.invalidOperation
}
