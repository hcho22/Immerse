import FilmDomain
import Foundation
import RenderCore

extension FilmRepository {
    public func allFilms() throws -> [Film] {
        try database.allFilmData().map { try decoder.decode(Film.self, from: $0) }
            .sorted { $0.loadedAt > $1.loadedAt }
    }

    public func rename(filmID: UUID, title: String) throws {
        try database.withTransaction {
            var film = try film(id: filmID)
            film.rename(to: title)
            try save(film)
        }
    }

    public func setArchived(filmID: UUID, archived: Bool) throws {
        try database.withTransaction {
            var film = try film(id: filmID)
            film.setArchived(archived)
            try save(film)
        }
    }

    public func beginDevelopment(filmID: UUID) throws -> DevelopmentRun {
        try database.withTransaction {
            var film = try film(id: filmID)
            if film.camera.revealRule != .instantPerExposure, film.developmentState == .notStarted {
                try film.startDevelopment()
                try save(film)
            }
            var run = try developmentRun(filmID: filmID) ?? DevelopmentRun(filmID: filmID)
            if !run.isComplete || film.captures.contains(where: { run.assignments[$0.sequenceNumber] == nil }) {
                try run.assignMissingTreatments(for: film)
                try database.setValue(filmID: filmID, key: "development", data: encoder.encode(run))
            }
            return run
        }
    }

    public func developmentRun(filmID: UUID) throws -> DevelopmentRun? {
        guard let data = try database.value(filmID: filmID, key: "development") else { return nil }
        return try decoder.decode(DevelopmentRun.self, from: data)
    }

    @discardableResult
    public func finishVerifiedDevelopment(filmID: UUID, verifiedMedia: [VerifiedMedia], instantSequence: Int? = nil) throws -> Film {
        try database.withTransaction {
            var film = try film(id: filmID)
            guard var run = try developmentRun(filmID: filmID) else { throw FilmDomainError.developmentNotInProgress }
            let sequences: [Int]
            if film.camera.revealRule == .instantPerExposure {
                guard let instantSequence, film.captures.contains(where: { $0.sequenceNumber == instantSequence && !$0.isDiscarded }) else {
                    throw PersistenceError.captureNotFound
                }
                sequences = [instantSequence]
            } else {
                guard instantSequence == nil else { throw FilmDomainError.wrongCameraMedium }
                sequences = film.captures.filter { !$0.isDiscarded }.map(\.sequenceNumber)
            }
            let kind: StoredAsset.Kind = film.camera.medium == .photo ? .master : .clip
            for sequence in sequences {
                try verifyAsset(filmID: filmID, sequence: sequence, kind: kind, evidence: verifiedMedia)
                try run.markRendered(sequenceNumber: sequence, in: film)
            }
            if film.camera.medium == .movie {
                try verifyAsset(filmID: filmID, sequence: 0, kind: .movie, evidence: verifiedMedia)
            }
            if let instantSequence {
                try film.revealInstantPrint(sequenceNumber: instantSequence)
            } else if film.developmentState != .developed {
                try film.finishDevelopment()
            }
            try database.setValue(filmID: filmID, key: "development", data: encoder.encode(run))
            try save(film)
            return film
        }
    }

    public func darkroomRecipe(filmID: UUID, sequence: Int) throws -> DarkroomRecipe {
        _ = try revealedAsset(filmID: filmID, sequenceNumber: sequence, kind: .master)
        guard let data = try database.value(filmID: filmID, key: "recipe-\(sequence)") else { return .original }
        return try decoder.decode(DarkroomRecipe.self, from: data)
    }

    public func saveDarkroomRecipe(filmID: UUID, sequence: Int, recipe: DarkroomRecipe) throws {
        try database.withTransaction {
            let film = try film(id: filmID)
            guard film.camera.medium == .photo else { throw FilmDomainError.wrongCameraMedium }
            _ = try revealedAsset(filmID: filmID, sequenceNumber: sequence, kind: .master)
            try NativePhotoRenderer.validate(recipe, camera: film.camera, process: photoPrintProcess(filmID: filmID))
            try database.setValue(filmID: filmID, key: "recipe-\(sequence)", data: encoder.encode(recipe))
        }
    }

    public func photoPrintProcess(filmID: UUID) throws -> PhotoPrintProcess {
        let film = try film(id: filmID)
        guard film.camera.medium == .photo else { throw FilmDomainError.wrongCameraMedium }
        return try developmentRun(filmID: filmID)?.printProcess ?? .color
    }

    private func verifyAsset(filmID: UUID, sequence: Int, kind: StoredAsset.Kind, evidence: [VerifiedMedia]) throws {
        guard let asset = try mediaAsset(filmID: filmID, sequenceNumber: sequence, kind: kind) else {
            throw PersistenceError.missingVerifiedMaster
        }
        guard evidence.contains(where: { $0.sha256 == asset.record.sha256 && $0.kind == (kind == .master ? .photo : .movie) }),
              try Checksum.sha256Hex(contentsOf: asset.url) == asset.record.sha256 else { throw PersistenceError.invalidMedia }
    }
}
