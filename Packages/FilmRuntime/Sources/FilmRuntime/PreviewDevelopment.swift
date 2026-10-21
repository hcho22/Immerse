#if DEBUG
import FilmDomain
import FilmPersistence
import Foundation
import RenderCore

/// Debug builds only: one saved capture of an unfinished Film developed now, for the captain to judge a Camera's look
/// without finishing the roll (the captain, 2026-10-21). It renders through Development's own code (`CaptureDevelopment`)
/// with the treatment Development will assign the capture, so a preview is what the roll's Development makes of it.
/// It only reads: the Film, its development record and the capture's source are left exactly as they were, the capture
/// stays sealed, and the preview is written only to `directory`, a disposable cache outside the Film's store. The whole
/// type is compiled out of Release; `Scripts/verify-release-excludes-testing-unlock.sh` checks the Release binary.
public enum PreviewDevelopment {
    /// Develops saved capture `sequenceNumber` of the Film at `root` into `directory`, replacing an earlier preview of
    /// it, and returns the file: a JPEG for a photo, a silent `.mov` Developed Clip for a Movie's clip. An Instant print
    /// develops by itself when it is saved, so an Instant Film has no preview.
    public static func render(root: URL, filmID: UUID, sequenceNumber: Int, directory: URL) async throws -> URL {
        let repository = try FilmRepository(rootURL: root)
        let film = try repository.film(id: filmID)
        guard film.camera.revealRule != .instantPerExposure else { throw FilmDomainError.wrongCameraMedium }
        guard film.captures.contains(where: { $0.sequenceNumber == sequenceNumber && !$0.isDiscarded }),
              let source = try repository.mediaAsset(filmID: filmID, sequenceNumber: sequenceNumber, kind: .source) else {
            throw PersistenceError.captureNotFound
        }
        // A capture already assigned a treatment keeps it; any other gets the one Development will give it.
        let run = try repository.developmentRun(filmID: filmID) ?? DevelopmentRun(film: film)
        let treatment = run.assignments[sequenceNumber]
            ?? DevelopmentRun.plannedAssignment(film: film, sequenceNumber: sequenceNumber)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var cache = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try cache.setResourceValues(values)
        let name = "\(filmID.uuidString)-\(sequenceNumber)"
        if film.camera.medium == .photo {
            let output = directory.appendingPathComponent("\(name).jpg")
            let data = try CaptureDevelopment.master(source: source.url, film: film, treatment: treatment, run: run)
            try Task.checkCancellation()
            try data.write(to: output, options: .atomic)
            return output
        }
        let output = directory.appendingPathComponent("\(name).mov")
        // The writer refuses a file that is already there.
        try FileManager.default.removeItemIfPresent(at: output)
        do {
            try await CaptureDevelopment.clip(source: source.url, destination: output, film: film, treatment: treatment,
                                              run: run)
        } catch {
            try? FileManager.default.removeItemIfPresent(at: output)
            throw error
        }
        return output
    }
}
#endif
