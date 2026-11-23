import Foundation

/// A developed picture waiting on the phone to upload (v2 PRD V2-FR-34, V2-FR-35): its event, exposure and capture
/// time, the developed file and its viewing copy, both kept in the queue's own folder until the server confirms them.
public struct QueuedPicture: Codable, Equatable, Sendable, Identifiable {
    public let eventID: String
    public let exposureNumber: Int
    public let captureTime: Date
    public let contentType: String
    public let queuedAt: Date

    public var id: String { Self.id(eventID: eventID, exposureNumber: exposureNumber) }

    static func id(eventID: String, exposureNumber: Int) -> String { "\(eventID)-\(exposureNumber)" }
}

/// What happened to a queued picture in one pass of the queue.
public enum UploadResult: Equatable, Sendable {
    /// The server confirmed it whole: the queue deleted its copy, and the phone may delete the original.
    case stored(QueuedPicture)
    /// The server will never take it (withdrawn or removed, its shooter removed, taken after the End Time, or the event
    /// gone): the queue deleted it, and the shooter is told (V2-FR-34).
    case refused(QueuedPicture, RefusalCode)
}

/// Sends one queued picture; `PictureUploader` behind the queue's runner in the app, a stand-in in tests.
public protocol QueuedPictureSending: Sendable {
    func send(_ picture: QueuedPicture, file: URL, view: URL?) async throws -> SendOutcome
}

/// The phone's upload queue (V2-FR-35): every developed event picture waits here, on disk, until the server confirms it,
/// so a crash, a closed app, a restart or a lost connection never loses one (V2-FR-34). Each picture is a folder holding
/// its manifest, its developed file and its viewing copy, written whole before the picture counts as queued. Pictures
/// go in capture order, and one that fails stays for the next pass; nothing is ever deleted unconfirmed except by
/// `remove`, which Withdraw Before Reveal, a removal, a deleted event or a server refusal calls.
public actor UploadQueue {
    private let directory: URL
    private let fileManager = FileManager.default

    public init(directory: URL) throws {
        self.directory = directory
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func folder(_ id: String) -> URL { directory.appending(path: id, directoryHint: .isDirectory) }
    private func manifest(_ id: String) -> URL { folder(id).appending(path: "picture.json") }
    private func file(_ id: String) -> URL { folder(id).appending(path: "developed.jpg") }
    private func view(_ id: String) -> URL { folder(id).appending(path: "view.jpg") }

    /// Queues a developed picture and its viewing copy, copying both in. Queuing the same exposure again keeps the first.
    public func enqueue(eventID: String, exposureNumber: Int, captureTime: Date, developed: Data, view viewData: Data?,
                        contentType: String = "image/jpeg") throws {
        let id = QueuedPicture.id(eventID: eventID, exposureNumber: exposureNumber)
        if fileManager.fileExists(atPath: manifest(id).path) { return }
        let staging = directory.appending(path: ".staging-\(UUID().uuidString)", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        do {
            try developed.write(to: staging.appending(path: "developed.jpg"), options: .atomic)
            if let viewData { try viewData.write(to: staging.appending(path: "view.jpg"), options: .atomic) }
            let picture = QueuedPicture(eventID: eventID, exposureNumber: exposureNumber, captureTime: captureTime,
                                        contentType: contentType, queuedAt: .now)
            try JSONEncoder().encode(picture).write(to: staging.appending(path: "picture.json"), options: .atomic)
            // The folder appears whole or not at all.
            try? fileManager.removeItem(at: folder(id))
            try fileManager.moveItem(at: staging, to: folder(id))
        } catch {
            try? fileManager.removeItem(at: staging)
            throw error
        }
    }

    /// Whether an exposure is queued.
    public func contains(eventID: String, exposureNumber: Int) -> Bool {
        fileManager.fileExists(atPath: manifest(QueuedPicture.id(eventID: eventID, exposureNumber: exposureNumber)).path)
    }

    /// Every queued picture, or one event's, in capture order. A folder left half-written by a crash is cleared.
    public func pending(eventID: String? = nil) -> [QueuedPicture] {
        let names = (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? []
        var pictures: [QueuedPicture] = []
        for name in names {
            if name.hasPrefix(".staging-") {
                try? fileManager.removeItem(at: directory.appending(path: name))
                continue
            }
            guard let data = try? Data(contentsOf: manifest(name)),
                  let picture = try? JSONDecoder().decode(QueuedPicture.self, from: data) else { continue }
            if eventID == nil || picture.eventID == eventID { pictures.append(picture) }
        }
        return pictures.sorted { ($0.captureTime, $0.exposureNumber) < ($1.captureTime, $1.exposureNumber) }
    }

    /// The developed file of a queued picture, for the shooter's own Instant print view.
    public func developedFile(of picture: QueuedPicture) -> URL { file(picture.id) }

    /// Deletes a queued picture, which then never uploads.
    public func remove(_ picture: QueuedPicture) throws {
        try removeFolder(picture.id)
    }

    /// Deletes every queued picture of an event, or up to an exposure: Withdraw Before Reveal, the guest removed, the
    /// event deleted (V2-FR-50, V2-FR-53, V2-FR-55).
    @discardableResult
    public func removeAll(eventID: String, throughExposure: Int = .max) throws -> [QueuedPicture] {
        let removed = pending(eventID: eventID).filter { $0.exposureNumber <= throughExposure }
        for picture in removed { try removeFolder(picture.id) }
        return removed
    }

    private func removeFolder(_ id: String) throws {
        do { try fileManager.removeItem(at: folder(id)) } catch CocoaError.fileNoSuchFile {}
    }

    /// One pass: sends every queued picture, or one event's, in capture order. A stored or refused picture leaves the
    /// queue; a failure leaves it for the next pass, and the pass goes on with the rest unless the server could not be
    /// reached, when it stops.
    public func run(using sender: some QueuedPictureSending, eventID: String? = nil) async -> [UploadResult] {
        var results: [UploadResult] = []
        for picture in pending(eventID: eventID) {
            guard !Task.isCancelled else { break }
            let viewFile = view(picture.id)
            do {
                switch try await sender.send(picture, file: file(picture.id),
                                             view: fileManager.fileExists(atPath: viewFile.path) ? viewFile : nil) {
                case .stored:
                    try? removeFolder(picture.id)
                    results.append(.stored(picture))
                case .refused(let code):
                    try? removeFolder(picture.id)
                    results.append(.refused(picture, code))
                }
            } catch let error as PictureUploader.UploadError where error == .server(.unreachable) {
                break
            } catch {
                continue
            }
        }
        return results
    }
}
