@preconcurrency import AVFoundation
import CoreGraphics
import CoreMedia
import CoreVideo
import Foundation
import ImageIO

public enum RenderFixtureError: Error, Equatable {
    case invalidSettings(String)
    case imageCreationFailed
    case imageDestinationCreationFailed
    case imageFinalizeFailed
    case assetWriterInputRejected
    case assetWriterFailed(String)
    case missingMovieTrack
    case missingVideoFormatDescription
    case missingCodec
}

public enum RenderFixtureGenerator {
    public static func writeFixtures(
        outputDirectory: URL,
        settings: RenderFixtureSettings = .defaultExperimental
    ) async throws -> RenderFixtureManifest {
        try validate(settings)
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        let photoURL = outputDirectory.appendingPathComponent("synthetic-developed-photo.jpg")
        let movieURL = outputDirectory.appendingPathComponent("synthetic-developed-movie.mov")
        let manifestURL = outputDirectory.appendingPathComponent("manifest.json")

        try writeSyntheticPhoto(to: photoURL, width: settings.photoWidth, height: settings.photoHeight)
        try writeSyntheticMovie(to: movieURL, settings: settings)

        let manifest = RenderFixtureManifest(
            note: "Synthetic native API fixture for render discovery only; not production treatment quality and not a DEC-04 decision.",
            settings: settings,
            photo: try inspectPhoto(at: photoURL, relativePath: photoURL.lastPathComponent),
            movie: try await inspectMovie(
                at: movieURL,
                relativePath: movieURL.lastPathComponent,
                orientation: settings.movieOrientation
            )
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(manifest).write(to: manifestURL, options: [.atomic])
        return manifest
    }

    public static func inspectPhoto(
        at url: URL,
        relativePath: String
    ) throws -> PhotoFixtureMetadata {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw RenderFixtureError.imageCreationFailed
        }

        let width = properties[kCGImagePropertyPixelWidth] as? Int ?? image.width
        let height = properties[kCGImagePropertyPixelHeight] as? Int ?? image.height
        let type = CGImageSourceGetType(source) as String? ?? "unknown"
        return PhotoFixtureMetadata(
            relativePath: relativePath,
            pixelWidth: width,
            pixelHeight: height,
            uniformTypeIdentifier: type,
            hasAlpha: image.alphaInfo != .none && image.alphaInfo != .noneSkipFirst && image.alphaInfo != .noneSkipLast
        )
    }

    public static func inspectMovie(
        at url: URL,
        relativePath: String,
        orientation: RenderFixtureOrientation
    ) async throws -> MovieFixtureMetadata {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw RenderFixtureError.missingMovieTrack
        }
        guard let formatDescription = try await track.load(.formatDescriptions).first else {
            throw RenderFixtureError.missingVideoFormatDescription
        }
        let mediaSubType = CMFormatDescriptionGetMediaSubType(formatDescription)
        let codec = fourCharacterCodeString(mediaSubType)
        let naturalSize = try await track.load(.naturalSize)
        let nominalFrameRate = try await track.load(.nominalFrameRate)
        let duration = try await asset.load(.duration)
        let preferredTransform = try await track.load(.preferredTransform)
        return MovieFixtureMetadata(
            relativePath: relativePath,
            encodedWidth: Int(naturalSize.width.rounded()),
            encodedHeight: Int(naturalSize.height.rounded()),
            codecFourCC: codec,
            nominalFrameRate: nominalFrameRate,
            durationSeconds: CMTimeGetSeconds(duration),
            orientation: orientation,
            preferredTransform: TransformMetadata(preferredTransform)
        )
    }

    private static func validate(_ settings: RenderFixtureSettings) throws {
        guard settings.photoWidth > 0, settings.photoHeight > 0 else {
            throw RenderFixtureError.invalidSettings("photo dimensions must be positive")
        }
        guard settings.movieWidth > 0, settings.movieHeight > 0 else {
            throw RenderFixtureError.invalidSettings("movie dimensions must be positive")
        }
        guard settings.movieFrameRate > 0 else {
            throw RenderFixtureError.invalidSettings("movie frame rate must be positive")
        }
        guard settings.movieDurationSeconds > 0 else {
            throw RenderFixtureError.invalidSettings("movie duration must be positive")
        }
    }

    private static func writeSyntheticPhoto(to url: URL, width: Int, height: Int) throws {
        let image = try makeSyntheticImage(width: width, height: height, frameIndex: 0)
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.jpeg" as CFString, 1, nil) else {
            throw RenderFixtureError.imageDestinationCreationFailed
        }
        CGImageDestinationAddImage(destination, image, [
            kCGImageDestinationLossyCompressionQuality: 0.92
        ] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw RenderFixtureError.imageFinalizeFailed
        }
    }

    private static func writeSyntheticMovie(to url: URL, settings: RenderFixtureSettings) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let outputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: settings.movieWidth,
            AVVideoHeightKey: settings.movieHeight,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 2_000_000,
                AVVideoMaxKeyFrameIntervalKey: settings.movieFrameRate
            ]
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        input.expectsMediaDataInRealTime = false
        input.transform = transform(
            for: settings.movieOrientation,
            width: settings.movieWidth,
            height: settings.movieHeight
        )

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: settings.movieWidth,
                kCVPixelBufferHeightKey as String: settings.movieHeight
            ]
        )

        guard writer.canAdd(input) else {
            throw RenderFixtureError.assetWriterInputRejected
        }
        writer.add(input)

        guard writer.startWriting() else {
            throw RenderFixtureError.assetWriterFailed(writer.error?.localizedDescription ?? "startWriting failed")
        }
        writer.startSession(atSourceTime: .zero)

        let frameCount = max(1, Int((settings.movieDurationSeconds * Double(settings.movieFrameRate)).rounded()))
        for frameIndex in 0..<frameCount {
            while !input.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.001)
            }
            guard let pool = adaptor.pixelBufferPool else {
                throw RenderFixtureError.assetWriterFailed("missing pixel buffer pool")
            }
            var pixelBuffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
            guard let pixelBuffer else {
                throw RenderFixtureError.assetWriterFailed("pixel buffer allocation failed")
            }
            try fill(pixelBuffer, frameIndex: frameIndex)
            let time = CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(settings.movieFrameRate))
            guard adaptor.append(pixelBuffer, withPresentationTime: time) else {
                throw RenderFixtureError.assetWriterFailed(writer.error?.localizedDescription ?? "append failed")
            }
        }

        input.markAsFinished()
        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting {
            semaphore.signal()
        }
        semaphore.wait()

        if writer.status != .completed {
            throw RenderFixtureError.assetWriterFailed(writer.error?.localizedDescription ?? "\(writer.status.rawValue)")
        }
    }

    private static func makeSyntheticImage(
        width: Int,
        height: Int,
        frameIndex: Int
    ) throws -> CGImage {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var bytes = [UInt8](repeating: 0, count: height * bytesPerRow)
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                bytes[offset] = UInt8((x + frameIndex * 7) % 256)
                bytes[offset + 1] = UInt8((y + frameIndex * 11) % 256)
                bytes[offset + 2] = UInt8((x + y + frameIndex * 13) % 256)
                bytes[offset + 3] = 255
            }
        }

        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let image = CGImage(
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bitsPerPixel: 32,
                  bytesPerRow: bytesPerRow,
                  space: colorSpace,
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                  provider: provider,
                  decode: nil,
                  shouldInterpolate: false,
                  intent: .defaultIntent
              ) else {
            throw RenderFixtureError.imageCreationFailed
        }
        return image
    }

    private static func fill(_ pixelBuffer: CVPixelBuffer, frameIndex: Int) throws {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw RenderFixtureError.assetWriterFailed("missing pixel buffer base address")
        }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let pointer = baseAddress.assumingMemoryBound(to: UInt8.self)
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * 4
                pointer[offset] = UInt8((x + frameIndex * 3) % 256)
                pointer[offset + 1] = UInt8((y + frameIndex * 5) % 256)
                pointer[offset + 2] = UInt8((x + y + frameIndex * 7) % 256)
                pointer[offset + 3] = 255
            }
        }
    }

    private static func transform(
        for orientation: RenderFixtureOrientation,
        width: Int,
        height: Int
    ) -> CGAffineTransform {
        switch orientation {
        case .landscape:
            .identity
        case .portrait:
            CGAffineTransform(translationX: CGFloat(height), y: 0).rotated(by: .pi / 2)
        }
    }

    private static func fourCharacterCodeString(_ code: FourCharCode) -> String {
        let bytes: [UInt8] = [
            UInt8((code >> 24) & 0xff),
            UInt8((code >> 16) & 0xff),
            UInt8((code >> 8) & 0xff),
            UInt8(code & 0xff)
        ]
        return String(bytes: bytes, encoding: .ascii) ?? "\(code)"
    }
}
