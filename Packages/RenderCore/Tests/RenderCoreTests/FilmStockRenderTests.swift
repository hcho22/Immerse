@preconcurrency import AVFoundation
import CoreGraphics
import CoreImage
import FilmDomain
import Foundation
import ImageIO
@testable import RenderCore
import RenderFixtures
import UniformTypeIdentifiers
import XCTest

/// The 6×6 Medium Format and the 16mm Cinema develop with one treatment per Film Stock (ADR 0014, PRD 2.1 section 6).
/// Black-and-white is its own monochrome rendering with high contrast and distinct grain, not the color look
/// desaturated, and color stays exactly as before. Values are provisional (DEC-04); these tests hold the character,
/// not the numbers.
final class FilmStockRenderTests: XCTestCase {
    private var root: URL!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("FilmStockRenderTests-\(UUID())")
        var settings = RenderFixtureSettings.defaultExperimental
        settings.movieWidth = 160
        settings.movieHeight = 96
        settings.movieDurationSeconds = 0.4
        _ = try await RenderFixtureGenerator.writeFixtures(outputDirectory: root, settings: settings)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
    }

    private var photo: URL { root.appendingPathComponent("synthetic-developed-photo.jpg") }
    private var movie: URL { root.appendingPathComponent("synthetic-developed-movie.mov") }

    func testBlackAndWhiteSixBySixDevelopsAMonochromeSquareMaster() throws {
        let camera = CameraCatalog.mediumFormat6x6
        let master = try NativePhotoRenderer.develop(source: photo, camera: camera, seed: 42, filmStock: .blackAndWhite)
        XCTAssertEqual(master, try NativePhotoRenderer.develop(source: photo, camera: camera, seed: 42, filmStock: .blackAndWhite))
        let pixels = try DecodedPixels(master)
        XCTAssertEqual(pixels.width, 3072)
        XCTAssertEqual(pixels.height, 3072)
        XCTAssertLessThanOrEqual(pixels.largestChannelSpread, 2, "Every pixel is neutral gray")
        let color = try DecodedPixels(NativePhotoRenderer.develop(source: photo, camera: camera, seed: 42, filmStock: .color))
        XCTAssertGreaterThan(color.largestChannelSpread, 40, "The color Film Stock keeps its color")
    }

    /// The black-and-white treatment starts from the capture's light, not from the color look: its tones differ from
    /// the color master's, desaturated, and it is higher in contrast.
    func testBlackAndWhiteIsHigherContrastAndNotTheColorLookDesaturated() throws {
        let camera = CameraCatalog.mediumFormat6x6
        let mono = try DecodedPixels(NativePhotoRenderer.develop(source: photo, camera: camera, seed: 42, filmStock: .blackAndWhite))
        let color = try DecodedPixels(NativePhotoRenderer.develop(source: photo, camera: camera, seed: 42, filmStock: .color))
        XCTAssertGreaterThan(mono.luminanceDeviation, color.luminanceDeviation * 1.1,
                             "Black-and-white spreads its tones further than the color look (\(mono.luminanceDeviation) vs \(color.luminanceDeviation))")
        XCTAssertGreaterThan(mono.meanLuminanceDifference(from: color), 6,
                             "Black-and-white tones are not the color master's luminance")
    }

    /// On an even mid-gray scene, the grain is all there is to see: black-and-white grain is coarser and stronger than
    /// the color Film Stock's very fine grain, and it is gray.
    func testBlackAndWhiteGrainIsDistinctOnAnEvenScene() throws {
        let gray = root.appendingPathComponent("mid-gray.png")
        try writeEvenGray(to: gray, side: 1024)
        let camera = CameraCatalog.mediumFormat6x6
        let mono = try DecodedPixels(NativePhotoRenderer.develop(source: gray, camera: camera, seed: 9, filmStock: .blackAndWhite))
        let color = try DecodedPixels(NativePhotoRenderer.develop(source: gray, camera: camera, seed: 9, filmStock: .color))
        XCTAssertLessThanOrEqual(mono.largestChannelSpread, 2)
        XCTAssertGreaterThan(mono.centerDeviation, color.centerDeviation * 2,
                             "Grain on an even scene (\(mono.centerDeviation) vs \(color.centerDeviation))")
        // Clearly visible on its own, not just next to the color stock's very fine grain; the provisional values give about 8.
        XCTAssertGreaterThan(mono.centerDeviation, 4)
    }

    /// The black-and-white print curve pivots on display mid-gray: an even mid-gray scene keeps its tone through the
    /// whole black-and-white chain, with and without grain, while darker tones print darker and lighter tones lighter.
    func testBlackAndWhiteKeepsDisplayMidGrayWithAndWithoutGrain() {
        for camera in [CameraID.mediumFormat6x6, .cinema16mm] {
            guard case let .monochrome(look) = FilmLook.treatment(camera: camera, filmStock: .blackAndWhite) else {
                return XCTFail("\(camera) has no black-and-white treatment")
            }
            let clean = FilmLook.Monochrome(spectral: look.spectral, curve: look.curve, grainAmplitude: 0, grainSize: look.grainSize)
            XCTAssertEqual(meanLevel(FilmLook.monochrome(evenGray(128), clean, seed: 9, frame: 0)), 128, accuracy: 3,
                           "\(camera) without grain")
            XCTAssertEqual(meanLevel(FilmLook.monochrome(evenGray(128), look, seed: 9, frame: 0)), 128, accuracy: 3,
                           "\(camera) with grain")
            XCTAssertLessThan(meanLevel(FilmLook.monochrome(evenGray(64), clean, seed: 9, frame: 0)), 64 - 10,
                              "\(camera) prints a dark tone darker")
            XCTAssertGreaterThan(meanLevel(FilmLook.monochrome(evenGray(192), clean, seed: 9, frame: 0)), 192 + 10,
                                 "\(camera) prints a light tone lighter")
        }
    }

    /// Color development of the two Cameras is unchanged by Film Stock: the color Film Stock and a Film loaded before
    /// Film Stock existed develop the same master, byte for byte.
    func testColorFilmStockDevelopsExactlyAsAFilmWithoutOne() async throws {
        let camera = CameraCatalog.mediumFormat6x6
        XCTAssertEqual(try NativePhotoRenderer.develop(source: photo, camera: camera, seed: 42, filmStock: .color),
                       try NativePhotoRenderer.develop(source: photo, camera: camera, seed: 42))
        let withStock = root.appendingPathComponent("color.mov"), without = root.appendingPathComponent("none.mov")
        try await NativeMovieRenderer.developClip(source: movie, destination: withStock, camera: CameraCatalog.cinema16mm,
            filmStock: .color, seed: 7, orientation: .landscape, longEdge: 320)
        try await NativeMovieRenderer.developClip(source: movie, destination: without, camera: CameraCatalog.cinema16mm,
            seed: 7, orientation: .landscape, longEdge: 320)
        let colorFrames = try await frames(withStock)
        let framesWithout = try await frames(without)
        XCTAssertEqual(colorFrames.map(\.bytes), framesWithout.map(\.bytes))
    }

    func testNoOtherCameraTakesAFilmStock() async throws {
        for camera in CameraCatalog.all where camera.filmStocks.isEmpty {
            for stock in FilmStock.allCases {
                if camera.medium == .photo {
                    XCTAssertThrowsError(try NativePhotoRenderer.develop(source: photo, camera: camera, seed: 1, filmStock: stock)) {
                        XCTAssertEqual($0 as? NativeRenderError, .filmStockNotOffered, camera.displayName)
                    }
                } else {
                    do {
                        try await NativeMovieRenderer.developClip(source: movie, destination: root.appendingPathComponent("x.mov"),
                            camera: camera, filmStock: stock, seed: 1, orientation: .landscape, longEdge: 320)
                        XCTFail("\(camera.displayName) developed a \(stock) Film Stock")
                    } catch { XCTAssertEqual(error as? NativeRenderError, .filmStockNotOffered, camera.displayName) }
                }
            }
        }
    }

    /// A black-and-white 16mm Film's Developed Clip is monochrome in every frame, keeps the Camera's 24 frames per
    /// second and its length, and grains each frame afresh; the Developed Movie assembled from such clips is too.
    func testBlackAndWhiteSixteenMillimeterClipIsMonochromeInEveryFrame() async throws {
        let mono = root.appendingPathComponent("mono.mov"), color = root.appendingPathComponent("color.mov")
        for (url, stock) in [(mono, FilmStock.blackAndWhite), (color, .color)] {
            try await NativeMovieRenderer.developClip(source: movie, destination: url, camera: CameraCatalog.cinema16mm,
                filmStock: stock, seed: 7, orientation: .landscape, longEdge: 320)
        }
        let monoFrames = try await frames(mono)
        let colorFrames = try await frames(color)
        XCTAssertEqual(monoFrames.count, colorFrames.count)
        XCTAssertGreaterThan(monoFrames.count, 1)
        for (index, frame) in monoFrames.enumerated() {
            XCTAssertLessThanOrEqual(frame.largestChannelSpread, 4, "Frame \(index) is neutral gray")
        }
        XCTAssertGreaterThan(colorFrames[0].largestChannelSpread, 40)
        XCTAssertNotEqual(monoFrames[0].bytes, monoFrames[1].bytes, "Each frame has its own grain")
        let rate = try await AVURLAsset(url: mono).loadTracks(withMediaType: .video).first!.load(.nominalFrameRate)
        XCTAssertEqual(rate, 24, accuracy: 0.5)
        let assembled = root.appendingPathComponent("movie.mov")
        try await NativeMovieRenderer.assemble(clips: [mono, mono], destination: assembled)
        let movieFrames = try await frames(assembled)
        XCTAssertEqual(movieFrames.count, monoFrames.count * 2)
        for (index, frame) in movieFrames.enumerated() {
            XCTAssertLessThanOrEqual(frame.largestChannelSpread, 4, "Developed Movie frame \(index) is neutral gray")
        }
    }

    /// Version 2 is assigned from now on, and a capture assigned version 1 before the update still renders, so a Film
    /// that was developing finishes. An unknown version does not.
    func testEarlierTreatmentVersionStillRenders() throws {
        XCTAssertEqual(NativePhotoRenderer.treatmentVersion, "film-look-2-provisional")
        let film = try Film(camera: CameraCatalog.mediumFormat6x6, title: "Roll", filmStock: .blackAndWhite)
        let run = DevelopmentRun(filmID: film.id)
        XCTAssertEqual(run.treatmentVersion, "film-look-2-provisional")
        XCTAssertTrue(run.rendersAssignedTreatment(TreatmentAssignment(sequenceNumber: 1, seed: 1)))
        XCTAssertTrue(run.rendersAssignedTreatment(TreatmentAssignment(sequenceNumber: 1, seed: 1, treatmentVersion: "film-look-1-provisional")))
        XCTAssertFalse(run.rendersAssignedTreatment(TreatmentAssignment(sequenceNumber: 1, seed: 1, treatmentVersion: "film-look-0-earlier")))
        let earlier = Data("{\"filmID\":\"\(film.id)\",\"treatmentVersion\":\"film-look-1-provisional\",\"assignments\":{},\"completedSequences\":[],\"isComplete\":false}".utf8)
        let restored = try JSONDecoder().decode(DevelopmentRun.self, from: earlier)
        XCTAssertTrue(restored.rendersAssignedTreatment(TreatmentAssignment(sequenceNumber: 1, seed: 1, treatmentVersion: nil)))
    }

    /// An even sRGB gray at an 8-bit level, as a capture brings it into Core Image's linear working space.
    private func evenGray(_ level: Int) -> CIImage {
        let value = CGFloat(level) / 255
        return CIImage(color: CIColor(red: value, green: value, blue: value, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)!)
            .cropped(to: CGRect(x: 0, y: 0, width: 512, height: 512))
    }

    /// The mean 8-bit sRGB level of a gray picture's 512 x 512 corner.
    private func meanLevel(_ image: CIImage) -> Double {
        var bytes = [UInt8](repeating: 0, count: 512 * 512 * 4)
        CIContext().render(image, toBitmap: &bytes, rowBytes: 512 * 4, bounds: CGRect(x: 0, y: 0, width: 512, height: 512),
                           format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
        let pixels = DecodedPixels(width: 512, height: 512, bytes: bytes)
        XCTAssertLessThanOrEqual(pixels.largestChannelSpread, 2)
        return stride(from: 0, to: bytes.count, by: 4).reduce(0.0) { $0 + Double(bytes[$1]) } / Double(512 * 512)
    }

    private func writeEvenGray(to url: URL, side: Int) throws {
        let context = try XCTUnwrap(CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(CGColor(srgbRed: 0.5, green: 0.5, blue: 0.5, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        let image = try XCTUnwrap(context.makeImage())
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }

    private func frames(_ url: URL) async throws -> [DecodedPixels] {
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let track = try XCTUnwrap(tracks.first)
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        reader.add(output)
        XCTAssertTrue(reader.startReading())
        var result: [DecodedPixels] = []
        while let sample = output.copyNextSampleBuffer() {
            let buffer = try XCTUnwrap(CMSampleBufferGetImageBuffer(sample))
            CVPixelBufferLockBaseAddress(buffer, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
            let base = try XCTUnwrap(CVPixelBufferGetBaseAddress(buffer))
            let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer)
            var bytes = [UInt8](repeating: 0, count: width * height * 4)
            for row in 0..<height {
                let line = base.advanced(by: row * CVPixelBufferGetBytesPerRow(buffer)).assumingMemoryBound(to: UInt8.self)
                // BGRA to RGBA, so every frame is read in the same channel order as a decoded photo.
                for x in 0..<width {
                    let to = (row * width + x) * 4
                    bytes[to] = line[x * 4 + 2]; bytes[to + 1] = line[x * 4 + 1]; bytes[to + 2] = line[x * 4]; bytes[to + 3] = line[x * 4 + 3]
                }
            }
            result.append(DecodedPixels(width: width, height: height, bytes: bytes))
        }
        XCTAssertEqual(reader.status, .completed)
        return result
    }
}

/// Decoded RGBA pixels and the measures these tests compare.
struct DecodedPixels {
    let width: Int
    let height: Int
    let bytes: [UInt8]

    init(width: Int, height: Int, bytes: [UInt8]) {
        self.width = width
        self.height = height
        self.bytes = bytes
    }

    init(_ data: Data) throws {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        self.init(width: image.width, height: image.height, bytes: bytes)
    }

    /// The largest difference between any two channels of any pixel: 0 for perfectly neutral gray.
    var largestChannelSpread: Int {
        bytes.withUnsafeBufferPointer { pixels in
            var largest = 0
            for index in stride(from: 0, to: pixels.count, by: 4) {
                let r = Int(pixels[index]), g = Int(pixels[index + 1]), b = Int(pixels[index + 2])
                largest = max(largest, max(r, g, b) - min(r, g, b))
            }
            return largest
        }
    }

    private func luminance(_ index: Int) -> Double {
        0.2126 * Double(bytes[index]) + 0.7152 * Double(bytes[index + 1]) + 0.0722 * Double(bytes[index + 2])
    }

    /// The standard deviation of luminance over the whole picture, in 8-bit levels.
    var luminanceDeviation: Double { deviation(in: 0..<height, 0..<width) }

    /// The standard deviation of luminance in the middle quarter, away from the vignette's falloff.
    var centerDeviation: Double { deviation(in: height / 4..<height * 3 / 4, width / 4..<width * 3 / 4) }

    private func deviation(in rows: Range<Int>, _ columns: Range<Int>) -> Double {
        var sum = 0.0, squares = 0.0, count = 0.0
        for y in rows { for x in columns {
            let value = luminance((y * width + x) * 4)
            sum += value; squares += value * value; count += 1
        } }
        let mean = sum / count
        return (squares / count - mean * mean).squareRoot()
    }

    /// The mean absolute difference in luminance from another picture of the same size, in 8-bit levels.
    func meanLuminanceDifference(from other: DecodedPixels) -> Double {
        precondition(width == other.width && height == other.height)
        var total = 0.0
        for index in stride(from: 0, to: bytes.count, by: 4) { total += abs(luminance(index) - other.luminance(index)) }
        return total / Double(width * height)
    }
}
