@preconcurrency import AVFoundation
import CoreImage
import CryptoKit
import FilmDomain
import FilmPersistence
import Foundation
import RenderCore
import RenderFixtures

struct ReviewAsset: Codable {
    let path: String
    let sha256: String
    let role: String
    let camera: CameraID?
    let seed: UInt64?
    let photo: PhotoFixtureMetadata?
    let movie: MovieFixtureMetadata?
    let duration: Double?
    let decodedFrames: Int
    let audioTracks: Int
}

struct ReviewManifest: Encodable {
    let schemaVersion = 1
    let status = "Draft review only; not production cleared, hardware evidence or approved DEC-04/05/11."
    let source = "Built-in image generation, 2026-10-01. See ../sources/PROVENANCE.md."
    let treatmentVersion = NativePhotoRenderer.treatmentVersion
    let movieSource = "Generated digital pan of the still, not captured motion. Two four-second silent clips: landscape then portrait."
    let musicSource = "Original deterministic score and synthesis in AssetReviewGenerator/Music.swift; no sampled recording."
    let sourceSHA256: String
    let assets: [ReviewAsset]
}

@main struct AssetReviewGenerator {
    static func main() async throws {
        let args = CommandLine.arguments
        guard args.count == 3 else { throw ReviewError.usage }
        let source = URL(fileURLWithPath: args[1]), output = URL(fileURLWithPath: args[2])
        guard !FileManager.default.fileExists(atPath: output.path) else { throw ReviewError.destinationExists }
        let sourceProof = try VerifiedMedia.photo(at: source)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        var records: [ReviewAsset] = []
        for (index, camera) in [CameraCatalog.disposable1990s, CameraCatalog.instant1970s, CameraCatalog.mediumFormat6x6].enumerated() {
            let seed = UInt64(2026100100 + index)
            let url = output.appendingPathComponent("\(camera.id.rawValue).jpg")
            try NativePhotoRenderer.develop(source: source, camera: camera, seed: seed).write(to: url)
            let verified = try VerifiedMedia.photo(at: url)
            records.append(ReviewAsset(path: url.lastPathComponent, sha256: verified.sha256, role: "Developed draft photo",
                camera: camera.id, seed: seed,
                photo: try RenderFixtureGenerator.inspectPhoto(at: url, relativePath: url.lastPathComponent),
                movie: nil, duration: nil, decodedFrames: verified.decodedFrameCount, audioTracks: 0))
        }
        let audio = output.appendingPathComponent("window-light.wav")
        try ReviewMusic.write(to: audio)
        let audioProof = try await VerifiedMedia.audio(at: audio)
        records.append(ReviewAsset(path: audio.lastPathComponent, sha256: audioProof.sha256,
            role: "Draft original instrumental: Window Light, 96 BPM, eight bars", camera: nil, seed: nil,
            photo: nil, movie: nil, duration: audioProof.durationSeconds, decodedFrames: audioProof.decodedFrameCount, audioTracks: 1))
        var sources: [URL] = []
        for portrait in [false, true] {
            let url = output.appendingPathComponent(portrait ? "source-portrait.mov" : "source-landscape.mov")
            try await writeMotion(source: source, destination: url, portrait: portrait)
            sources.append(url)
            records.append(try await movieRecord(url, role: "Silent digital-pan source, not camera capture",
                orientation: portrait ? .portrait : .landscape))
        }
        for (index, camera) in [CameraCatalog.super8HomeMovie, CameraCatalog.cinema16mm].enumerated() {
            var clips: [URL] = []
            for (sequence, source) in sources.enumerated() {
                let url = output.appendingPathComponent("\(camera.id.rawValue)-clip-\(sequence + 1).mov")
                let seed = UInt64(2026100110 + index * 10 + sequence)
                try await NativeMovieRenderer.developClip(source: source, destination: url, camera: camera,
                    seed: seed, orientation: .landscape)
                records.append(try await movieRecord(url, role: "Developed draft clip; locked landscape", camera: camera.id, seed: seed))
                clips.append(url)
            }
            for soundtrack in [false, true] {
                let url = output.appendingPathComponent("\(camera.id.rawValue)-\(soundtrack ? "instrumental" : "silent").mov")
                try await NativeMovieRenderer.assemble(clips: clips, destination: url, soundtrack: soundtrack ? audio : nil)
                records.append(try await movieRecord(url, role: soundtrack ? "Draft Movie with original instrumental" : "Silent draft Movie", camera: camera.id, allowsAudio: soundtrack))
            }
            try await poster(clips[0], to: output.appendingPathComponent("\(camera.id.rawValue)-poster.jpg"))
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(ReviewManifest(sourceSHA256: sourceProof.sha256, assets: records)).write(to: output.appendingPathComponent("manifest.json"))
        print("DRAFT_REVIEW verifiedAssets=\(records.count) treatment=\(NativePhotoRenderer.treatmentVersion) output=\(output.path)")
    }

    private static func movieRecord(_ url: URL, role: String, camera: CameraID? = nil, seed: UInt64? = nil,
                                    orientation: RenderFixtureOrientation = .landscape, allowsAudio: Bool = false) async throws -> ReviewAsset {
        let verified = try await VerifiedMedia.movie(at: url, allowsAudio: allowsAudio)
        return ReviewAsset(path: url.lastPathComponent, sha256: verified.sha256, role: role, camera: camera, seed: seed,
            photo: nil, movie: try await RenderFixtureGenerator.inspectMovie(at: url, relativePath: url.lastPathComponent, orientation: orientation),
            duration: verified.durationSeconds, decodedFrames: verified.decodedFrameCount, audioTracks: verified.audioTrackCount)
    }

    private static func writeMotion(source: URL, destination: URL, portrait: Bool) async throws {
        guard let image = CIImage(contentsOf: source) else { throw ReviewError.invalidSource }
        let width = portrait ? 480 : 640, height = portrait ? 640 : 480, fps = 30, seconds = 4
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        let writer = try AVAssetWriter(outputURL: destination, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width, AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 2_000_000, AVVideoExpectedSourceFrameRateKey: fps]])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]])
        guard writer.canAdd(input) else { throw ReviewError.writerFailed }
        writer.add(input)
        guard writer.startWriting() else { throw ReviewError.writerFailed }
        writer.startSession(atSourceTime: .zero)
        defer { if writer.status == .writing { writer.cancelWriting() } }
        let context = CIContext(options: [.cacheIntermediates: false])
        for frame in 0..<(fps * seconds) {
            let deadline = ContinuousClock.now + .seconds(10)
            while !input.isReadyForMoreMediaData {
                guard writer.status == .writing, ContinuousClock.now < deadline else { throw ReviewError.writerFailed }
                try await Task.sleep(for: .milliseconds(2))
            }
            guard let pool = adaptor.pixelBufferPool else { throw ReviewError.writerFailed }
            var buffer: CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess, let buffer else { throw ReviewError.writerFailed }
            let progress = Double(frame) / Double(fps * seconds - 1)
            let scale = max(bounds.width / image.extent.width, bounds.height / image.extent.height) * (1.06 + progress * 0.03)
            let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            let framed = scaled.transformed(by: CGAffineTransform(
                translationX: (bounds.width - scaled.extent.width) / 2 + (progress - 0.5) * 8,
                y: (bounds.height - scaled.extent.height) / 2)).cropped(to: bounds)
            context.render(framed, to: buffer, bounds: bounds, colorSpace: CGColorSpaceCreateDeviceRGB())
            guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: Int32(fps))) else { throw ReviewError.writerFailed }
        }
        writer.endSession(atSourceTime: CMTime(seconds: Double(seconds), preferredTimescale: 600))
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw ReviewError.writerFailed }
    }

    private static func poster(_ source: URL, to destination: URL) async throws {
        let asset = AVURLAsset(url: source)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw ReviewError.invalidSource }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        reader.add(output)
        guard reader.startReading() else { throw ReviewError.invalidSource }
        defer { reader.cancelReading() }
        guard let sample = output.copyNextSampleBuffer(), let buffer = CMSampleBufferGetImageBuffer(sample),
              let bytes = CIContext().jpegRepresentation(of: CIImage(cvPixelBuffer: buffer), colorSpace: CGColorSpaceCreateDeviceRGB()) else { throw ReviewError.invalidSource }
        try bytes.write(to: destination)
        _ = try VerifiedMedia.photo(at: destination)
    }
}

enum ReviewError: Error { case usage, destinationExists, invalidSource, writerFailed, audioFailed }
