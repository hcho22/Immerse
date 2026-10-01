@preconcurrency import AVFoundation
import Foundation
import ImageIO

public struct VerifiedMedia: Sendable {
    public enum Kind: Sendable { case photo, movie, audio }
    public let kind: Kind
    public let sha256: String
    public let durationSeconds: TimeInterval?
    public let decodedFrameCount: Int
    public let audioTrackCount: Int

    public static func photo(at url: URL) throws -> VerifiedMedia {
        let hash = try Checksum.sha256Hex(contentsOf: url)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetStatus(source) == .statusComplete,
              CGImageSourceGetCount(source) == 1,
              let image = CGImageSourceCreateImageAtIndex(source, 0, [
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary), image.width > 0, image.height > 0,
              CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete else {
            throw PersistenceError.invalidMedia
        }
        guard try Checksum.sha256Hex(contentsOf: url) == hash else {
            throw PersistenceError.mediaChangedDuringVerification
        }
        return VerifiedMedia(kind: .photo, sha256: hash, durationSeconds: nil, decodedFrameCount: 1, audioTrackCount: 0)
    }

    public static func movie(at url: URL, allowsAudio: Bool = false) async throws -> VerifiedMedia {
        let hash = try Checksum.sha256Hex(contentsOf: url)
        let asset = AVURLAsset(url: url)
        let video = try await asset.loadTracks(withMediaType: .video)
        let audio = try await asset.loadTracks(withMediaType: .audio)
        let duration = try await asset.load(.duration).seconds
        guard video.count == 1, let track = video.first,
              audio.count <= 1, allowsAudio || audio.isEmpty, duration.isFinite, duration > 0 else {
            throw PersistenceError.invalidMedia
        }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw PersistenceError.invalidMedia }
        reader.add(output)
        guard reader.startReading() else { throw PersistenceError.invalidMedia }
        defer { if reader.status == .reading { reader.cancelReading() } }
        var frames = 0
        while let sample = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            guard CMSampleBufferGetImageBuffer(sample) != nil else { throw PersistenceError.invalidMedia }
            frames += 1
        }
        guard reader.status == .completed, frames > 0 else { throw PersistenceError.invalidMedia }
        if let audioTrack = audio.first { _ = try decodeAudio(asset: asset, track: audioTrack) }
        guard try Checksum.sha256Hex(contentsOf: url) == hash else {
            throw PersistenceError.mediaChangedDuringVerification
        }
        return VerifiedMedia(kind: .movie, sha256: hash, durationSeconds: duration, decodedFrameCount: frames, audioTrackCount: audio.count)
    }

    public static func audio(at url: URL) async throws -> VerifiedMedia {
        let hash = try Checksum.sha256Hex(contentsOf: url)
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        let duration = try await asset.load(.duration).seconds
        guard tracks.count == 1, let track = tracks.first,
              try await asset.loadTracks(withMediaType: .video).isEmpty,
              duration.isFinite, duration > 0 else { throw PersistenceError.invalidMedia }
        let frames = try decodeAudio(asset: asset, track: track)
        guard try Checksum.sha256Hex(contentsOf: url) == hash else { throw PersistenceError.mediaChangedDuringVerification }
        return VerifiedMedia(kind: .audio, sha256: hash, durationSeconds: duration, decodedFrameCount: frames, audioTrackCount: 1)
    }

    private static func decodeAudio(asset: AVAsset, track: AVAssetTrack) throws -> Int {
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM])
        guard reader.canAdd(output) else { throw PersistenceError.invalidMedia }
        reader.add(output)
        guard reader.startReading() else { throw PersistenceError.invalidMedia }
        defer { if reader.status == .reading { reader.cancelReading() } }
        var frames = 0
        while let sample = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            guard CMSampleBufferDataIsReady(sample), CMSampleBufferGetDataBuffer(sample) != nil else {
                throw PersistenceError.invalidMedia
            }
            frames += CMSampleBufferGetNumSamples(sample)
        }
        guard reader.status == .completed, frames > 0 else { throw PersistenceError.invalidMedia }
        return frames
    }

    private init(kind: Kind, sha256: String, durationSeconds: TimeInterval?, decodedFrameCount: Int, audioTrackCount: Int) {
        self.kind = kind
        self.sha256 = sha256
        self.durationSeconds = durationSeconds
        self.decodedFrameCount = decodedFrameCount
        self.audioTrackCount = audioTrackCount
    }
}

public struct StoredMediaAsset: Sendable {
    public let record: StoredAsset
    public let url: URL
}

public enum OriginalDisposition: Codable, Equatable, Sendable {
    case declined
    case exportRequested
    case exported(sourceSHA256: String, photosIdentifier: String)
}
