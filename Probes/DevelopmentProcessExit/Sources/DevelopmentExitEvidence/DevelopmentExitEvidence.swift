import FilmDomain
import FilmPersistence
import FilmRuntime
import Foundation
import RenderCore
import RenderFixtures

public enum ExitBoundary: String, CaseIterable, Codable, Sendable {
    case beforeBegin, afterAssignments, afterRendering, afterPersistence, beforeReveal, beforeCleanup

    public func stage(camera: CameraID, sequence: Int = 1) -> DevelopmentStage {
        switch self {
        case .beforeBegin: .beforeBegin
        case .afterAssignments: .afterAssignments
        case .afterRendering: .afterRendering(sequence: sequence)
        case .afterPersistence: .afterPersistence(sequence: sequence)
        case .beforeReveal: .beforeRevealOrCleanup(camera == .instant1970s ? .instantReveal(sequence: sequence) : .filmReveal)
        case .beforeCleanup: .beforeRevealOrCleanup(.sourceCleanup)
        }
    }
}

public struct DevelopmentExitSnapshot: Codable, Sendable {
    public let film: Film
    public let run: DevelopmentRun?
    public let assets: [String: String]
    public let privateFiles: [String]
    public let process: Int32

    public static func read(root: URL, filmID: UUID) async throws -> Self {
        let repository = try FilmRepository(rootURL: root)
        let film = try repository.film(id: filmID)
        var assets: [String: String] = [:]
        for sequence in 0...film.captures.count {
            for kind in [StoredAsset.Kind.source, .master, .clip, .movie] {
                guard let asset = try repository.mediaAsset(filmID: filmID, sequenceNumber: sequence, kind: kind) else { continue }
                let verification = film.camera.medium == .photo ? try VerifiedMedia.photo(at: asset.url)
                    : try await VerifiedMedia.movie(at: asset.url)
                guard verification.sha256 == asset.record.sha256, verification.decodedFrameCount > 0 else {
                    throw PersistenceError.mediaChangedDuringVerification
                }
                assets["\(kind.rawValue)-\(sequence)"] = verification.sha256
            }
        }
        return Self(film: film, run: try repository.developmentRun(filmID: filmID), assets: assets,
                    privateFiles: try files(root), process: ProcessInfo.processInfo.processIdentifier)
    }

    private static func files(_ root: URL) throws -> [String] {
        guard let iterator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey]) else { return [] }
        var paths: [String] = []
        for case let url as URL in iterator where try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
            paths.append(String(url.path.dropFirst(root.path.count + 1)))
        }
        return paths.sorted()
    }

    public func persist(to url: URL) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: url, options: .withoutOverwriting)
        let file = try FileHandle(forWritingTo: url)
        defer { try? file.close() }
        try file.synchronize()
    }
}
