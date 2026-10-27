@preconcurrency import AVFoundation
import FilmDomain
import Foundation
import NativeAdapters
import RenderFixtures
import XCTest

final class CapturedMediaFileTests: XCTestCase {
    func testRecoveryAcceptsOneRecordedSoundTrackOnlyForANewMovieFilm() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let manifest = try await fixtures(at: root)
        let video = root.appendingPathComponent(manifest.movie.relativePath)
        let wave = root.appendingPathComponent("captured-sound.wav")
        try Self.wave().write(to: wave)
        let captured = root.appendingPathComponent("captured-with-sound.mov")
        try await Self.addAudio(wave, to: video, destination: captured)

        let soundFiles = try CapturedMediaFiles(directory: root.appendingPathComponent("new-film-staging"))
        let soundID = UUID()
        try soundFiles.prepare(PendingCaptureRecord(id: soundID, mediaKind: .movie,
            orientation: .portrait, remainingFrames: 6_000, allowsAudio: true))
        try FileManager.default.copyItem(at: captured, to: soundFiles.movieDestination(id: soundID))
        let recovered = try await soundFiles.recoveryEvents()
        XCTAssertEqual(recovered.count, 1,
                       "A new sound-capable Film recovers its one captured sound track")

        let silentFiles = try CapturedMediaFiles(directory: root.appendingPathComponent("earlier-film-staging"))
        let silentID = UUID()
        try silentFiles.prepare(PendingCaptureRecord(id: silentID, mediaKind: .movie,
            orientation: .portrait, remainingFrames: 6_000, allowsAudio: false))
        try FileManager.default.copyItem(at: captured, to: silentFiles.movieDestination(id: silentID))
        do {
            _ = try await silentFiles.recoveryEvents()
            XCTFail("An earlier Film's staging record must refuse newly added sound")
        } catch { }
        XCTAssertEqual(try silentFiles.pendingRecords().map(\.id), [silentID], "Rejected media remains pending")
    }

    func testReopenedJournalRecoversPhotoAndMovieInCaptureOrderUntilAcknowledged() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let manifest = try await fixtures(at: root)
        let staging = root.appendingPathComponent("staging")
        let files = try CapturedMediaFiles(directory: staging)
        let photoID = UUID(), movieID = UUID(), unusedID = UUID()
        let date = Date(timeIntervalSince1970: 1_000)
        try files.prepare(PendingCaptureRecord(id: photoID, mediaKind: .photo, createdAt: date))
        let data = try Data(contentsOf: root.appendingPathComponent(manifest.photo.relativePath))
        let photo = try files.savePhoto(data, id: photoID)
        try files.prepare(PendingCaptureRecord(id: movieID, mediaKind: .movie, createdAt: date.addingTimeInterval(1),
            orientation: .portrait, remainingFrames: 300))
        try FileManager.default.copyItem(at: root.appendingPathComponent(manifest.movie.relativePath), to: files.movieDestination(id: movieID))
        try files.prepare(PendingCaptureRecord(id: unusedID, mediaKind: .photo, createdAt: date.addingTimeInterval(2)))
        let reopened = try CapturedMediaFiles(directory: staging)
        let recovered = try await reopened.recoveryEvents()
        XCTAssertEqual(recovered.count, 2)
        XCTAssertEqual(recovered.first, .photoSaved(photo))
        if case let .movieClipSaved(_, seconds, orientation) = recovered.last {
            XCTAssertEqual(seconds, manifest.movie.durationSeconds)
            XCTAssertEqual(orientation, .portrait)
        } else { XCTFail("Expected recovered Movie") }
        XCTAssertEqual(try CapturedMediaFiles.metadata(for: photo)?.createdAt, date)
        XCTAssertEqual(try reopened.pendingRecords().count, 2)
        XCTAssertEqual(try Data(contentsOf: photo), data)
        for event in recovered { try reopened.removeCommittedFile(for: event) }
        XCTAssertTrue(try reopened.pendingRecords().isEmpty)
        let retry = try await reopened.recoveryEvents()
        XCTAssertTrue(retry.isEmpty)
    }

    func testInvalidPendingMovieIsRetainedAndBlocksSuccessfulRecovery() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let files = try CapturedMediaFiles(directory: root)
        let id = UUID()
        try files.prepare(PendingCaptureRecord(id: id, mediaKind: .movie, orientation: .landscape, remainingFrames: 6_000))
        let data = Data("unfinished movie".utf8)
        try data.write(to: files.movieDestination(id: id))
        do { _ = try await files.recoveryEvents(); XCTFail("Must not acknowledge undecodable media") }
        catch { }
        XCTAssertEqual(try files.pendingRecords().count, 1)
        XCTAssertEqual(try Data(contentsOf: files.movieDestination(id: id)), data)
    }

    func testRealPhotoBytesAreRetainedUnchangedUntilCommitCleanup() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let manifest = try await fixtures(at: root)
        let data = try Data(contentsOf: root.appendingPathComponent(manifest.photo.relativePath))
        let staging = root.appendingPathComponent("staging")
        let files = try CapturedMediaFiles(directory: staging)
        let id = UUID()
        let saved = try files.savePhoto(data, id: id)
        XCTAssertEqual(try Data(contentsOf: saved), data)
        XCTAssertThrowsError(try files.savePhoto(data, id: id))
        XCTAssertEqual(try Data(contentsOf: saved), data)
        XCTAssertEqual(try staging.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, false)
        try files.removeCommittedFile(for: .photoSaved(saved))
        XCTAssertFalse(FileManager.default.fileExists(atPath: saved.path))
    }

    func testPhotoInterruptedMidWriteNeverBlocksRecoveryOrBecomesASavedCapture() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let manifest = try await fixtures(at: root)
        let data = try Data(contentsOf: root.appendingPathComponent(manifest.photo.relativePath))
        let files = try CapturedMediaFiles(directory: root.appendingPathComponent("staging"))
        let interrupted = UUID(), saved = UUID()
        try files.prepare(PendingCaptureRecord(id: interrupted, mediaKind: .photo))
        // What a process killed during the write leaves behind: a truncated partial file.
        let partial = root.appendingPathComponent("staging/\(interrupted.uuidString).photo.partial")
        try data.prefix(data.count / 2).write(to: partial)
        let photo = try files.savePhoto(data, id: saved)
        XCTAssertEqual(try Data(contentsOf: photo), data)

        let recovered = try await files.recoveryEvents()
        XCTAssertEqual(recovered, [.photoSaved(photo)])
        XCTAssertFalse(FileManager.default.fileExists(atPath: partial.path))
        XCTAssertEqual(try files.pendingRecords().map(\.id), [saved])
    }

    func testMalformedPhotoCannotBecomeASavedCapture() throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let files = try CapturedMediaFiles(directory: root)
        XCTAssertThrowsError(try files.savePhoto(Data("not-an-image".utf8), id: UUID()))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }

    func testMissingStagingDirectoryBehavesAsAlreadyEmptyDuringPrivacyCleanup() async throws {
        let root = makeRoot()
        let files = try CapturedMediaFiles(directory: root)
        try FileManager.default.removeItem(at: root)

        XCTAssertTrue(try files.pendingRecords().isEmpty)
        let recovery = try await files.recoveryEvents()
        XCTAssertTrue(recovery.isEmpty)
        try files.removeUncommitted(id: UUID())
        try files.removeCommittedFile(for: .photoSaved(root.appendingPathComponent("missing.photo")))
    }

    func testExistingUninspectableStagingPathStillThrowsInsteadOfPretendingEmpty() throws {
        let root = makeRoot()
        let files = try CapturedMediaFiles(directory: root)
        try FileManager.default.removeItem(at: root)
        try Data("not a staging directory".utf8).write(to: root, options: .withoutOverwriting)
        defer { try? FileManager.default.removeItem(at: root) }

        XCTAssertThrowsError(try files.pendingRecords())
    }

    func testExistingStagingDirectoryThatCannotBeInspectedIsNeitherEmptyNorRemoved() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let manifest = try await fixtures(at: root)
        let data = try Data(contentsOf: root.appendingPathComponent(manifest.photo.relativePath))
        let parent = root.appendingPathComponent("Staging")
        let files = try CapturedMediaFiles(directory: parent.appendingPathComponent("film"))
        let id = UUID()
        let photo = try files.savePhoto(data, id: id)
        // The staging directory still exists; its parent denies search, so presence cannot be confirmed.
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: parent.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: parent.path) }

        XCTAssertThrowsError(try files.pendingRecords()) {
            XCTAssertEqual(($0 as? CocoaError)?.code, .fileReadNoPermission)
        }
        do { _ = try await files.recoveryEvents(); XCTFail("Uninspectable staging must not recover as empty") }
        catch { XCTAssertEqual((error as? CocoaError)?.code, .fileReadNoPermission) }
        XCTAssertThrowsError(try files.removeUncommitted(id: id)) {
            XCTAssertEqual(($0 as? CocoaError)?.code, .fileWriteNoPermission)
        }
        XCTAssertThrowsError(try files.removeCommittedFile(for: .photoSaved(photo))) {
            XCTAssertEqual(($0 as? CocoaError)?.code, .fileWriteNoPermission)
        }

        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: parent.path)
        XCTAssertEqual(try files.pendingRecords().map(\.id), [id])
        XCTAssertEqual(try Data(contentsOf: photo), data)
    }

    func testCommittedCleanupRejectsOutsideStagingFilesAndLeavesThemUntouched() throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let staging = root.appendingPathComponent("staging")
        let files = try CapturedMediaFiles(directory: staging)
        let outside = root.appendingPathComponent("outside.photo")
        let bytes = Data("outside synthetic file".utf8)
        try bytes.write(to: outside)

        XCTAssertThrowsError(try files.removeCommittedFile(for: .photoSaved(outside))) { error in
            XCTAssertEqual(error as? NativeCaptureError, .invalidMedia)
        }
        XCTAssertEqual(try Data(contentsOf: outside), bytes)
    }

    func testDecodedMoviePreservesFractionalDurationAndIndependentPortraitClip() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let manifest = try await fixtures(at: root)
        let files = try CapturedMediaFiles(directory: root.appendingPathComponent("staging"))
        let id = UUID()
        let destination = files.movieDestination(id: id)
        try FileManager.default.copyItem(at: root.appendingPathComponent(manifest.movie.relativePath), to: destination)
        let event = try await files.movieSavedEvent(id: id, orientation: .portrait, remainingFrames: 300)
        guard case let .movieClipSaved(url, seconds, orientation) = event else {
            return XCTFail("Expected validated Movie file")
        }
        XCTAssertEqual(url, destination)
        XCTAssertEqual(seconds, manifest.movie.durationSeconds, accuracy: 0.000001)
        XCTAssertGreaterThan(seconds, 0)
        XCTAssertLessThan(seconds, 1)
        XCTAssertEqual(orientation, .portrait)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        do {
            _ = try await files.movieSavedEvent(id: id, orientation: .portrait, remainingFrames: 3)
            XCTFail("Over-budget footage must never be committed")
        } catch { XCTAssertEqual(error as? NativeCaptureError, .invalidMedia) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
    }

    func testClipThatRecordsExactlyTheRemainingFramesIsSavedAndOneMoreFrameIsNot() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let manifest = try await fixtures(at: root, frameRate: MovieFrames.perSecond, seconds: MovieFrames.seconds(17))
        let files = try CapturedMediaFiles(directory: root.appendingPathComponent("staging"))
        let id = UUID()
        try FileManager.default.copyItem(at: root.appendingPathComponent(manifest.movie.relativePath),
                                         to: files.movieDestination(id: id))
        do {
            _ = try await files.movieSavedEvent(id: id, orientation: .landscape, remainingFrames: 16)
            XCTFail("A clip one frame over the remaining budget must not be committed")
        } catch { XCTAssertEqual(error as? NativeCaptureError, .invalidMedia) }
        let event = try await files.movieSavedEvent(id: id, orientation: .landscape, remainingFrames: 17)
        guard case let .movieClipSaved(_, seconds, _) = event else { return XCTFail("Expected validated Movie file") }
        XCTAssertEqual(MovieFrames.count(seconds: seconds), 17)
    }

    /// A clip's sound can end a packet after its last picture frame. The clip that records exactly the remaining frames is
    /// still saved, at its picture's length: capacity is whole picture frames (S7).
    func testClipWhoseSoundEndsAfterItsLastFrameIsMeasuredByItsPicture() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let manifest = try await fixtures(at: root, frameRate: MovieFrames.perSecond, seconds: MovieFrames.seconds(17))
        let video = root.appendingPathComponent(manifest.movie.relativePath)
        let wave = root.appendingPathComponent("longer-sound.wav")
        try Self.wave(seconds: 1).write(to: wave)
        let captured = root.appendingPathComponent("sound-past-the-picture.mov")
        try await Self.addAudio(wave, to: video, destination: captured, overrunning: CMTime(value: 25, timescale: 1_000))
        let asset = AVURLAsset(url: captured)
        let whole = try await asset.load(.duration).seconds
        XCTAssertEqual(MovieFrames.count(seconds: whole), 18, "The file as a whole runs into an 18th frame")

        let files = try CapturedMediaFiles(directory: root.appendingPathComponent("staging"))
        let id = UUID()
        try FileManager.default.copyItem(at: captured, to: files.movieDestination(id: id))
        let event = try await files.movieSavedEvent(id: id, orientation: .landscape, remainingFrames: 17, allowsAudio: true)
        guard case let .movieClipSaved(_, seconds, _) = event else { return XCTFail("Expected validated Movie file") }
        XCTAssertEqual(MovieFrames.count(seconds: seconds), 17, "The clip is as long as its picture")
    }

    func testUnfinishedMovieIsRetainedWithoutReportingSaveSuccess() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let files = try CapturedMediaFiles(directory: root)
        let id = UUID()
        let url = files.movieDestination(id: id)
        let partial = Data("unfinished-movie".utf8)
        try partial.write(to: url)
        do {
            _ = try await files.movieSavedEvent(id: id, orientation: .landscape, remainingFrames: 6_000)
            XCTFail("Incomplete file must not become a save event")
        } catch { }
        XCTAssertEqual(try Data(contentsOf: url), partial)
    }

    /// Writes `videoURL`'s picture with `audioURL`'s sound to `destination`, the sound as long as the picture plus
    /// `overrunning`.
    private static func addAudio(_ audioURL: URL, to videoURL: URL, destination: URL, overrunning: CMTime = .zero) async throws {
        let videoAsset = AVURLAsset(url: videoURL)
        let audioAsset = AVURLAsset(url: audioURL)
        let composition = AVMutableComposition()
        let videoTracks = try await videoAsset.loadTracks(withMediaType: .video)
        let audioTracks = try await audioAsset.loadTracks(withMediaType: .audio)
        let video = try XCTUnwrap(videoTracks.first)
        let audio = try XCTUnwrap(audioTracks.first)
        let duration = try await videoAsset.load(.duration)
        let videoTarget = try XCTUnwrap(composition.addMutableTrack(withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid))
        let audioTarget = try XCTUnwrap(composition.addMutableTrack(withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid))
        try videoTarget.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: video, at: .zero)
        let audioDuration = try await audioAsset.load(.duration)
        try audioTarget.insertTimeRange(CMTimeRange(start: .zero, duration: min(duration + overrunning, audioDuration)),
                                        of: audio, at: .zero)
        let exporter = try XCTUnwrap(AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough))
        try await exporter.export(to: destination, as: .mov)
    }

    private static func wave(seconds: Double = 0.5) -> Data {
        let rate: UInt32 = 22_050
        let samples = Int(Double(rate) * seconds)
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

    private func makeRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("NativeCaptureFiles-\(UUID())")
    }

    private func fixtures(at root: URL, frameRate: Int = 24, seconds: Double = 0.5) async throws -> RenderFixtureManifest {
        try await RenderFixtureGenerator.writeFixtures(
            outputDirectory: root,
            settings: RenderFixtureSettings(
                photoWidth: 64, photoHeight: 64, movieWidth: 64, movieHeight: 64,
                movieFrameRate: frameRate, movieDurationSeconds: seconds, movieOrientation: .landscape
            )
        )
    }
}
