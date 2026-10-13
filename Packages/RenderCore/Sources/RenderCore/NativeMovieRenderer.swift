@preconcurrency import AVFoundation
import CoreImage
import FilmDomain
import Foundation

/// The format Developed Clips and the Developed Movie are written and saved to Photos in, the captain's of 2026-10-13
/// (DEC-04): H.264 in a `.mov`, 1920 x 1440, or 1440 x 1920 for a portrait Movie, at the Camera's frame rate, silent
/// unless a licensed built-in soundtrack is chosen.
public enum DevelopedMovieFormat {
    public static let longEdge = 1920

    /// The frame of a Movie in `orientation`, in the Camera's 4:3 proportions.
    public static func size(_ orientation: MovieOrientation) -> (width: Int, height: Int) {
        orientation == .landscape ? (longEdge, longEdge * 3 / 4) : (longEdge * 3 / 4, longEdge)
    }

    public static func framesPerSecond(_ camera: CameraID) -> Int { camera == .super8HomeMovie ? 18 : 24 }

    /// The frames a Developed Clip of `seconds` has: every whole frame that fits, and at least one.
    public static func frameCount(seconds: Double, camera: CameraID) -> Int {
        max(1, Int((seconds * Double(framesPerSecond(camera)) + 0.000_001).rounded(.down)))
    }
}

public enum NativeMovieRenderer {
    /// One Developed Clip: every frame of the clip in the Camera's treatment, in the clip's assigned treatment version,
    /// for the Film's Film Stock, at the Camera's frame rate. A nil Film Stock, a Camera without one or a Film loaded
    /// before Film Stock existed, develops as color.
    public static func developClip(
        source: URL, destination: URL, camera: CameraPackage, filmStock: FilmStock? = nil, seed: UInt64,
        orientation: MovieOrientation, longEdge: Int = DevelopedMovieFormat.longEdge,
        treatmentVersion: String = NativePhotoRenderer.treatmentVersion
    ) async throws {
        guard camera.medium == .movie else { throw NativeRenderError.wrongMedium }
        guard longEdge > 0, longEdge % 16 == 0 else { throw NativeRenderError.invalidMovie }
        let asset = AVURLAsset(url: source)
        let treatment = try DevelopedTreatment(version: treatmentVersion, camera: camera.id, filmStock: filmStock, seed: seed,
                                               sceneWhiteBalance: try await sceneWhiteBalance(of: asset))
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard tracks.count == 1, let track = tracks.first,
              try await asset.loadTracks(withMediaType: .audio).isEmpty else { throw NativeRenderError.invalidMovie }
        let duration = try await asset.load(.duration)
        let transform = try await track.load(.preferredTransform)
        guard duration.seconds.isFinite, duration.seconds > 0 else { throw NativeRenderError.invalidMovie }
        let fps = DevelopedMovieFormat.framesPerSecond(camera.id)
        // Only whole frames: the clip's last frame is held to where the recording stopped. A frame begun in the sliver
        // of time left over would last a fraction of a frame and count against the Camera's frame rate.
        let frameCount = DevelopedMovieFormat.frameCount(seconds: duration.seconds, camera: camera.id)
        let width = orientation == .landscape ? longEdge : longEdge * 3 / 4
        let height = orientation == .landscape ? longEdge * 3 / 4 : longEdge
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw NativeRenderError.invalidMovie }
        reader.add(output)
        let writer = try AVAssetWriter(outputURL: destination, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width, AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 8_000_000,
                AVVideoExpectedSourceFrameRateKey: fps,
                AVVideoMaxKeyFrameIntervalKey: fps
            ]
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ])
        guard writer.canAdd(input) else { throw NativeRenderError.writerFailed }
        writer.add(input)
        guard reader.startReading(), writer.startWriting() else { throw NativeRenderError.writerFailed }
        writer.startSession(atSourceTime: .zero)
        defer {
            if reader.status == .reading { reader.cancelReading() }
            if writer.status == .writing { writer.cancelWriting() }
        }
        let context = CIContext(options: [.cacheIntermediates: false])
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var frame = 0
        var firstTime: CMTime?
        var lastImage: CIImage?

        func append(_ image: CIImage) async throws {
            let deadline = ContinuousClock.now + .seconds(15)
            while !input.isReadyForMoreMediaData {
                try Task.checkCancellation()
                guard writer.status == .writing else { throw NativeRenderError.writerFailed }
                guard ContinuousClock.now < deadline else { throw NativeRenderError.writerTimedOut }
                try await Task.sleep(for: .milliseconds(2))
            }
            guard let pool = adaptor.pixelBufferPool else { throw NativeRenderError.writerFailed }
            var buffer: CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess, let buffer else {
                throw NativeRenderError.writerFailed
            }
            let treated = try treatment.apply(to: image, frame: frame, frameRate: fps)
            context.render(treated, to: buffer, bounds: bounds, colorSpace: colorSpace)
            guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: Int32(fps))) else {
                throw NativeRenderError.writerFailed
            }
            frame += 1
        }

        while let sample = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            guard let buffer = CMSampleBufferGetImageBuffer(sample) else { throw NativeRenderError.invalidMovie }
            let time = CMSampleBufferGetPresentationTimeStamp(sample)
            if firstTime == nil { firstTime = time }
            let elapsed = (time - firstTime!).seconds
            let decoded = CIImage(cvPixelBuffer: buffer)
            let image = NativePhotoRenderer.normalize(decoded.transformed(by: coreImage(transform, extent: decoded.extent)))
            let scale = min(bounds.width / image.extent.width, bounds.height / image.extent.height)
            let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            let fitted = scaled.transformed(by: CGAffineTransform(
                translationX: (bounds.width - scaled.extent.width) / 2,
                y: (bounds.height - scaled.extent.height) / 2
            )).composited(over: CIImage(color: .black).cropped(to: bounds)).cropped(to: bounds)
            while Double(frame) / Double(fps) <= elapsed && frame < frameCount {
                try await append(lastImage ?? fitted)
            }
            lastImage = fitted
        }
        guard reader.status == .completed, let lastImage else { throw NativeRenderError.invalidMovie }
        while frame < frameCount { try await append(lastImage) }
        writer.endSession(atSourceTime: duration)
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw NativeRenderError.writerFailed }
    }

    /// The light the clip was recorded in, which the capture writes into the clip's QuickTime metadata.
    static func sceneWhiteBalance(of asset: AVURLAsset) async throws -> SceneWhiteBalance? {
        let identifier = AVMetadataItem.identifier(forKey: SceneWhiteBalance.metadataKey, keySpace: .quickTimeMetadata)
        let items = AVMetadataItem.metadataItems(from: try await asset.load(.metadata), filteredByIdentifier: identifier!)
        guard let value = try await items.first?.load(.stringValue) else { return nil }
        return SceneWhiteBalance(metadataValue: value)
    }

    /// `preferredTransform` uses a top-left origin and Core Image a bottom-left one, so the
    /// transform is conjugated with a vertical flip of the source and of the rotated frame.
    static func coreImage(_ transform: CGAffineTransform, extent: CGRect) -> CGAffineTransform {
        let flipSource = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: extent.height)
        let flipFrame = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0,
                                          ty: CGRect(origin: .zero, size: extent.size).applying(transform).height)
        return flipSource.concatenating(transform).concatenating(flipFrame)
    }

    public static func assemble(clips: [URL], destination: URL, soundtrack: URL? = nil) async throws {
        guard !clips.isEmpty else { throw NativeRenderError.invalidMovie }
        let composition = AVMutableComposition()
        guard let video = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw NativeRenderError.invalidMovie
        }
        var cursor = CMTime.zero
        var dimensions: CGSize?
        for url in clips {
            try Task.checkCancellation()
            let asset = AVURLAsset(url: url)
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard tracks.count == 1, let track = tracks.first,
                  try await asset.loadTracks(withMediaType: .audio).isEmpty else { throw NativeRenderError.invalidMovie }
            let size = try await track.load(.naturalSize)
            let transform = try await track.load(.preferredTransform)
            guard transform == .identity, dimensions == nil || dimensions == size else { throw NativeRenderError.invalidMovie }
            dimensions = size
            let duration = try await asset.load(.duration)
            guard duration.seconds.isFinite, duration.seconds > 0 else { throw NativeRenderError.invalidMovie }
            try video.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: track, at: cursor)
            cursor = cursor + duration
        }
        if let soundtrack {
            let audioAsset = AVURLAsset(url: soundtrack)
            guard let source = try await audioAsset.loadTracks(withMediaType: .audio).first,
                  let audio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                throw NativeRenderError.invalidMovie
            }
            let length = try await audioAsset.load(.duration)
            guard length.seconds.isFinite, length.seconds > 0 else { throw NativeRenderError.invalidMovie }
            var offset = CMTime.zero
            while offset < cursor {
                try audio.insertTimeRange(CMTimeRange(start: .zero, duration: min(length, cursor - offset)), of: source, at: offset)
                offset = offset + min(length, cursor - offset)
            }
        }
        guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
            throw NativeRenderError.writerFailed
        }
        try await export.export(to: destination, as: .mov)
    }
}
