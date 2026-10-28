@preconcurrency import AVFoundation
import FilmDomain
import Foundation
import ImageIO
import RenderCore
import RenderFixtures
import XCTest

final class NativeRenderTests: XCTestCase {
    func testRealPhotoTreatmentRepeatsAndResetReturnsExactMasterBytes() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try await RenderFixtureGenerator.writeFixtures(outputDirectory: root)
        let source = root.appendingPathComponent("synthetic-developed-photo.jpg")
        let master = try NativePhotoRenderer.develop(source: source, camera: CameraCatalog.disposable1990s, seed: 42)
        let again = try NativePhotoRenderer.develop(source: source, camera: CameraCatalog.disposable1990s, seed: 42)
        XCTAssertEqual(master, again)
        XCTAssertNotEqual(master, try Data(contentsOf: source))
        let decoded = try image(master)
        XCTAssertEqual(decoded.width, 640)
        XCTAssertEqual(decoded.height, 426, "The Disposable's 4:3 capture develops as a borderless 3:2 picture")
        let edited = try NativePhotoRenderer.print(
            master: master, recipe: DarkroomRecipe(printExposureStops: 0.7, contrastGrade: 3,
                colorFiltration: ColorFiltration(cyan: 8, magenta: -3, yellow: 5),
                crop: Crop(x: 0.25, y: 0.25, width: 0.5, height: 0.5),
                dodgeBurnMasks: [LocalMask(kind: .burn, points: [MaskPoint(x: 0.5, y: 0.5)], exposureStops: 0.5)]),
            camera: CameraCatalog.disposable1990s
        )
        XCTAssertNotEqual(master, edited)
        XCTAssertEqual(try image(edited).width, 320)
        XCTAssertEqual(try image(edited).height, 214, "Half of the 426 rows, rounded out to whole pixels")
        XCTAssertEqual(try NativePhotoRenderer.print(master: master, recipe: .original, camera: CameraCatalog.disposable1990s), master)
        XCTAssertThrowsError(try NativePhotoRenderer.print(master: master,
            recipe: DarkroomRecipe(printExposureStops: .nan), camera: CameraCatalog.disposable1990s))
        XCTAssertThrowsError(try NativePhotoRenderer.print(master: master, recipe: .original, camera: CameraCatalog.cinema16mm))
    }

    func testDisposableDevelopsEveryCaptureShapeAsABorderlessThreeByTwoAtTheTwelveMegapixelLimit() async throws {
        for (width, height, expected) in [
            (640, 480, (640, 426)),      // the phone's 4:3 landscape capture keeps its long side
            (480, 640, (426, 640)),      // portrait develops 2:3
            (1280, 720, (1080, 720)),    // a wider source keeps its short side
            (4032, 3024, (4032, 2688)),  // a real 12 MP capture stays under the master limit uncropped in size
            (6000, 8000, (2828, 4242))   // a larger source is scaled to whole pixels within 12 MP after the crop
        ] {
            let root = makeRoot()
            defer { try? FileManager.default.removeItem(at: root) }
            var settings = RenderFixtureSettings.defaultExperimental
            settings.photoWidth = width
            settings.photoHeight = height
            _ = try await RenderFixtureGenerator.writeFixtures(outputDirectory: root, settings: settings)
            let source = root.appendingPathComponent("synthetic-developed-photo.jpg")
            let developed = try image(try NativePhotoRenderer.develop(source: source, camera: CameraCatalog.disposable1990s, seed: 5))
            XCTAssertEqual(developed.width, expected.0, "\(width)x\(height)")
            XCTAssertEqual(developed.height, expected.1, "\(width)x\(height)")
            XCTAssertLessThanOrEqual(developed.width * developed.height, DevelopedPhotoSize.disposableMaximumPixels,
                                     "Never more than 12,000,000 pixels (DEC-04)")
            // Every pixel row and column is picture: the grain tile covers the whole frame and nothing is stamped on it.
            let ratio = Double(max(developed.width, developed.height)) / Double(min(developed.width, developed.height))
            XCTAssertEqual(ratio, 1.5, accuracy: 0.01)
        }
    }

    func testOtherPhotoCamerasKeepTheirShapes() async throws {
        try requireTetrahedralReader()
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        var settings = RenderFixtureSettings.defaultExperimental
        settings.photoWidth = 480
        settings.photoHeight = 640
        _ = try await RenderFixtureGenerator.writeFixtures(outputDirectory: root, settings: settings)
        let source = root.appendingPathComponent("synthetic-developed-photo.jpg")
        let instant = try image(try NativePhotoRenderer.develop(source: source, camera: CameraCatalog.instant1970s, seed: 5))
        let square = try image(try NativePhotoRenderer.develop(source: source, camera: CameraCatalog.mediumFormat6x6, seed: 5))
        // The 2048 x 2048 picture on its white card.
        XCTAssertEqual([instant.width, instant.height], [InstantPrintCard.width, InstantPrintCard.height])
        XCTAssertEqual([square.width, square.height], [3072, 3072])
    }

    func testSquareCameraOutputsAndBoundedDifferentTreatments() async throws {
        try requireTetrahedralReader()
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try await RenderFixtureGenerator.writeFixtures(outputDirectory: root)
        let source = root.appendingPathComponent("synthetic-developed-photo.jpg")
        let instant = try NativePhotoRenderer.develop(source: source, camera: CameraCatalog.instant1970s, seed: 19)
        let square = try NativePhotoRenderer.develop(source: source, camera: CameraCatalog.mediumFormat6x6, seed: 19)
        // The 2048 x 2048 picture sits on its white card (InstantPrintCardTests checks the pixels).
        XCTAssertEqual(try image(instant).width, InstantPrintCard.width)
        XCTAssertEqual(try image(instant).height, InstantPrintCard.height)
        XCTAssertEqual(InstantPrintCard.pictureSide, 2048)
        XCTAssertEqual(try image(square).width, 3072)
        XCTAssertEqual(try image(square).height, 3072)
        XCTAssertThrowsError(try NativePhotoRenderer.print(master: square,
            recipe: DarkroomRecipe(crop: Crop(x: 0, y: 0, width: 0.5, height: 0.8)), camera: CameraCatalog.mediumFormat6x6))
    }

    func testNativeMoviesKeepLockedPresentationDurationAndSilentChronologicalAssembly() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        var settings = RenderFixtureSettings.defaultExperimental
        settings.movieWidth = 160
        settings.movieHeight = 96
        settings.movieDurationSeconds = 0.4
        settings.movieOrientation = .portrait
        let manifest = try await RenderFixtureGenerator.writeFixtures(outputDirectory: root, settings: settings)
        let source = root.appendingPathComponent("synthetic-developed-movie.mov")
        let first = root.appendingPathComponent("first.mov")
        let second = root.appendingPathComponent("second.mov")
        for (index, url) in [first, second].enumerated() {
            try await NativeMovieRenderer.developClip(source: source, destination: url, camera: CameraCatalog.super8HomeMovie,
                seed: UInt64(index + 4), orientation: .landscape, longEdge: 320)
        }
        let clipMetadata = try await RenderFixtureGenerator.inspectMovie(at: first, relativePath: "first.mov", orientation: .landscape)
        XCTAssertEqual(clipMetadata.encodedWidth, 320)
        XCTAssertEqual(clipMetadata.encodedHeight, 240)
        XCTAssertEqual(clipMetadata.preferredTransform, TransformMetadata(.identity))
        XCTAssertEqual(clipMetadata.durationSeconds, manifest.movie.durationSeconds, accuracy: 0.01)
        let movie = root.appendingPathComponent("movie.mov")
        try await NativeMovieRenderer.assemble(clips: [first, second], destination: movie)
        let assembled = AVURLAsset(url: movie)
        let audio = try await assembled.loadTracks(withMediaType: .audio)
        let total = try await assembled.load(.duration).seconds
        XCTAssertTrue(audio.isEmpty)
        XCTAssertEqual(total, manifest.movie.durationSeconds * 2, accuracy: 0.01)
        let firstFrames = try await decodedFrames(first)
        let firstPixels = try XCTUnwrap(firstFrames.first)
        // Portrait source fits the 4:3 output with side borders, not a crop/stretch.
        XCTAssertLessThan(firstPixels[(120 * 320 + 8) * 4], 40)
        XCTAssertGreaterThan(firstPixels[(120 * 320 + 160) * 4], 40)
        // Upright, the source's dark top-left corner sits at the top right and its bright
        // bottom-right corner at the bottom left, as a player shows the portrait clip.
        func brightness(x: Int, y: Int) -> Int { (0..<3).reduce(0) { $0 + Int(firstPixels[(y * 320 + x) * 4 + $1]) } }
        XCTAssertLessThan(brightness(x: 210, y: 30) + 150, brightness(x: 110, y: 210))
        let secondFrames = try await decodedFrames(second)
        let assembledFrames = try await decodedFrames(movie)
        XCTAssertGreaterThan(firstFrames.count, 1)
        XCTAssertEqual(assembledFrames, firstFrames + secondFrames)
        let surviving = root.appendingPathComponent("surviving.mov")
        try await NativeMovieRenderer.assemble(clips: [second], destination: surviving)
        let survivingFrames = try await decodedFrames(surviving)
        XCTAssertEqual(survivingFrames, secondFrames)
    }

    func testLiveSoundPassesThroughDevelopmentAndAssemblyAndOldPackagesRejectIt() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        var settings = RenderFixtureSettings.defaultExperimental
        settings.movieWidth = 160
        settings.movieHeight = 120
        settings.movieDurationSeconds = 0.4
        let manifest = try await RenderFixtureGenerator.writeFixtures(outputDirectory: root, settings: settings)
        // A source shaped like a capture: picture and AAC sound written together by AVAssetWriter from time zero.
        let source = root.appendingPathComponent("captured-with-sound.mov")
        try await Self.capturedMovie(at: source, seconds: manifest.movie.durationSeconds)

        let developed = root.appendingPathComponent("developed.mov")
        try await NativeMovieRenderer.developClip(source: source, destination: developed,
            camera: CameraCatalog.super8HomeMovie, seed: 17, orientation: .landscape, longEdge: 320)
        let sourceSamples = try await decodedAudioSamples(source)
        let developedSamples = try await decodedAudioSamples(developed)
        let developedAsset = AVURLAsset(url: developed)
        let developedAudio = try await developedAsset.loadTracks(withMediaType: .audio)
        XCTAssertFalse(sourceSamples.isEmpty)
        XCTAssertEqual(developedAudio.count, 1)
        let sourceFormat = try await Self.audioFormat(source)
        let developedFormat = try await Self.audioFormat(developed)
        // The developed sound keeps the format it was captured in, whatever the iPhone recorded (DEC-19).
        XCTAssertEqual(CMFormatDescriptionGetMediaSubType(developedFormat), CMFormatDescriptionGetMediaSubType(sourceFormat))
        XCTAssertEqual(try Self.streamDescription(developedFormat).mSampleRate,
                       try Self.streamDescription(sourceFormat).mSampleRate)
        XCTAssertEqual(try Self.streamDescription(developedFormat).mChannelsPerFrame,
                       try Self.streamDescription(sourceFormat).mChannelsPerFrame)
        // The clip lasts until the recording stopped, its last whole frame held there, and its sound runs to that same
        // end, so a Movie has no silence where one clip meets the next; only the sound past the picture is cut.
        let sourceVideo = try await AVURLAsset(url: source).loadTracks(withMediaType: .video)
        let pictureSeconds = try await XCTUnwrap(sourceVideo.first).load(.timeRange).duration.seconds
        let wholeFrames = DevelopedMovieFormat.frameCount(seconds: pictureSeconds, camera: .super8HomeMovie)
        XCTAssertLessThan(Double(wholeFrames) / 18, pictureSeconds - 0.005, "The recording stops part way through a frame")
        let clipSeconds = try await developedAsset.load(.duration).seconds
        XCTAssertEqual(clipSeconds, pictureSeconds, accuracy: 1.0 / 600)
        let developedRange = try await XCTUnwrap(developedAudio.first).load(.timeRange)
        XCTAssertEqual(developedRange.start.seconds, 0, accuracy: 1.0 / 600)
        XCTAssertEqual(developedRange.end.seconds, clipSeconds, accuracy: 1.0 / 600,
                       "The developed sound runs to where the recording stopped")
        XCTAssertLessThan(developedSamples.count, sourceSamples.count, "The sound past the picture's end is cut")
        XCTAssertEqual(developedSamples, sourceSamples.prefix(developedSamples.count),
                       "Development keeps the original sound samples without treatment")

        let assembled = root.appendingPathComponent("assembled.mov")
        try await NativeMovieRenderer.assemble(clips: [developed], destination: assembled, includeRecordedSound: true)
        let assembledAsset = AVURLAsset(url: assembled)
        let assembledAudio = try await assembledAsset.loadTracks(withMediaType: .audio)
        let assembledDuration = try await assembledAsset.load(.duration).seconds
        XCTAssertEqual(assembledAudio.count, 1)
        let assembledFormat = try await Self.audioFormat(assembled)
        XCTAssertEqual(CMFormatDescriptionGetMediaSubType(assembledFormat), CMFormatDescriptionGetMediaSubType(developedFormat))
        XCTAssertEqual(try Self.streamDescription(assembledFormat).mSampleRate,
                       try Self.streamDescription(developedFormat).mSampleRate)
        XCTAssertEqual(try Self.streamDescription(assembledFormat).mChannelsPerFrame,
                       try Self.streamDescription(developedFormat).mChannelsPerFrame)
        XCTAssertEqual(assembledDuration, clipSeconds, accuracy: 1.0 / 600)
        let assembledRange = try await XCTUnwrap(assembledAudio.first).load(.timeRange)
        XCTAssertEqual(assembledRange.end.seconds, assembledDuration, accuracy: 1.0 / 600,
                       "The Movie's recorded sound runs to the clip's last frame")

        let oldPackage = CameraPackage(id: .cinema16mm, displayName: "16mm Cinema", medium: .movie,
                                       capacity: .seconds(165), revealRule: .movieDevelopment,
                                       supportsBuiltInSoundtrack: true)
        do {
            try await NativeMovieRenderer.developClip(source: source, destination: root.appendingPathComponent("old.mov"),
                camera: oldPackage, seed: 17, orientation: .landscape, longEdge: 320)
            XCTFail("An earlier stored Camera package must refuse source sound")
        } catch { }
    }

    /// A clip with several seconds of recorded sound develops completely (FR-27): every whole frame, and its sound to
    /// the clip's end, however far the writer lets the picture run ahead of the sound.
    func testAClipWithSeveralSecondsOfSoundDevelopsEveryFrameAndAllOfItsSound() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("captured-with-sound.mov")
        try await Self.capturedMovie(at: source, seconds: 4)

        let developed = root.appendingPathComponent("developed.mov")
        try await NativeMovieRenderer.developClip(source: source, destination: developed,
            camera: CameraCatalog.super8HomeMovie, seed: 17, orientation: .landscape, longEdge: 320)
        let sourceVideo = try await AVURLAsset(url: source).loadTracks(withMediaType: .video)
        let pictureSeconds = try await XCTUnwrap(sourceVideo.first).load(.timeRange).duration.seconds
        let wholeFrames = DevelopedMovieFormat.frameCount(seconds: pictureSeconds, camera: .super8HomeMovie)
        XCTAssertGreaterThan(wholeFrames, 18 * 3)
        let frames = try await decodedFrames(developed)
        XCTAssertEqual(frames.count, wholeFrames, "Every whole frame of the clip is developed")
        let developedAudio = try await AVURLAsset(url: developed).loadTracks(withMediaType: .audio)
        let developedRange = try await XCTUnwrap(developedAudio.first).load(.timeRange)
        let clipSeconds = try await AVURLAsset(url: developed).load(.duration).seconds
        XCTAssertEqual(developedRange.start.seconds, 0, accuracy: 1.0 / 600)
        XCTAssertEqual(developedRange.end.seconds, clipSeconds, accuracy: 1.0 / 600, "The sound runs to the clip's end")
        let sourceSamples = try await decodedAudioSamples(source)
        let developedSamples = try await decodedAudioSamples(developed)
        XCTAssertEqual(developedSamples, sourceSamples.prefix(developedSamples.count),
                       "Development keeps the original sound samples without treatment")
    }

    func testBothMovieCamerasUsePortraitThreeByFourWithLetterboxedLandscape() async throws {
        try requireTetrahedralReader()
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        var settings = RenderFixtureSettings.defaultExperimental
        settings.movieWidth = 160
        settings.movieHeight = 120
        settings.movieDurationSeconds = 0.2
        settings.movieOrientation = .landscape
        _ = try await RenderFixtureGenerator.writeFixtures(outputDirectory: root, settings: settings)
        let source = root.appendingPathComponent("synthetic-developed-movie.mov")
        for camera in [CameraCatalog.super8HomeMovie, CameraCatalog.cinema16mm] {
            let result = root.appendingPathComponent("\(camera.id.rawValue).mov")
            try await NativeMovieRenderer.developClip(source: source, destination: result,
                camera: camera, seed: 7, orientation: .portrait, longEdge: 160)
            let metadata = try await RenderFixtureGenerator.inspectMovie(at: result,
                relativePath: result.lastPathComponent, orientation: .portrait)
            XCTAssertEqual(metadata.encodedWidth, 120)
            XCTAssertEqual(metadata.encodedHeight, 160)
            XCTAssertEqual(metadata.preferredTransform, TransformMetadata(.identity))
            guard metadata.encodedWidth == 120, metadata.encodedHeight == 160 else { continue }
            let frames = try await decodedFrames(result)
            let pixels = try XCTUnwrap(frames.first)
            XCTAssertLessThan(pixels[(8 * 120 + 60) * 4], 40)
            XCTAssertLessThan(pixels[(151 * 120 + 60) * 4], 40)
            XCTAssertGreaterThan(pixels[(80 * 120 + 60) * 4], 40)
        }
    }

    private func image(_ data: Data) throws -> CGImage {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        return try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary))
    }

    private static func addAudio(_ audioURL: URL, to videoURL: URL, destination: URL) async throws {
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

    /// A movie shaped like a capture, as `AVCaptureMovieFileOutput` writes one: an H.264 picture at 30 frames per second
    /// and AAC sound at 48 kHz in stereo, written together by `AVAssetWriter` from time zero, the sound a 440 Hz tone
    /// that runs a frame past the last picture frame, as a capture's sound can.
    static func capturedMovie(at url: URL, seconds: Double, width: Int = 160, height: Int = 120) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let video = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height
        ])
        video.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: video, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height
        ])
        var layout = AudioChannelLayout()
        layout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo
        let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 48_000, AVNumberOfChannelsKey: 2,
            AVChannelLayoutKey: Data(bytes: &layout, count: MemoryLayout<AudioChannelLayout>.size)
        ])
        audio.expectsMediaDataInRealTime = false
        writer.add(video)
        writer.add(audio)
        XCTAssertTrue(writer.startWriting())
        writer.startSession(atSourceTime: .zero)

        var pcm = AudioStreamBasicDescription(
            mSampleRate: 48_000, mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked,
            mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4, mChannelsPerFrame: 2, mBitsPerChannel: 16,
            mReserved: 0)
        var soundFormat: CMAudioFormatDescription?
        CMAudioFormatDescriptionCreate(allocator: nil, asbd: &pcm, layoutSize: 0, layout: nil, magicCookieSize: 0,
                                       magicCookie: nil, extensions: nil, formatDescriptionOut: &soundFormat)
        let frames = Int((seconds * 30).rounded())
        let samples = (frames + 1) * 1_600
        var frame = 0
        var written = 0
        // Each input takes the next picture frame or sound packet whenever it is ready, as a capture's are, so the
        // writer interleaves them however far either runs ahead.
        while frame < frames || written < samples {
            var appended = false
            if frame < frames, video.isReadyForMoreMediaData {
                var buffer: CVPixelBuffer?
                CVPixelBufferPoolCreatePixelBuffer(nil, try XCTUnwrap(adaptor.pixelBufferPool), &buffer)
                let pixels = try XCTUnwrap(buffer)
                CVPixelBufferLockBaseAddress(pixels, [])
                let shade = Int32(40 + frame * 7 % 180)
                memset(CVPixelBufferGetBaseAddress(pixels), shade, CVPixelBufferGetDataSize(pixels))
                CVPixelBufferUnlockBaseAddress(pixels, [])
                XCTAssertTrue(adaptor.append(pixels, withPresentationTime: CMTime(value: Int64(frame), timescale: 30)))
                frame += 1
                if frame == frames { video.markAsFinished() }
                appended = true
            }
            if written < samples, audio.isReadyForMoreMediaData {
                let count = min(1_024, samples - written)
                var bytes = Data(count: count * 4)
                bytes.withUnsafeMutableBytes { raw in
                    let values = raw.bindMemory(to: Int16.self)
                    for index in 0..<count {
                        let phase: Double = Double(written + index) * 2 * Double.pi * 440 / 48_000
                        let value = Int16(sin(phase) * 4_000)
                        values[index * 2] = value
                        values[index * 2 + 1] = value
                    }
                }
                var block: CMBlockBuffer?
                CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: nil, blockLength: bytes.count,
                                                   blockAllocator: nil, customBlockSource: nil, offsetToData: 0,
                                                   dataLength: bytes.count, flags: 0, blockBufferOut: &block)
                let blockBuffer = try XCTUnwrap(block)
                _ = bytes.withUnsafeBytes { CMBlockBufferReplaceDataBytes(with: $0.baseAddress!, blockBuffer: blockBuffer,
                                                                          offsetIntoDestination: 0, dataLength: bytes.count) }
                var sample: CMSampleBuffer?
                CMAudioSampleBufferCreateReadyWithPacketDescriptions(
                    allocator: nil, dataBuffer: blockBuffer, formatDescription: try XCTUnwrap(soundFormat),
                    sampleCount: count, presentationTimeStamp: CMTime(value: Int64(written), timescale: 48_000),
                    packetDescriptions: nil, sampleBufferOut: &sample)
                XCTAssertTrue(audio.append(try XCTUnwrap(sample)))
                written += count
                if written == samples { audio.markAsFinished() }
                appended = true
            }
            if !appended { try await Task.sleep(for: .milliseconds(1)) }
        }
        await writer.finishWriting()
        XCTAssertEqual(writer.status, .completed, "\(String(describing: writer.error))")
    }

    private static func encodeAAC(_ audioURL: URL, destination: URL) async throws {
        let asset = AVURLAsset(url: audioURL)
        let exporter = try XCTUnwrap(AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A))
        try await exporter.export(to: destination, as: .m4a)
    }

    private static func audioFormat(_ url: URL) async throws -> CMFormatDescription {
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        let track = try XCTUnwrap(tracks.first)
        let formats = try await track.load(.formatDescriptions)
        return try XCTUnwrap(formats.first)
    }

    private static func streamDescription(_ format: CMFormatDescription) throws -> AudioStreamBasicDescription {
        try XCTUnwrap(CMAudioFormatDescriptionGetStreamBasicDescription(format)?.pointee)
    }

    private func decodedAudioSamples(_ url: URL) async throws -> Data {
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        let track = try XCTUnwrap(tracks.first)
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM])
        guard reader.canAdd(output) else { throw NativeRenderError.invalidMovie() }
        reader.add(output)
        guard reader.startReading() else { throw NativeRenderError.invalidMovie(underlying: reader.error as NSError?) }
        var result = Data()
        while let sample = output.copyNextSampleBuffer() {
            guard let block = CMSampleBufferGetDataBuffer(sample) else { throw NativeRenderError.invalidMovie() }
            let length = CMBlockBufferGetDataLength(block)
            var bytes = Data(count: length)
            let status = bytes.withUnsafeMutableBytes { buffer in
                CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: buffer.baseAddress!)
            }
            guard status == kCMBlockBufferNoErr else { throw NativeRenderError.invalidMovie() }
            result.append(bytes)
        }
        guard reader.status == .completed else { throw NativeRenderError.invalidMovie(underlying: reader.error as NSError?) }
        return result
    }

    private static func wave() -> Data {
        let rate: UInt32 = 48_000
        let samples = Int(rate / 2)
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

    private func decodedFrames(_ url: URL) async throws -> [Data] {
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let track = try XCTUnwrap(tracks.first)
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        reader.add(output)
        XCTAssertTrue(reader.startReading(), reader.failureDescription(framesRead: 0))
        var result: [Data] = []
        while let sample = output.copyNextSampleBuffer() {
            let buffer = try XCTUnwrap(CMSampleBufferGetImageBuffer(sample))
            CVPixelBufferLockBaseAddress(buffer, .readOnly)
            let base = try XCTUnwrap(CVPixelBufferGetBaseAddress(buffer))
            var pixels = Data()
            for row in 0..<CVPixelBufferGetHeight(buffer) {
                pixels.append(Data(bytes: base.advanced(by: row * CVPixelBufferGetBytesPerRow(buffer)), count: CVPixelBufferGetWidth(buffer) * 4))
            }
            CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
            result.append(pixels)
        }
        XCTAssertEqual(reader.status, .completed, reader.failureDescription(framesRead: result.count))
        return result
    }

    private func makeRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("NativeRenderTests-\(UUID())")
    }
}
