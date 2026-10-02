import FilmDomain
import FilmPersistence
import FilmRuntime
import Foundation
import NativeAdapters
import RenderFixtures
import XCTest
@testable import MediaCatalog

final class SoundtrackTests: XCTestCase {
    func testSoundtrackSurvivesBundleRemovalAndDiscardWithoutRedevelopment() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let repository = fixture.repository
        let filmID = fixture.film.id
        let oldMovie = try repository.revealedAsset(filmID: filmID, sequenceNumber: 0, kind: .movie)
        let clip = try repository.revealedAsset(filmID: filmID, sequenceNumber: 2, kind: .clip)
        let clipBytes = try Data(contentsOf: clip.url)
        let assignments = try repository.developmentRun(filmID: filmID)?.assignments
        try await fixture.processor.selectSoundtrack(filmID: filmID, assetID: "tone", catalog: fixture.catalog())
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldMovie.url.path))
        let movie = try repository.revealedAsset(filmID: filmID, sequenceNumber: 0, kind: .movie)
        let verified = try await VerifiedMedia.movie(at: movie.url, allowsAudio: true)
        XCTAssertEqual(verified.audioTrackCount, 1)
        XCTAssertEqual(try XCTUnwrap(verified.durationSeconds), fixture.duration * 2, accuracy: 0.01)
        XCTAssertEqual(try Data(contentsOf: clip.url), clipBytes)
        XCTAssertEqual(try repository.developmentRun(filmID: filmID)?.assignments, assignments)
        let writer = DecodingWriter()
        try await fixture.processor.export(filmID: filmID, sequences: [1, 2], originals: false,
            coordinator: PhotoExportCoordinator(authorizer: Authorization(), writer: writer))
        let exported = await writer.audioTracks
        XCTAssertEqual(exported, [1])
        XCTAssertNil(try repository.originalDisposition(filmID: filmID, sequenceNumber: 1))

        try FileManager.default.removeItem(at: fixture.bundle)
        let reopened = try FilmProcessor(root: fixture.root)
        try await reopened.discard(filmID: filmID, sequence: 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: movie.url.path))
        let shorter = try repository.revealedAsset(filmID: filmID, sequenceNumber: 0, kind: .movie)
        let proof = try await VerifiedMedia.movie(at: shorter.url, allowsAudio: true)
        XCTAssertEqual(proof.audioTrackCount, 1)
        XCTAssertEqual(try XCTUnwrap(proof.durationSeconds), fixture.duration, accuracy: 0.01)
        XCTAssertEqual(try Data(contentsOf: clip.url), clipBytes)
        XCTAssertEqual(try repository.developmentRun(filmID: filmID)?.assignments, assignments)
        XCTAssertNotNil(try repository.retainedSoundtrack(filmID: filmID))
        try await reopened.discard(filmID: filmID, sequence: 2)
        XCTAssertEqual(try repository.film(id: filmID).discardedPlaceholderSequenceNumbers, [1, 2])
        XCTAssertFalse(try repository.film(id: filmID).canPlaybackDevelopedMovie)
        XCTAssertThrowsError(try repository.revealedAsset(filmID: filmID, sequenceNumber: 0, kind: .movie))
        try await reopened.deleteFilm(filmID: filmID)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.root.appendingPathComponent("Media/\(filmID)").path))
    }

    func testAudioChangeRetiresOldMovieAndRejectsStaleRenderBeforeResumingSilence() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let repository = fixture.repository
        let id = fixture.film.id
        try await fixture.processor.selectSoundtrack(filmID: id, assetID: "tone", catalog: fixture.catalog())
        let old = try repository.revealedAsset(filmID: id, sequenceNumber: 0, kind: .movie)
        let oldData = try Data(contentsOf: old.url)
        let oldProof = try await VerifiedMedia.movie(at: old.url, allowsAudio: true)
        let revision = try XCTUnwrap(repository.movieAudioSelection(filmID: id)).revision
        let audio = try XCTUnwrap(repository.retainedSoundtrack(filmID: id))
        try repository.selectMovieSoundtrack(filmID: id, asset: nil, verification: nil, reselectionPolicy: .allowed)
        XCTAssertFalse(FileManager.default.fileExists(atPath: old.url.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: audio.url.path))
        XCTAssertThrowsError(try repository.writeAssembledMovie(filmID: id, data: oldData,
            clipSequenceNumbers: [1, 2], verification: oldProof, soundtrackRevision: revision)) {
            XCTAssertEqual($0 as? PersistenceError, .soundtrackChanged)
        }
        XCTAssertNil(try repository.mediaAsset(filmID: id, sequenceNumber: 0, kind: .movie))
        let reopened = try FilmProcessor(root: fixture.root)
        try await reopened.develop(filmID: id)
        let silent = try repository.revealedAsset(filmID: id, sequenceNumber: 0, kind: .movie)
        let proof = try await VerifiedMedia.movie(at: silent.url)
        XCTAssertEqual(proof.audioTrackCount, 0)
        XCTAssertNil(try repository.retainedSoundtrack(filmID: id))
    }

    func testPolicyAndDecodeFailuresPreserveSelectionAndPlayableMovie() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let id = fixture.film.id
        let original = try fixture.repository.revealedAsset(filmID: id, sequenceNumber: 0, kind: .movie)
        do {
            try await fixture.processor.selectSoundtrack(filmID: id, assetID: "tone", catalog: fixture.catalog(policy: nil))
            XCTFail("An unresolved reselection policy must not be invented")
        } catch MediaCatalogError.invalidManifest { }
        let corrupt = Data("not audio".utf8)
        try corrupt.write(to: fixture.bundle.appendingPathComponent("tone.wav"))
        do {
            try await fixture.processor.selectSoundtrack(filmID: id, assetID: "tone", catalog: fixture.catalog(audio: corrupt))
            XCTFail("Integrity checks cannot substitute for actual media decode")
        } catch { }
        XCTAssertNil(try fixture.repository.movieAudioSelection(filmID: id))
        XCTAssertEqual(try fixture.repository.revealedAsset(filmID: id, sequenceNumber: 0, kind: .movie).record, original.record)
        try fixture.audio.write(to: fixture.bundle.appendingPathComponent("tone.wav"))
        let locked = try fixture.catalog(policy: .initialChoiceOnly)
        try await fixture.processor.selectSoundtrack(filmID: id, assetID: "tone", catalog: locked)
        let selection = try fixture.repository.movieAudioSelection(filmID: id)
        do {
            try await fixture.processor.selectSoundtrack(filmID: id, assetID: nil, catalog: locked)
            XCTFail("A locked choice cannot be changed")
        } catch PersistenceError.soundtrackSelectionLocked { }
        XCTAssertEqual(try fixture.repository.movieAudioSelection(filmID: id), selection)
        let retained = try XCTUnwrap(fixture.repository.retainedSoundtrack(filmID: id))
        try Data("damage after selection".utf8).write(to: retained.url)
        do { try await fixture.processor.develop(filmID: id); XCTFail("Damaged retained audio must fail closed") }
        catch { }
        XCTAssertEqual(try fixture.repository.movieAudioSelection(filmID: id), selection)
        try fixture.audio.write(to: retained.url)
        try FileManager.default.removeItem(at: fixture.bundle)
        try await FilmProcessor(root: fixture.root).develop(filmID: id)
        let movie = try fixture.repository.revealedAsset(filmID: id, sequenceNumber: 0, kind: .movie)
        let proof = try await VerifiedMedia.movie(at: movie.url, allowsAudio: true)
        XCTAssertEqual(proof.audioTrackCount, 1)
    }

    private struct Fixture {
        let root: URL
        let bundle: URL
        let audio: Data
        let license = Data("Generated sine wave for private automated testing only.".utf8)
        let repository: FilmRepository
        let processor: FilmProcessor
        let film: Film
        let duration: Double

        init() async throws {
            root = FileManager.default.temporaryDirectory.appendingPathComponent("SoundtrackTests-\(UUID())")
            bundle = root.appendingPathComponent("TestBundle")
            try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
            audio = Self.wave()
            try audio.write(to: bundle.appendingPathComponent("tone.wav"))
            try license.write(to: bundle.appendingPathComponent("license.txt"))
            var settings = RenderFixtureSettings.defaultExperimental
            settings.movieWidth = 160; settings.movieHeight = 96; settings.movieDurationSeconds = 0.16
            let fixtures = root.appendingPathComponent("Fixtures")
            let manifest = try await RenderFixtureGenerator.writeFixtures(outputDirectory: fixtures, settings: settings)
            duration = manifest.movie.durationSeconds
            let source = try Data(contentsOf: fixtures.appendingPathComponent("synthetic-developed-movie.mov"))
            repository = try FilmRepository(rootURL: root)
            film = try repository.createFilm(camera: CameraCatalog.cinema16mm, title: "Private audio test", movieOrientation: .portrait)
            for _ in 0..<2 {
                try repository.saveMovieClip(filmID: film.id, sourceData: source, durationSeconds: duration, orientation: .landscape)
            }
            try repository.completeEarly(filmID: film.id)
            processor = try FilmProcessor(root: root)
            try await processor.develop(filmID: film.id)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let identity = [
                "filmID": film.id.uuidString,
                "sourceSHA256": BundleMediaCatalog.digest(source),
                "audioSHA256": BundleMediaCatalog.digest(audio),
                "licenseSHA256": BundleMediaCatalog.digest(license),
                "generatorManifest": String(decoding: try encoder.encode(manifest), as: UTF8.self),
                "developmentRun": String(decoding: try encoder.encode(repository.developmentRun(filmID: film.id)), as: UTF8.self)
            ]
            print("SOUNDTRACK_FIXTURE " + String(decoding: try encoder.encode(identity), as: UTF8.self))
        }

        func catalog(policy: SoundtrackReselectionPolicy? = .allowed, audio: Data? = nil) throws -> BundleMediaCatalog {
            let asset = CatalogMediaAsset(id: "tone", title: "Private test tone", cameraIDs: [.cinema16mm], purpose: .instrumental,
                kind: .audio, resourcePath: "tone.wav", sha256: BundleMediaCatalog.digest(audio ?? self.audio),
                rights: MediaRights(clearance: .syntheticTestOnly, creator: "Unit test", source: "Generated PCM",
                    acquiredAt: "2026-10-01", approvalReference: "Private fixture only", licensePath: "license.txt",
                    licenseSHA256: BundleMediaCatalog.digest(license), permitsBundling: true, permitsMovieExport: true,
                    attribution: "Test tone, not production soundtrack"))
            let manifest = MediaCatalogManifest(schemaVersion: 1, soundtrackReselection: policy, assets: [asset])
            return try BundleMediaCatalog(rootURL: bundle, manifestData: JSONEncoder().encode(manifest), allowSyntheticFixtures: true)
        }

        func remove() { try? FileManager.default.removeItem(at: root) }

        static func wave() -> Data {
            let rate: UInt32 = 22_050
            let samples = Int(rate / 10)
            var bytes = Data()
            func text(_ value: String) { bytes.append(contentsOf: value.utf8) }
            func integer<T: FixedWidthInteger>(_ value: T) {
                var little = value.littleEndian
                withUnsafeBytes(of: &little) { bytes.append(contentsOf: $0) }
            }
            text("RIFF"); integer(UInt32(36 + samples * 2)); text("WAVEfmt ")
            integer(UInt32(16)); integer(UInt16(1)); integer(UInt16(1)); integer(rate)
            integer(rate * 2); integer(UInt16(2)); integer(UInt16(16)); text("data"); integer(UInt32(samples * 2))
            for sample in 0..<samples {
                integer(Int16(sin(Double(sample) * 2 * .pi * 440 / Double(rate)) * 4_000))
            }
            return bytes
        }
    }
}

private struct Authorization: PhotoLibraryAuthorizing {
    func authorizationStatus(for accessLevel: PhotoLibraryAccessLevel) -> PhotoLibraryAuthorizationStatus { .authorized }
    func requestAuthorization(for accessLevel: PhotoLibraryAccessLevel) async -> PhotoLibraryAuthorizationStatus { .authorized }
}

private actor DecodingWriter: PhotoLibraryWriting {
    var audioTracks: [Int] = []
    func write(_ request: PhotoExportRequest) async throws -> PhotoExportReceipt {
        let proof = try await VerifiedMedia.movie(at: request.fileURL, allowsAudio: true)
        audioTracks.append(proof.audioTrackCount)
        return PhotoExportReceipt(localIdentifier: "private-test-\(audioTracks.count)")
    }
}
