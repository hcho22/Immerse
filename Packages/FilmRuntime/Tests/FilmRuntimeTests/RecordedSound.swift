@preconcurrency import AVFoundation
import Foundation
import RenderFixtures
import XCTest

/// Sound as a movie Camera records it beside a Recorded Clip: a generated tone encoded as AAC, added to a generated
/// picture. Shared by the tests that need a clip with Live Audio.
enum RecordedSound {
    /// A stereo tone at 48 kHz, as WAV: a tenth of a second unless `seconds` says otherwise.
    static func wave(seconds: Double = 0.1) -> Data {
        let rate: UInt32 = 48_000
        let samples = Int(Double(rate) * seconds)
        var bytes = Data()
        func text(_ value: String) { bytes.append(contentsOf: value.utf8) }
        func integer<T: FixedWidthInteger>(_ value: T) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { bytes.append(contentsOf: $0) }
        }
        text("RIFF"); integer(UInt32(36 + samples * 4)); text("WAVEfmt ")
        integer(UInt32(16)); integer(UInt16(1)); integer(UInt16(2)); integer(rate)
        integer(rate * 4); integer(UInt16(4)); integer(UInt16(16)); text("data"); integer(UInt32(samples * 4))
        for sample in 0..<samples {
            let value = Int16(sin(Double(sample) * 2 * .pi * 440 / Double(rate)) * 4_000)
            integer(value); integer(value)
        }
        return bytes
    }

    static func addAudio(_ audioURL: URL, to videoURL: URL, destination: URL) async throws {
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
        try audioTarget.insertTimeRange(CMTimeRange(start: .zero, duration: min(duration, audioDuration)),
                                        of: audio, at: .zero)
        let exporter = try XCTUnwrap(AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough))
        try await exporter.export(to: destination, as: .mov)
    }

    static func encodeAAC(_ audioURL: URL, destination: URL) async throws {
        let asset = AVURLAsset(url: audioURL)
        let exporter = try XCTUnwrap(AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A))
        try await exporter.export(to: destination, as: .m4a)
    }

    /// A Recorded Clip with Live Audio in `directory`: the generator's picture, `seconds` long, with a stereo AAC tone
    /// as long as it. Returns the clip and the picture's length, which is what a capture counts.
    static func clip(seconds: Double, in directory: URL) async throws -> (url: URL, seconds: Double) {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var settings = RenderFixtureSettings.defaultExperimental
        settings.movieWidth = 320; settings.movieHeight = 240; settings.movieDurationSeconds = seconds
        let manifest = try await RenderFixtureGenerator.writeFixtures(outputDirectory: directory, settings: settings)
        let tone = directory.appendingPathComponent("tone.wav")
        try wave(seconds: seconds).write(to: tone)
        let sound = directory.appendingPathComponent("tone.m4a")
        try await encodeAAC(tone, destination: sound)
        let clip = directory.appendingPathComponent("recorded-clip.mov")
        try await addAudio(sound, to: directory.appendingPathComponent("synthetic-developed-movie.mov"), destination: clip)
        return (clip, manifest.movie.durationSeconds)
    }
}
