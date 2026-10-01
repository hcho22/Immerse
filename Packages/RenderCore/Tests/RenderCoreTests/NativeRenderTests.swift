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
        XCTAssertEqual(decoded.height, 480)
        let edited = try NativePhotoRenderer.print(
            master: master, recipe: DarkroomRecipe(printExposureStops: 0.7, contrastGrade: 3,
                colorFiltration: ColorFiltration(cyan: 8, magenta: -3, yellow: 5),
                crop: Crop(x: 0.25, y: 0.25, width: 0.5, height: 0.5),
                dodgeBurnMasks: [LocalMask(kind: .burn, points: [MaskPoint(x: 0.5, y: 0.5)], exposureStops: 0.5)]),
            camera: CameraCatalog.disposable1990s
        )
        XCTAssertNotEqual(master, edited)
        XCTAssertEqual(try image(edited).width, 320)
        XCTAssertEqual(try image(edited).height, 240)
        XCTAssertEqual(try NativePhotoRenderer.print(master: master, recipe: .original, camera: CameraCatalog.disposable1990s), master)
        XCTAssertThrowsError(try NativePhotoRenderer.print(master: master,
            recipe: DarkroomRecipe(printExposureStops: .nan), camera: CameraCatalog.disposable1990s))
        XCTAssertThrowsError(try NativePhotoRenderer.print(master: master, recipe: .original, camera: CameraCatalog.cinema16mm))
    }

    func testSquareCameraOutputsAndBoundedDifferentTreatments() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try await RenderFixtureGenerator.writeFixtures(outputDirectory: root)
        let source = root.appendingPathComponent("synthetic-developed-photo.jpg")
        let instant = try NativePhotoRenderer.develop(source: source, camera: CameraCatalog.instant1970s, seed: 19)
        let square = try NativePhotoRenderer.develop(source: source, camera: CameraCatalog.mediumFormat6x6, seed: 19)
        XCTAssertEqual(try image(instant).width, 2048)
        XCTAssertEqual(try image(instant).height, 2048)
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
        XCTAssertEqual(clipMetadata.encodedHeight, 180)
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
        let secondFrames = try await decodedFrames(second)
        let assembledFrames = try await decodedFrames(movie)
        XCTAssertGreaterThan(firstFrames.count, 1)
        XCTAssertEqual(assembledFrames, firstFrames + secondFrames)
        let surviving = root.appendingPathComponent("surviving.mov")
        try await NativeMovieRenderer.assemble(clips: [second], destination: surviving)
        let survivingFrames = try await decodedFrames(surviving)
        XCTAssertEqual(survivingFrames, secondFrames)
    }

    private func image(_ data: Data) throws -> CGImage {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        return try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary))
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
        XCTAssertTrue(reader.startReading())
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
        XCTAssertEqual(reader.status, .completed)
        return result
    }

    private func makeRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("NativeRenderTests-\(UUID())")
    }
}
