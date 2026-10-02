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
        values.isExcludedFromBackup = false
        try url.setResourceValues(values)
    }

    public func movieDestination(id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).mov")
    }

    public func savePhoto(_ data: Data, id: UUID) throws -> URL {
        try Self.validatePhoto(data)
        if try !FileManager.default.itemExists(at: recordURL(id)) {
            try prepare(PendingCaptureRecord(id: id, mediaKind: .photo))
        }
        let url = directory.appendingPathComponent("\(id.uuidString).photo")
        let partial = partialURL(url)
        do {
            try data.write(to: partial)
            try synchronize(partial)
            try FileManager.default.moveItem(at: partial, to: url)
        } catch {
            try? FileManager.default.removeItemIfPresent(at: partial)
            throw error
        }
        return url
    }

    private static func validatePhoto(_ data: Data) throws {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetStatus(imageSource) == .statusComplete,
              let image = CGImageSourceCreateImageAtIndex(imageSource, 0, [
                  kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary), image.width > 0, image.height > 0 else {
            throw NativeCaptureError.invalidMedia
        }
    }

    public func prepare(_ record: PendingCaptureRecord) throws {
        let url = recordURL(record.id)
        try JSONEncoder().encode(record).write(to: url, options: [.atomic])
        try synchronize(url)
    }

    public func pendingRecords() throws -> [PendingCaptureRecord] {
        let urls = try FileManager.default.contentsOfDirectoryIfPresent(at: directory)
        let records = try urls.filter { $0.pathExtension == "json" }.map { url in
            try JSONDecoder().decode(PendingCaptureRecord.self, from: Data(contentsOf: url))
        }
        return records.sorted {
            $0.createdAt == $1.createdAt ? $0.id.uuidString < $1.id.uuidString : $0.createdAt < $1.createdAt
        }
    }

    public static func metadata(for mediaURL: URL) throws -> PendingCaptureRecord? {
        let path = mediaURL.deletingPathExtension().appendingPathExtension("json")
        guard try FileManager.default.itemExists(at: path) else { return nil }
        return try JSONDecoder().decode(PendingCaptureRecord.self, from: Data(contentsOf: path))
    }

    public func recoveryEvents() async throws -> [CaptureSaveEvent] {
        for leftover in try FileManager.default.contentsOfDirectoryIfPresent(at: directory)
            where leftover.pathExtension == "partial" {
            try FileManager.default.removeItemIfPresent(at: leftover)
        }
        var result: [CaptureSaveEvent] = []
        for record in try pendingRecords() {
            let url = record.mediaKind == .movie ? movieDestination(id: record.id)
                : directory.appendingPathComponent("\(record.id).photo")
            guard try FileManager.default.itemExists(at: url) else {
                try FileManager.default.removeItem(at: recordURL(record.id))
                continue
            }
            if record.mediaKind == .photo {
                try Self.validatePhoto(Data(contentsOf: url))
                result.append(.photoSaved(url))
            } else {
                guard let orientation = record.orientation, let budget = record.remainingFrames else {
                    throw NativeCaptureError.invalidMedia
                }
                result.append(try await movieSavedEvent(id: record.id, orientation: orientation, remainingFrames: budget))
            }
        }
        return result
    }

    public func movieSavedEvent(
        id: UUID,
        orientation: ClipOrientation,
        remainingFrames: Int
    ) async throws -> CaptureSaveEvent {
        guard remainingFrames > 0 else {
            throw NativeCaptureError.invalidDuration
        }
        let url = movieDestination(id: id)
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let audio = try await asset.loadTracks(withMediaType: .audio)
        let duration = try await asset.load(.duration).seconds
        guard let track = tracks.first, tracks.count == 1, audio.isEmpty,
              let clipFrames = MovieFrames.count(seconds: duration), clipFrames <= remainingFrames else {
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
        guard url.deletingLastPathComponent().standardizedFileURL.path == directory.standardizedFileURL.path else {
            throw NativeCaptureError.invalidMedia
        }
        try FileManager.default.removeItemIfPresent(at: url)
        try FileManager.default.removeItemIfPresent(at: url.deletingPathExtension().appendingPathExtension("json"))
    }

    public func removeUncommitted(id: UUID) throws {
        for suffix in ["photo", "photo.partial", "mov", "json"] {
            try FileManager.default.removeItemIfPresent(at: directory.appendingPathComponent("\(id).\(suffix)"))
        }
    }

    private func recordURL(_ id: UUID) -> URL { directory.appendingPathComponent("\(id).json") }
    private func partialURL(_ url: URL) -> URL { url.appendingPathExtension("partial") }

    private func synchronize(_ url: URL) throws {
        let file = try FileHandle(forWritingTo: url)
        defer { try? file.close() }
        try file.synchronize()
    }
}

/// `fileExists(atPath:)` also returns false when an existing item cannot be inspected.
/// Staging recovery and privacy cleanup treat only a confirmed-missing item as absent.
private extension FileManager {
    func itemExists(at url: URL) throws -> Bool {
        do { return try url.checkResourceIsReachable() }
        catch CocoaError.fileReadNoSuchFile { return false }
    }

    func contentsOfDirectoryIfPresent(at url: URL) throws -> [URL] {
        do { return try contentsOfDirectory(at: url, includingPropertiesForKeys: nil) }
        catch CocoaError.fileReadNoSuchFile { return [] }
    }

    func removeItemIfPresent(at url: URL) throws {
        do { try removeItem(at: url) }
        catch CocoaError.fileNoSuchFile {}
    }
}
