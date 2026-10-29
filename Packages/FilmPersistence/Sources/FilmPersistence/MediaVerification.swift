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
        guard video.count == 1, let track = video.first, audio.count <= 1, allowsAudio || audio.isEmpty else {
            throw PersistenceError.invalidMedia
        }
        // A movie is as long as its picture, as the capture check measures it (`CapturedMediaFiles`): its sound can end a
        // packet later.
        let duration = try await track.load(.timeRange).duration.seconds
        guard duration.isFinite, duration > 0 else { throw PersistenceError.invalidMedia }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw PersistenceError.invalidMedia }
        reader.add(output)
        guard reader.startReading() else {
            throw PersistenceError.unreadableMedia(MediaReadFailure(.pictureStart, framesRead: 0, reader: reader))
        }
        defer { if reader.status == .reading { reader.cancelReading() } }
        var frames = 0
        while let sample = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            guard CMSampleBufferGetImageBuffer(sample) != nil else { throw PersistenceError.invalidMedia }
            frames += 1
        }
        guard reader.status == .completed else {
            throw PersistenceError.unreadableMedia(MediaReadFailure(.picture, framesRead: frames, reader: reader))
        }
        guard frames > 0 else { throw PersistenceError.invalidMedia }
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
        guard reader.startReading() else {
            throw PersistenceError.unreadableMedia(MediaReadFailure(.soundStart, framesRead: 0, reader: reader))
        }
        defer { if reader.status == .reading { reader.cancelReading() } }
        var frames = 0
        while let sample = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            guard CMSampleBufferDataIsReady(sample), CMSampleBufferGetDataBuffer(sample) != nil else {
                throw PersistenceError.invalidMedia
            }
            frames += CMSampleBufferGetNumSamples(sample)
        }
        guard reader.status == .completed else {
            throw PersistenceError.unreadableMedia(MediaReadFailure(.sound, framesRead: frames, reader: reader))
        }
        guard frames > 0 else { throw PersistenceError.invalidMedia }
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

/// What AVFoundation said about a read that did not finish: which read it was and where it stopped, how many frames it
/// had read, the reader's status, and its error with every error underneath, since a failed status alone names no cause.
/// It holds the errors' text, not the errors, so it stays `Sendable`.
public struct MediaReadFailure: Sendable, Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    public enum Stage: String, Sendable {
        /// The picture read did not start.
        case pictureStart = "picture read did not start"
        /// The picture read started and ended without finishing.
        case picture = "picture read did not finish"
        /// The sound read did not start.
        case soundStart = "sound read did not start"
        /// The sound read started and ended without finishing.
        case sound = "sound read did not finish"
    }

    /// One error as AVFoundation gave it.
    public struct ReportedError: Sendable, Equatable {
        public let domain: String
        public let code: Int
        public let description: String
        public let reason: String?

        public init(domain: String, code: Int, description: String, reason: String? = nil) {
            self.domain = domain
            self.code = code
            self.description = description
            self.reason = reason
        }
    }

    public let stage: Stage
    /// Picture frames, or sound sample frames, read before the read ended.
    public let framesRead: Int
    /// The reader's `AVAssetReader.Status` raw value.
    public let status: Int
    /// The reader's error first, then each error underneath it; empty when the reader recorded none.
    public let errors: [ReportedError]

    public init(stage: Stage, framesRead: Int, status: Int, errors: [ReportedError]) {
        self.stage = stage
        self.framesRead = framesRead
        self.status = status
        self.errors = errors
    }

    init(_ stage: Stage, framesRead: Int, reader: AVAssetReader) {
        var errors: [ReportedError] = []
        var error = reader.error as NSError?
        while let current = error {
            errors.append(ReportedError(domain: current.domain, code: current.code, description: current.localizedDescription,
                                        reason: current.localizedFailureReason))
            error = current.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        self.init(stage: stage, framesRead: framesRead, status: reader.status.rawValue, errors: errors)
    }

    public var description: String {
        var parts = ["\(stage.rawValue): reader status \(statusName) (\(status)) after \(framesRead) frames"]
        for (depth, error) in errors.enumerated() {
            parts.append("\(depth == 0 ? "error" : "underlying error"): \(error.domain) \(error.code), \"\(error.description)\""
                + (error.reason.map { ", reason \"\($0)\"" } ?? ""))
        }
        if errors.isEmpty { parts.append("no error recorded") }
        return parts.joined(separator: "; ")
    }

    public var debugDescription: String { description }

    private var statusName: String {
        switch AVAssetReader.Status(rawValue: status) {
        case .unknown: "unknown"
        case .reading: "reading"
        case .completed: "completed"
        case .failed: "failed"
        case .cancelled: "cancelled"
        default: "new"
        }
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
