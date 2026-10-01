import FilmDomain
import FilmPersistence
import Foundation
import ImageIO
import NativeAdapters
import RenderCore
import UniformTypeIdentifiers

public enum FilmExportError: Error, Equatable {
    case nothingToExport
    case needsPermission
    case permissionDenied
    case writeFailed(String)
    case missingReceipt
}

enum FilmExportWorker {
    static func export<Authorizer: PhotoLibraryAuthorizing, Writer: PhotoLibraryWriting>(
        root: URL, filmID: UUID, sequences: [Int], originals: Bool,
        coordinator: PhotoExportCoordinator<Authorizer, Writer>
    ) async throws {
        let repository = try FilmRepository(rootURL: root)
        let film = try repository.film(id: filmID)
        let selected = Array(Set(sequences)).sorted()
        guard !selected.isEmpty else { throw FilmExportError.nothingToExport }
        // Validate the entire requested selection before creating any external copy.
        for sequence in selected {
            guard film.captures.contains(where: { $0.sequenceNumber == sequence && $0.revealState == .revealed }) else {
                throw PersistenceError.mediaNotRevealed
            }
        }
        var work = root.appendingPathComponent("Work/\(filmID)/Export-\(UUID())")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        var resources = URLResourceValues(); resources.isExcludedFromBackup = true
        try work.setResourceValues(resources)
        defer { try? FileManager.default.removeItem(at: work) }
        let items = film.camera.medium == .movie && !originals ? [0] : selected
        for sequence in items {
            try Task.checkCancellation()
            let kind: StoredAsset.Kind = originals ? .source : (film.camera.medium == .movie ? .movie : .master)
            if originals, case .exported = try repository.originalDisposition(filmID: filmID, sequenceNumber: sequence) {
                continue
            }
            let asset = try repository.revealedAsset(filmID: filmID, sequenceNumber: sequence, kind: kind)
            let verification: VerifiedMedia
            if film.camera.medium == .photo { verification = try VerifiedMedia.photo(at: asset.url) }
            else { verification = try await VerifiedMedia.movie(at: asset.url, allowsAudio: !originals) }
            guard verification.sha256 == asset.record.sha256 else { throw PersistenceError.mediaChangedDuringVerification }
            let extensionName: String
            if film.camera.medium == .movie { extensionName = "mov" }
            else if originals {
                guard let image = CGImageSourceCreateWithURL(asset.url as CFURL, nil),
                      let type = CGImageSourceGetType(image), let suffix = UTType(type as String)?.preferredFilenameExtension else {
                    throw PersistenceError.invalidMedia
                }
                extensionName = suffix
            } else { extensionName = "jpg" }
            let file = work.appendingPathComponent("\(sequence).\(extensionName)")
            if !originals && film.camera.medium == .photo {
                let recipe = try repository.darkroomRecipe(filmID: filmID, sequence: sequence)
                let data = try NativePhotoRenderer.print(master: Data(contentsOf: asset.url), recipe: recipe, camera: film.camera,
                    process: repository.photoPrintProcess(filmID: filmID))
                try data.write(to: file, options: .atomic)
                _ = try VerifiedMedia.photo(at: file)
            } else {
                try FileManager.default.copyItem(at: asset.url, to: file)
                let copied: VerifiedMedia
                if film.camera.medium == .photo { copied = try VerifiedMedia.photo(at: file) }
                else { copied = try await VerifiedMedia.movie(at: file, allowsAudio: !originals) }
                guard copied.sha256 == asset.record.sha256 else { throw PersistenceError.mediaChangedDuringVerification }
            }
            if originals { try repository.chooseOriginalExport(filmID: filmID, sequenceNumber: sequence, export: true) }
            try Task.checkCancellation()
            let outcome = await coordinator.export(PhotoExportRequest(fileURL: file, mediaKind: film.camera.medium == .photo ? .photo : .movie))
            switch outcome {
            case let .exported(receipt):
                guard let identifier = receipt.localIdentifier, !identifier.isEmpty else { throw FilmExportError.missingReceipt }
                if originals {
                    try repository.recordSuccessfulOriginalExport(filmID: filmID, sequenceNumber: sequence,
                        sourceSHA256: asset.record.sha256, photosIdentifier: identifier)
                }
            case .needsPermission: throw FilmExportError.needsPermission
            case .permissionDenied: throw FilmExportError.permissionDenied
            case let .writeFailed(message): throw FilmExportError.writeFailed(message)
            }
        }
        if originals { try await DevelopmentWorker.cleanup(root: root, filmID: filmID) }
    }
}
