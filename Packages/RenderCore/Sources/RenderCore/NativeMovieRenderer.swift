@preconcurrency import AVFoundation
import CoreImage
import FilmDomain
import Foundation

public enum NativeMovieRenderer {
    /// One Developed Clip: every frame of the clip in the Camera's treatment for the Film's Film Stock, at the Camera's
    /// frame rate. A nil Film Stock, a Camera without one or a Film loaded before Film Stock existed, develops as color.
    public static func developClip(
        source: URL, destination: URL, camera: CameraPackage, filmStock: FilmStock? = nil, seed: UInt64,
        orientation: MovieOrientation, longEdge: Int = 1920
    ) async throws {
        guard camera.medium == .movie else { throw NativeRenderError.wrongMedium }
        try FilmLook.require(filmStock, offeredBy: camera)
        guard longEdge > 0, longEdge % 16 == 0 else { throw NativeRenderError.invalidMovie }
        let asset = AVURLAsset(url: source)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard tracks.count == 1, let track = tracks.first,
              try await asset.loadTracks(withMediaType: .audio).isEmpty else { throw NativeRenderError.invalidMovie }
        let duration = try await asset.load(.duration)
        let transform = try await track.load(.preferredTransform)
        guard duration.seconds.isFinite, duration.seconds > 0 else { throw NativeRenderError.invalidMovie }
        let fps = camera.id == .super8HomeMovie ? 18 : 24
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
            let treated = try FilmLook.apply(to: image, camera: camera.id, filmStock: filmStock, seed: seed, frame: frame)
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
            while Double(frame) / Double(fps) <= elapsed && Double(frame) / Double(fps) < duration.seconds {
                try await append(lastImage ?? fitted)
            }
            lastImage = fitted
        }
        guard reader.status == .completed, let lastImage else { throw NativeRenderError.invalidMovie }
        while Double(frame) / Double(fps) < duration.seconds { try await append(lastImage) }
        writer.endSession(atSourceTime: duration)
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw NativeRenderError.writerFailed }
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
