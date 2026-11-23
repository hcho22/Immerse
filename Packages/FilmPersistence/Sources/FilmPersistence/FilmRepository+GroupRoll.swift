import FilmDomain
import Foundation

/// An event Roll's media on the phone that took it (v2 PRD V2-FR-34, V2-FR-36, V2-FR-50). Each refuses a personal Film,
/// so nothing here can ever reach one (V2-FR-72).
extension FilmRepository {
    private func requireEventRoll(_ filmID: UUID) throws {
        guard try filmAccess(filmID: filmID).isGroupRoll else { throw PersistenceError.notAnEventRoll }
    }

    /// Makes the local Film of a Roll taken in a Group Film, with the exposures the server already counts as used (a Roll
    /// shot on another iPhone, or before this phone kept its Film) marked used, so its numbering continues where the Roll
    /// is and never reuses an exposure (V2-FR-04, V2-FR-31, V2-FR-56).
    public func createEventRoll(
        eventID: String,
        camera: CameraPackage,
        title: String,
        filmStock: FilmStock?,
        exposuresUsed: Int,
        loadedAt: Date = Date()
    ) throws -> Film {
        var film = try Film(camera: camera, title: title, loadedAt: loadedAt, filmStock: filmStock)
        try film.recordUsedEventExposures(exposuresUsed, at: loadedAt)
        try database.withTransaction {
            try save(film)
            try database.setValue(filmID: film.id, key: "access", data: encoder.encode(FilmAccess.groupRoll(eventID: eventID)))
        }
        return film
    }

    /// Deletes a capture's original once Immerse's server has confirmed its developed picture whole (V2-FR-36). The
    /// capture keeps its place and, on the Instant, its developed print, which its shooter keeps seeing until the reveal
    /// (V2-FR-32). Repeating it does nothing.
    public func removeEventOriginal(filmID: UUID, sequenceNumber: Int) throws {
        try requireEventRoll(filmID)
        try database.withTransaction {
            guard let source = try database.asset(filmID: filmID, sequenceNumber: sequenceNumber, kind: .source) else { return }
            try database.enqueueDeletion(filmID: filmID, relativePath: source.relativePath)
            try database.deleteAsset(filmID: filmID, sequenceNumber: sequenceNumber, kind: .source)
        }
        try finishPendingDeletions(filmID: filmID)
    }

    /// Retires a capture of an event Roll: its original and its developed print are deleted, and it becomes a numbered
    /// placeholder whose exposure stays used. For Withdraw Before Reveal, the guest removed, the event deleted, the server
    /// refusing the picture, and an Instant print the reveal has taken into the album (V2-FR-32, V2-FR-50, V2-FR-53,
    /// V2-FR-55). Repeating it does nothing.
    public func retireEventCapture(filmID: UUID, sequenceNumber: Int) throws {
        try requireEventRoll(filmID)
        try database.withTransaction {
            var film = try film(id: filmID)
            guard let capture = film.captures.first(where: { $0.sequenceNumber == sequenceNumber }) else {
                throw PersistenceError.captureNotFound
            }
            if !capture.isDiscarded {
                try film.retireEventCapture(sequenceNumber: sequenceNumber)
                try save(film)
            }
            for kind in [StoredAsset.Kind.source, .master] {
                if let asset = try database.asset(filmID: filmID, sequenceNumber: sequenceNumber, kind: kind) {
                    try database.enqueueDeletion(filmID: filmID, relativePath: asset.relativePath)
                    try database.deleteAsset(filmID: filmID, sequenceNumber: sequenceNumber, kind: kind)
                }
            }
        }
        try finishPendingDeletions(filmID: filmID)
    }
}
