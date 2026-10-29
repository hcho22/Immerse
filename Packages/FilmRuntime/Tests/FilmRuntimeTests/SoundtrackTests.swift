@preconcurrency import AVFoundation
import FilmDomain
import FilmPersistence
import FilmRuntime
import Foundation
import NativeAdapters
import RenderCore
import RenderFixtures
import XCTest
@testable import MediaCatalog

final class SoundtrackTests: XCTestCase {
    func testNewLiveSoundFilmDefaultsToRecordedSoundThroughDevelopmentAndExport() async throws {
        try XCTSkipUnless(NativePhotoRenderer.readsFilmTables, "Core Image cannot run the tetrahedral reader here")
        let fixture = try await Fixture(withRecordedSound: true)
        defer { fixture.remove() }

        let movie = try fixture.repository.revealedAsset(filmID: fixture.film.id, sequenceNumber: 0, kind: .movie)
        let assembled = try await VerifiedMedia.movie(at: movie.url, allowsAudio: true)
        XCTAssertEqual(assembled.audioTrackCount, 1, "A new movie Film defaults to its recorded sound")
        for sequence in [1, 2] {
            let clip = try fixture.repository.revealedAsset(filmID: fixture.film.id, sequenceNumber: sequence, kind: .clip)
            let proof = try await VerifiedMedia.movie(at: clip.url, allowsAudio: true)
            XCTAssertEqual(proof.audioTrackCount, 1,
                           "Developed Clip \(sequence) keeps its captured sound")
        }

        let writer = DecodingWriter()
        try await fixture.processor.export(filmID: fixture.film.id, sequences: [1, 2], originals: false,
            coordinator: PhotoExportCoordinator(authorizer: Authorization(), writer: writer))
        let exportedTracks = await writer.audioTracks
        XCTAssertEqual(exportedTracks, [1], "The file handed to Photos carries the chosen recorded sound")
        // The export carries the sound in the format it was developed in, which is the format it was captured in
        // (DEC-19): what the iPhone records, compared, not a constant the fixture was made with.
        let exportedFormats = await writer.audioFormats
        let developedFormats = try await [1, 2].asyncMap { sequence in
            try await AudioFormat(of: fixture.repository.revealedAsset(filmID: fixture.film.id, sequenceNumber: sequence,
                                                                       kind: .clip).url)
        }
        XCTAssertEqual(Set(developedFormats).count, 1, "Both clips were developed in one sound format")
        XCTAssertEqual(exportedFormats, [developedFormats[0]], "The export keeps the developed sound's format")
    }

    func testRecordedSoundAndSilentCanChangeWithoutCatalogOrRedevelopment() async throws {
        try XCTSkipUnless(NativePhotoRenderer.readsFilmTables, "Core Image cannot run the tetrahedral reader here")
        let fixture = try await Fixture(withRecordedSound: true)
        defer { fixture.remove() }
        let repository = fixture.repository
        let id = fixture.film.id
        let run = try repository.developmentRun(filmID: id)
        let clips = try [1, 2].map { try repository.revealedAsset(filmID: id, sequenceNumber: $0, kind: .clip) }
        let clipBytes = try clips.map { try Data(contentsOf: $0.url) }
        let stages = StageLog()
        let processor = try FilmProcessor(root: fixture.root, developmentObserver: { _, stage in await stages.record(stage) })

        try await processor.selectMovieSound(filmID: id, choice: .silent, assetID: nil, catalog: nil)
        XCTAssertEqual(try repository.movieSoundChoice(filmID: id), .silent)
        var movie = try repository.revealedAsset(filmID: id, sequenceNumber: 0, kind: .movie)
        var proof = try await VerifiedMedia.movie(at: movie.url)
        XCTAssertEqual(proof.audioTrackCount, 0)

        try await processor.selectMovieSound(filmID: id, choice: .recordedSound, assetID: nil, catalog: nil)
        XCTAssertEqual(try repository.movieSoundChoice(filmID: id), .recordedSound)
        movie = try repository.revealedAsset(filmID: id, sequenceNumber: 0, kind: .movie)
        proof = try await VerifiedMedia.movie(at: movie.url, allowsAudio: true)
        XCTAssertEqual(proof.audioTrackCount, 1, "Recorded sound returns without another Development")
        XCTAssertEqual(try repository.developmentRun(filmID: id), run)
        XCTAssertEqual(try clips.map { try Data(contentsOf: $0.url) }, clipBytes)
        let rendered = await stages.rendered
        XCTAssertEqual(rendered, 0, "Switching sound choices reassembles unchanged Developed Clips")
    }

    func testLegacyMovieAudioSelectionStillReadsAsBefore() throws {
        let data = Data(#"{"revision":"0F6D1E2A-6C1B-4B8E-9C11-5A0E7E2B9D41","asset":null}"#.utf8)
        let legacy = try JSONDecoder().decode(MovieAudioSelection.self, from: data)
        XCTAssertNil(legacy.choice)
        XCTAssertEqual(legacy.effectiveChoice(recordsLiveSound: false), .silent)
    }

    func testSoundtrackSurvivesBundleRemovalAndDiscardWithoutRedevelopment() async throws {
        try XCTSkipUnless(NativePhotoRenderer.readsFilmTables, "Core Image cannot run the tetrahedral reader here")
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let repository = fixture.repository
        let filmID = fixture.film.id
        let oldMovie = try repository.revealedAsset(filmID: filmID, sequenceNumber: 0, kind: .movie)
        let clip = try repository.revealedAsset(filmID: filmID, sequenceNumber: 2, kind: .clip)
        let clipBytes = try Data(contentsOf: clip.url)
        let assignments = try repository.developmentRun(filmID: filmID)?.assignments
        try await fixture.processor.selectMovieSound(filmID: filmID, choice: .soundtrack, assetID: "tone",
                                                     catalog: fixture.catalog())
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
        try XCTSkipUnless(NativePhotoRenderer.readsFilmTables, "Core Image cannot run the tetrahedral reader here")
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let repository = fixture.repository
        let id = fixture.film.id
        try await fixture.processor.selectMovieSound(filmID: id, choice: .soundtrack, assetID: "tone", catalog: fixture.catalog())
        let old = try repository.revealedAsset(filmID: id, sequenceNumber: 0, kind: .movie)
        let oldData = try Data(contentsOf: old.url)
        let oldProof = try await VerifiedMedia.movie(at: old.url, allowsAudio: true)
        let revision = try XCTUnwrap(repository.movieAudioSelection(filmID: id)).revision
        let audio = try XCTUnwrap(repository.retainedSoundtrack(filmID: id))
        try repository.selectMovieSoundChoice(filmID: id, choice: .silent, asset: nil, verification: nil)
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

    /// A Movie's soundtrack can be changed later, any number of times, without developing again (DEC-11, the captain,
    /// 2026-10-13): each change assembles the Movie again from the same Developed Clips, and no clip is rendered.
    func testASoundtrackCanBeChangedLaterAnyNumberOfTimesWithoutDevelopingAgain() async throws {
        try XCTSkipUnless(NativePhotoRenderer.readsFilmTables, "Core Image cannot run the tetrahedral reader here")
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let repository = fixture.repository
        let id = fixture.film.id
        let run = try XCTUnwrap(repository.developmentRun(filmID: id))
        let clips = try [1, 2].map { try repository.revealedAsset(filmID: id, sequenceNumber: $0, kind: .clip) }
        let clipBytes = try clips.map { try Data(contentsOf: $0.url) }
        // A new processor, as after a relaunch, that records every stage Development reports.
        let stages = StageLog()
        let later = try FilmProcessor(root: fixture.root, developmentObserver: { _, stage in await stages.record(stage) })
        var revisions: Set<UUID> = []
        for (choice, assetID, tracks) in [(.soundtrack, "tone", 1), (.silent, nil, 0), (.soundtrack, "tone", 1),
                                          (.soundtrack, "tone", 1), (.silent, nil, 0)] as [(MovieSoundChoice, String?, Int)] {
            try await later.selectMovieSound(filmID: id, choice: choice, assetID: assetID, catalog: fixture.catalog())
            let selection = try XCTUnwrap(repository.movieAudioSelection(filmID: id))
            XCTAssertEqual(selection.choice, choice)
            XCTAssertEqual(selection.asset?.id, assetID)
            revisions.insert(selection.revision)
            let movie = try repository.revealedAsset(filmID: id, sequenceNumber: 0, kind: .movie)
            let proof = try await VerifiedMedia.movie(at: movie.url, allowsAudio: true)
            XCTAssertEqual(proof.audioTrackCount, tracks, "\(choice)")
            XCTAssertEqual(try XCTUnwrap(proof.durationSeconds), fixture.duration * 2, accuracy: 0.01)
            XCTAssertEqual(try [1, 2].map { try repository.revealedAsset(filmID: id, sequenceNumber: $0, kind: .clip).record }, clips.map(\.record))
            XCTAssertEqual(try clips.map { try Data(contentsOf: $0.url) }, clipBytes)
            XCTAssertEqual(try repository.developmentRun(filmID: id), run)
            XCTAssertEqual(try repository.film(id: id).developmentState, .developed)
        }
        // Choosing the soundtrack the Movie already has changes nothing, so four of the five choices were changes.
        XCTAssertEqual(revisions.count, 4)
        let rendered = await stages.rendered
        XCTAssertEqual(rendered, 0, "No clip was developed again")
    }

    func testDecodeFailuresPreserveSelectionAndPlayableMovie() async throws {
        try XCTSkipUnless(NativePhotoRenderer.readsFilmTables, "Core Image cannot run the tetrahedral reader here")
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let id = fixture.film.id
        let original = try fixture.repository.revealedAsset(filmID: id, sequenceNumber: 0, kind: .movie)
        let corrupt = Data("not audio".utf8)
        try corrupt.write(to: fixture.bundle.appendingPathComponent("tone.wav"))
        do {
            try await fixture.processor.selectMovieSound(filmID: id, choice: .soundtrack, assetID: "tone",
                                                         catalog: fixture.catalog(audio: corrupt))
            XCTFail("Integrity checks cannot substitute for actual media decode")
        } catch { }
        XCTAssertNil(try fixture.repository.movieAudioSelection(filmID: id))
        XCTAssertEqual(try fixture.repository.revealedAsset(filmID: id, sequenceNumber: 0, kind: .movie).record, original.record)
        try fixture.audio.write(to: fixture.bundle.appendingPathComponent("tone.wav"))
        try await fixture.processor.selectMovieSound(filmID: id, choice: .soundtrack, assetID: "tone", catalog: fixture.catalog())
        let selection = try fixture.repository.movieAudioSelection(filmID: id)
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

    private actor StageLog {
        private(set) var rendered = 0
        func record(_ stage: DevelopmentStage) {
            if case .afterRendering = stage { rendered += 1 }
        }
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

        init(withRecordedSound: Bool = false) async throws {
            root = FileManager.default.temporaryDirectory.appendingPathComponent("SoundtrackTests-\(UUID())")
            bundle = root.appendingPathComponent("TestBundle")
            try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
            audio = RecordedSound.wave()
            try audio.write(to: bundle.appendingPathComponent("tone.wav"))
            let capturedAudio = bundle.appendingPathComponent("tone.m4a")
            try await RecordedSound.encodeAAC(bundle.appendingPathComponent("tone.wav"), destination: capturedAudio)
            try license.write(to: bundle.appendingPathComponent("license.txt"))
            var settings = RenderFixtureSettings.defaultExperimental
            settings.movieWidth = 160; settings.movieHeight = 96; settings.movieDurationSeconds = 0.16
            let fixtures = root.appendingPathComponent("Fixtures")
            let manifest = try await RenderFixtureGenerator.writeFixtures(outputDirectory: fixtures, settings: settings)
            duration = manifest.movie.durationSeconds
            let sourceURL = fixtures.appendingPathComponent("synthetic-developed-movie.mov")
            let capturedURL = fixtures.appendingPathComponent("captured-with-sound.mov")
            if withRecordedSound { try await RecordedSound.addAudio(capturedAudio, to: sourceURL, destination: capturedURL) }
            let source = try Data(contentsOf: withRecordedSound ? capturedURL : sourceURL)
            repository = try FilmRepository(rootURL: root)
            film = try repository.createFilm(camera: CameraCatalog.cinema16mm, title: "Private audio test", movieOrientation: .portrait, filmStock: .color)
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

        func catalog(audio: Data? = nil) throws -> BundleMediaCatalog {
            let asset = CatalogMediaAsset(id: "tone", title: "Private test tone", cameraIDs: [.cinema16mm], purpose: .instrumental,
                kind: .audio, resourcePath: "tone.wav", sha256: BundleMediaCatalog.digest(audio ?? self.audio),
                rights: MediaRights(clearance: .syntheticTestOnly, creator: "Unit test", source: "Generated PCM",
                    acquiredAt: "2026-10-01", approvalReference: "Private fixture only", licensePath: "license.txt",
                    licenseSHA256: BundleMediaCatalog.digest(license), permitsBundling: true, permitsMovieExport: true,
                    attribution: "Test tone, not production soundtrack"))
            let manifest = MediaCatalogManifest(schemaVersion: 1, assets: [asset])
            return try BundleMediaCatalog(rootURL: bundle, manifestData: JSONEncoder().encode(manifest), allowSyntheticFixtures: true)
        }

        func remove() { try? FileManager.default.removeItem(at: root) }
    }
}

private struct Authorization: PhotoLibraryAuthorizing {
    func authorizationStatus(for accessLevel: PhotoLibraryAccessLevel) -> PhotoLibraryAuthorizationStatus { .authorized }
    func requestAuthorization(for accessLevel: PhotoLibraryAccessLevel) async -> PhotoLibraryAuthorizationStatus { .authorized }
}

private actor DecodingWriter: PhotoLibraryWriting {
    var audioTracks: [Int] = []
    var audioFormats: [AudioFormat] = []
    func write(_ request: PhotoExportRequest) async throws -> PhotoExportReceipt {
        let proof = try await VerifiedMedia.movie(at: request.fileURL, allowsAudio: true)
        audioTracks.append(proof.audioTrackCount)
        let asset = AVURLAsset(url: request.fileURL)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        if !tracks.isEmpty { audioFormats.append(try await AudioFormat(of: request.fileURL)) }
        return PhotoExportReceipt(localIdentifier: "private-test-\(audioTracks.count)")
    }
}

private struct AudioFormat: Hashable, Sendable {
    let codec: UInt32
    let sampleRate: Double
    let channels: UInt32

    /// The format of the first sound track of the movie at `url`.
    init(of url: URL) async throws {
        let tracks = try await AVURLAsset(url: url).loadTracks(withMediaType: .audio)
        let descriptions = try await XCTUnwrap(tracks.first).load(.formatDescriptions)
        let format = try XCTUnwrap(descriptions.first)
        let basic = try XCTUnwrap(CMAudioFormatDescriptionGetStreamBasicDescription(format)?.pointee)
        codec = CMFormatDescriptionGetMediaSubType(format)
        sampleRate = basic.mSampleRate
        channels = basic.mChannelsPerFrame
    }
}

private extension Array {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var result: [T] = []
        for element in self { result.append(try await transform(element)) }
        return result
    }
}
