import FilmPersistence
import Foundation
import NativeAdapters

enum ExportBoundary: String, Codable { case none, beforeCopy, beforeReply }
enum InjectedExportReply: String, Codable { case success, failBeforeCopy, failAfterCopy, missingReceipt, cancelled }
enum ExportHarnessError: Error { case invalidControl, busy, alreadyPrepared, missingPreparation, unsafePath }
enum InjectedExportError: Error { case beforeCopy, unknownAfterCopy }

struct ExportWriterPlan: Codable, Sendable {
    var boundary: ExportBoundary = .none
    var reply: InjectedExportReply = .success
    var failAtAttempt: Int? = nil
    var acknowledgeAfterCancellation = false
}

struct InjectedAuthorization: PhotoLibraryAuthorizing {
    let status: PhotoLibraryAuthorizationStatus
    let evidence: ScenarioEvidence
    func authorizationStatus(for accessLevel: PhotoLibraryAccessLevel) -> PhotoLibraryAuthorizationStatus {
        evidence.record("injected-authorization", ["level": String(describing: accessLevel), "status": String(describing: status)])
        return status
    }
    func requestAuthorization(for accessLevel: PhotoLibraryAccessLevel) async -> PhotoLibraryAuthorizationStatus {
        evidence.record("injected-permission-request", ["nativePrompt": "false"])
        return status
    }
}

actor ControlledExportWriter: PhotoLibraryWriting {
    let id = UUID()
    let plan: ExportWriterPlan
    let directory: URL
    let workRoot: URL
    let evidence: ScenarioEvidence
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var phase = "idle"
    private(set) var attempts = 0
    private(set) var cancellations = 0

    init(plan: ExportWriterPlan, directory: URL, workRoot: URL, evidence: ScenarioEvidence) throws {
        self.plan = plan; self.directory = directory; self.workRoot = workRoot; self.evidence = evidence
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try ScenarioEvidence.persist(plan, to: evidence.directory.appendingPathComponent("writer-\(id).json"))
    }

    func write(_ request: PhotoExportRequest) async throws -> PhotoExportReceipt {
        let prefix = workRoot.standardizedFileURL.resolvingSymlinksInPath().path + "/"
        guard request.fileURL.standardizedFileURL.resolvingSymlinksInPath().path.hasPrefix(prefix) else {
            throw ExportHarnessError.unsafePath
        }
        attempts += 1
        let attempt = attempts
        evidence.record("writer-entered", ["writer": id.uuidString, "attempt": String(attempt),
            "kind": String(describing: request.mediaKind), "nativePhotoKit": "false"])
        return try await withTaskCancellationHandler {
            try await execute(request, attempt: attempt)
        } onCancel: {
            Task { await self.observedCancellation() }
        }
    }

    private func execute(_ request: PhotoExportRequest, attempt: Int) async throws -> PhotoExportReceipt {
        await checkpoint(.beforeCopy)
        try checkCancellation()
        if plan.reply == .failBeforeCopy || plan.failAtAttempt == attempt {
            evidence.record("injected-export-failure", ["at": "beforeCopy", "writer": id.uuidString])
            throw InjectedExportError.beforeCopy
        }
        let verification = request.mediaKind == .photo ? try VerifiedMedia.photo(at: request.fileURL)
            : try await VerifiedMedia.movie(at: request.fileURL, allowsAudio: true)
        let output = directory.appendingPathComponent("\(id)-\(attempt).\(request.fileURL.pathExtension)")
        try FileManager.default.copyItem(at: request.fileURL, to: output)
        let handle = try FileHandle(forWritingTo: output); try handle.synchronize(); try handle.close()
        guard ScenarioEvidence.hash(try Data(contentsOf: output)) == verification.sha256 else { throw PersistenceError.invalidMedia }
        evidence.record("external-synthetic-copy-completed", ["writer": id.uuidString,
            "file": output.lastPathComponent, "sha256": verification.sha256,
            "decodedFrames": String(verification.decodedFrameCount), "recalledByPrivateRemoval": "false"])
        await checkpoint(.beforeReply)
        try checkCancellation()
        if plan.reply == .failAfterCopy {
            evidence.record("injected-export-failure", ["at": "afterCopy", "writer": id.uuidString])
            throw InjectedExportError.unknownAfterCopy
        }
        if plan.reply == .cancelled {
            evidence.record("injected-cancelled-reply", ["writer": id.uuidString])
            throw CancellationError()
        }
        let receipt = plan.reply == .missingReceipt ? nil : "injected-private-export036:\(id):\(attempt)"
        evidence.record("injected-export-reply", ["writer": id.uuidString, "receipt": receipt ?? "missing",
            "taskCancelled": String(Task.isCancelled)])
        phase = "finished"
        return PhotoExportReceipt(localIdentifier: receipt)
    }

    private func checkCancellation() throws {
        if !plan.acknowledgeAfterCancellation { try Task.checkCancellation() }
    }
    private func observedCancellation() {
        cancellations += 1
        evidence.record("writer-task-cancelled", ["writer": id.uuidString, "phase": phase])
    }
    private func checkpoint(_ boundary: ExportBoundary) async {
        guard plan.boundary == boundary else { return }
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            phase = "paused-\(boundary.rawValue)"
            evidence.record("writer-paused", ["writer": id.uuidString, "phase": phase])
        }
    }
    func release() throws {
        guard let continuation else { throw ExportHarnessError.invalidControl }
        self.continuation = nil; phase = "released"
        evidence.record("writer-released", ["writer": id.uuidString])
        continuation.resume()
    }
}
