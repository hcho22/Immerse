@preconcurrency import AVFoundation
import FilmDomain
import Foundation
import ImageIO

public struct CapturedMediaFiles: Sendable {
    private let directory: URL

    public init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var url = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
    }

    public func movieDestination(id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).mov")
    }

    public func savePhoto(_ data: Data, id: UUID) throws -> URL {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetStatus(imageSource) == .statusComplete,
              let image = CGImageSourceCreateImageAtIndex(imageSource, 0, [
                  kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary), image.width > 0, image.height > 0 else {
            throw NativeCaptureError.invalidMedia
        }
        let url = directory.appendingPathComponent("\(id.uuidString).photo")
        try data.write(to: url, options: [.withoutOverwriting])
        try synchronize(url)
        return url
    }

    public func movieSavedEvent(
        id: UUID,
        orientation: ClipOrientation,
        remainingSeconds: TimeInterval
    ) async throws -> CaptureSaveEvent {
        guard remainingSeconds.isFinite, remainingSeconds > 0 else {
            throw NativeCaptureError.invalidDuration
        }
        let url = movieDestination(id: id)
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let audio = try await asset.loadTracks(withMediaType: .audio)
        let duration = try await asset.load(.duration).seconds
        guard let track = tracks.first, tracks.count == 1, audio.isEmpty,
              duration.isFinite, duration > 0, duration <= remainingSeconds else {
            throw NativeCaptureError.invalidMedia
        }

        // Read decoded frames through EOF; a readable container alone is not a valid saved clip.
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw NativeCaptureError.invalidMedia }
        reader.add(output)
        guard reader.startReading() else { throw NativeCaptureError.invalidMedia }
        defer { if reader.status == .reading { reader.cancelReading() } }
        var frames = 0
        while let sample = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            guard CMSampleBufferGetImageBuffer(sample) != nil else {
                throw NativeCaptureError.invalidMedia
            }
            frames += 1
        }
        guard reader.status == .completed, frames > 0 else { throw NativeCaptureError.invalidMedia }
        try synchronize(url)
        return .movieClipSaved(url: url, durationSeconds: duration, orientation: orientation)
    }

    public func removeCommittedFile(for event: CaptureSaveEvent) throws {
        let url: URL
        switch event {
        case let .photoSaved(value), let .movieClipSaved(value, _, _): url = value
        default: return
        }
        guard url.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL else {
            throw NativeCaptureError.invalidMedia
        }
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }

    private func synchronize(_ url: URL) throws {
        let file = try FileHandle(forWritingTo: url)
        defer { try? file.close() }
        try file.synchronize()
    }
}
