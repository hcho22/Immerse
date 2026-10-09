@preconcurrency import AVFoundation
import CoreImage
import FilmDomain
import FilmPersistence
import Foundation
import ImageIO
import RenderCore
import UniformTypeIdentifiers

/// Renders the scenes of a look review board through the production renderers: every Photo Camera and Film Stock
/// develops each photo scene with `NativePhotoRenderer.develop`, and every Movie Camera and Film Stock develops each
/// scene as a Developed Clip with `NativeMovieRenderer.developClip`. Nothing here sets a look; it only shows one.
///
/// Usage: `LookReviewBoards <scenes.json> <new output directory>`. Scene paths are relative to the JSON file.
@main struct LookReviewBoards {
    struct Scenes: Decodable {
        struct Photo: Decodable {
            let id: String
            let file: String
            /// Whether the scene was lit by on-camera flash, which the Disposable's flash look reads from Exif.
            let flash: Bool?
            /// The light the scene was lit by, as a clip's `SceneWhiteBalance` metadata value ("3200,0"), written into
            /// the Movie Cameras' clips of the scene so a fixed-balance Film Stock develops against it.
            let light: String?
        }

        struct Movie: Decodable {
            let id: String
            let file: String
            let light: String?
        }

        let photos: [Photo]
        let movies: [Movie]
    }

    struct Output: Encodable {
        let treatmentVersion = NativePhotoRenderer.treatmentVersion
        let comparedVersion = NativePhotoRenderer.lockedBeforeVersionsTreatmentVersion
        var files: [Rendered] = []
    }

    struct Rendered: Encodable {
        let camera: String
        let filmStock: String?
        let scene: String
        let kind: String
        let path: String
        let seed: UInt64?
        let version: String?
    }

    static let displayEdge: CGFloat = 1600

    static func main() async throws {
        let args = CommandLine.arguments
        guard args.count == 3 else { throw BoardError.usage }
        let scenesURL = URL(fileURLWithPath: args[1]), output = URL(fileURLWithPath: args[2])
        guard !FileManager.default.fileExists(atPath: output.path) else { throw BoardError.destinationExists }
        let base = scenesURL.deletingLastPathComponent()
        let scenes = try JSONDecoder().decode(Scenes.self, from: Data(contentsOf: scenesURL))
        let work = output.appendingPathComponent("work")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        var manifest = Output()

        // The sources as the board shows them.
        let sourceDirectory = output.appendingPathComponent("scenes")
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        var photoSources: [String: URL] = [:]
        for scene in scenes.photos {
            var source = base.appendingPathComponent(scene.file)
            if scene.flash == true {
                // The capture as the Disposable would record it: the same pixels with Exif saying the flash fired.
                let tagged = work.appendingPathComponent("\(scene.id)-flash.jpg")
                try tagFlash(source, to: tagged)
                source = tagged
            }
            photoSources[scene.id] = source
            try writeDisplay(CIImage(contentsOf: source, options: [.applyOrientationProperty: true])!,
                             to: sourceDirectory.appendingPathComponent("\(scene.id).jpg"))
            manifest.files.append(Rendered(camera: "source", filmStock: nil, scene: scene.id, kind: "source",
                                           path: "scenes/\(scene.id).jpg", seed: nil, version: nil))
        }

        for (index, camera) in CameraCatalog.all.enumerated() {
            for filmStock in camera.filmStocks.isEmpty ? [nil] : camera.filmStocks.map(Optional.some) {
                let folder = camera.id.rawValue + (filmStock.map { "-\($0.rawValue)" } ?? "")
                let directory = output.appendingPathComponent(folder)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                for (sceneIndex, scene) in scenes.photos.enumerated() {
                    let seed = UInt64(2026_1009_00 + index * 100 + sceneIndex)
                    let source = photoSources[scene.id]!
                    if camera.medium == .photo {
                        for version in [NativePhotoRenderer.treatmentVersion, NativePhotoRenderer.lockedBeforeVersionsTreatmentVersion] {
                            let master = try NativePhotoRenderer.develop(source: source, camera: camera, seed: seed,
                                                                         filmStock: filmStock, treatmentVersion: version)
                            let verify = work.appendingPathComponent("verify.jpg")
                            try master.write(to: verify)
                            _ = try VerifiedMedia.photo(at: verify)
                            let current = version == NativePhotoRenderer.treatmentVersion
                            let name = current ? scene.id : "\(scene.id)-v2"
                            let image = CIImage(data: master)!
                            try writeDisplay(image, to: directory.appendingPathComponent("\(name).jpg"))
                            manifest.files.append(Rendered(camera: camera.id.rawValue, filmStock: filmStock?.rawValue, scene: scene.id,
                                kind: current ? "developed" : "previous", path: "\(folder)/\(name).jpg", seed: seed, version: version))
                            if current {
                                try writeCrop(image, to: directory.appendingPathComponent("\(scene.id)-crop.jpg"))
                                manifest.files.append(Rendered(camera: camera.id.rawValue, filmStock: filmStock?.rawValue, scene: scene.id,
                                    kind: "crop", path: "\(folder)/\(scene.id)-crop.jpg", seed: seed, version: version))
                            }
                        }
                        // The Instant: the same scene on further prints, each with its own variation.
                        if camera.id == .instant1970s {
                            for print in 1...3 {
                                let printSeed = seed + UInt64(print) * 7919
                                let master = try NativePhotoRenderer.develop(source: source, camera: camera, seed: printSeed)
                                try writeDisplay(CIImage(data: master)!, to: directory.appendingPathComponent("\(scene.id)-print-\(print).jpg"))
                                manifest.files.append(Rendered(camera: camera.id.rawValue, filmStock: nil, scene: scene.id,
                                    kind: "print", path: "\(folder)/\(scene.id)-print-\(print).jpg", seed: printSeed,
                                    version: NativePhotoRenderer.treatmentVersion))
                            }
                        }
                    } else {
                        // A Movie Camera's frame of the photo scene: a two-second still clip developed as a Developed
                        // Clip, from which a frame is kept.
                        let still = work.appendingPathComponent("\(scene.id)-still.mov")
                        if !FileManager.default.fileExists(atPath: still.path) {
                            try await writeStillClip(source, to: still, light: scene.light.flatMap(SceneWhiteBalance.init(metadataValue:)))
                        }
                        let clip = work.appendingPathComponent("\(folder)-\(scene.id).mov")
                        try await NativeMovieRenderer.developClip(source: still, destination: clip, camera: camera,
                            filmStock: filmStock, seed: seed, orientation: .landscape)
                        let frame = try await frameImage(clip, index: 9)
                        try writeDisplay(frame, to: directory.appendingPathComponent("\(scene.id).jpg"))
                        try writeCrop(frame, to: directory.appendingPathComponent("\(scene.id)-crop.jpg"))
                        manifest.files.append(Rendered(camera: camera.id.rawValue, filmStock: filmStock?.rawValue, scene: scene.id,
                            kind: "developed", path: "\(folder)/\(scene.id).jpg", seed: seed, version: NativePhotoRenderer.treatmentVersion))
                        manifest.files.append(Rendered(camera: camera.id.rawValue, filmStock: filmStock?.rawValue, scene: scene.id,
                            kind: "crop", path: "\(folder)/\(scene.id)-crop.jpg", seed: seed, version: NativePhotoRenderer.treatmentVersion))
                        let earlier = work.appendingPathComponent("\(folder)-\(scene.id)-v2.mov")
                        try await NativeMovieRenderer.developClip(source: still, destination: earlier, camera: camera,
                            filmStock: filmStock, seed: seed, orientation: .landscape,
                            treatmentVersion: NativePhotoRenderer.lockedBeforeVersionsTreatmentVersion)
                        try writeDisplay(try await frameImage(earlier, index: 9), to: directory.appendingPathComponent("\(scene.id)-v2.jpg"))
                        manifest.files.append(Rendered(camera: camera.id.rawValue, filmStock: filmStock?.rawValue, scene: scene.id,
                            kind: "previous", path: "\(folder)/\(scene.id)-v2.jpg", seed: seed,
                            version: NativePhotoRenderer.lockedBeforeVersionsTreatmentVersion))
                    }
                }
                guard camera.medium == .movie else { continue }
                for (sceneIndex, scene) in scenes.movies.enumerated() {
                    let seed = UInt64(2026_1009_50 + index * 100 + sceneIndex)
                    let clip = directory.appendingPathComponent("\(scene.id).mov")
                    var source = base.appendingPathComponent(scene.file)
                    if let light = scene.light.flatMap(SceneWhiteBalance.init(metadataValue:)) {
                        let tagged = work.appendingPathComponent("\(scene.id)-light.mov")
                        if !FileManager.default.fileExists(atPath: tagged.path) { try await tagLight(source, light, to: tagged) }
                        source = tagged
                    }
                    try await NativeMovieRenderer.developClip(source: source, destination: clip,
                        camera: camera, filmStock: filmStock, seed: seed, orientation: .landscape)
                    _ = try await VerifiedMedia.movie(at: clip)
                    manifest.files.append(Rendered(camera: camera.id.rawValue, filmStock: filmStock?.rawValue, scene: scene.id,
                        kind: "clip", path: "\(folder)/\(scene.id).mov", seed: seed, version: NativePhotoRenderer.treatmentVersion))
                }
            }
        }
        try FileManager.default.removeItem(at: work)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(manifest).write(to: output.appendingPathComponent("manifest.json"))
        print("LOOK_BOARDS files=\(manifest.files.count) treatment=\(NativePhotoRenderer.treatmentVersion) output=\(output.path)")
    }

    /// A display copy, at most `displayEdge` on its long side.
    static func writeDisplay(_ image: CIImage, to url: URL) throws {
        let scale = min(1, displayEdge / max(image.extent.width, image.extent.height))
        try writeJPEG(image.transformed(by: CGAffineTransform(scaleX: scale, y: scale)), to: url)
    }

    /// A 640-pixel square from the middle of the picture at full size, where grain and softness show as they are.
    static func writeCrop(_ image: CIImage, to url: URL) throws {
        let side: CGFloat = 640
        let crop = image.cropped(to: CGRect(x: image.extent.midX - side / 2, y: image.extent.midY - side / 2, width: side, height: side))
        try writeJPEG(crop.transformed(by: CGAffineTransform(translationX: -crop.extent.minX, y: -crop.extent.minY)), to: url)
    }

    static func writeJPEG(_ image: CIImage, to url: URL) throws {
        guard let data = CIContext().jpegRepresentation(of: image, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, options: [
            kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.9
        ]) else { throw BoardError.writeFailed }
        try data.write(to: url)
    }

    static func tagFlash(_ source: URL, to destination: URL) throws {
        guard let input = CGImageSourceCreateWithURL(source as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(input, 0, nil),
              let output = CGImageDestinationCreateWithURL(destination as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw BoardError.invalidSource
        }
        var properties = (CGImageSourceCopyPropertiesAtIndex(input, 0, nil) as? [CFString: Any]) ?? [:]
        var exif = (properties[kCGImagePropertyExifDictionary] as? [CFString: Any]) ?? [:]
        exif[kCGImagePropertyExifFlash] = 1
        properties[kCGImagePropertyExifDictionary] = exif
        properties[kCGImageDestinationLossyCompressionQuality] = 0.95
        CGImageDestinationAddImage(output, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(output) else { throw BoardError.writeFailed }
    }

    /// The clip with the light it was recorded in, as the capture writes it.
    static func tagLight(_ source: URL, _ light: SceneWhiteBalance, to destination: URL) async throws {
        guard let export = AVAssetExportSession(asset: AVURLAsset(url: source), presetName: AVAssetExportPresetPassthrough) else {
            throw BoardError.writeFailed
        }
        export.metadata = [lightItem(light)]
        try await export.export(to: destination, as: .mov)
    }

    static func lightItem(_ light: SceneWhiteBalance) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.keySpace = .quickTimeMetadata
        item.key = SceneWhiteBalance.metadataKey as NSString
        item.value = light.metadataValue as NSString
        item.dataType = kCMMetadataBaseDataType_UTF8 as String
        return item
    }

    /// Two seconds at 30 fps of the still, filling a 4:3 landscape frame, with the light it was lit by when known.
    static func writeStillClip(_ source: URL, to destination: URL, light: SceneWhiteBalance?) async throws {
        guard let image = CIImage(contentsOf: source, options: [.applyOrientationProperty: true]) else { throw BoardError.invalidSource }
        let width = 1920, height = 1440, fps = 30
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        let scale = max(bounds.width / image.extent.width, bounds.height / image.extent.height)
        let scaled = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let framed = scaled.transformed(by: CGAffineTransform(translationX: (bounds.width - scaled.extent.width) / 2,
                                                              y: (bounds.height - scaled.extent.height) / 2)).cropped(to: bounds)
        let writer = try AVAssetWriter(outputURL: destination, fileType: .mov)
        if let light { writer.metadata = [lightItem(light)] }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width, AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 20_000_000]])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height])
        writer.add(input)
        guard writer.startWriting() else { throw BoardError.writeFailed }
        writer.startSession(atSourceTime: .zero)
        let context = CIContext()
        for frame in 0..<(fps * 2) {
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(2)) }
            var buffer: CVPixelBuffer?
            guard let pool = adaptor.pixelBufferPool,
                  CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess, let buffer else { throw BoardError.writeFailed }
            context.render(framed, to: buffer, bounds: bounds, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
            guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: Int32(fps))) else {
                throw BoardError.writeFailed
            }
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw BoardError.writeFailed }
    }

    static func frameImage(_ url: URL, index: Int) async throws -> CIImage {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw BoardError.invalidSource }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        reader.add(output)
        guard reader.startReading() else { throw BoardError.invalidSource }
        defer { reader.cancelReading() }
        var count = 0
        while let sample = output.copyNextSampleBuffer() {
            if count == index, let buffer = CMSampleBufferGetImageBuffer(sample) {
                // Copy the pixels out before the reader recycles the buffer.
                let image = CIImage(cvPixelBuffer: buffer)
                guard let cgImage = CIContext().createCGImage(image, from: image.extent) else { throw BoardError.invalidSource }
                return CIImage(cgImage: cgImage)
            }
            count += 1
        }
        throw BoardError.invalidSource
    }
}

enum BoardError: Error { case usage, destinationExists, invalidSource, writeFailed }
