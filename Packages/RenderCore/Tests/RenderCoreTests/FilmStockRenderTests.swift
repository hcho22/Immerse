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
/// desaturated, and the color Film Stock develops as a Film without one. Values are provisional (DEC-04); these tests
/// hold the character, not the numbers.
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
    /// the color master's, desaturated, and on a neutral ramp, where only the print curves differ, it is steeper
    /// through the middle tones.
    func testBlackAndWhiteIsHigherContrastAndNotTheColorLookDesaturated() throws {
        let camera = CameraCatalog.mediumFormat6x6
        let mono = try DecodedPixels(NativePhotoRenderer.develop(source: photo, camera: camera, seed: 42, filmStock: .blackAndWhite))
        let color = try DecodedPixels(NativePhotoRenderer.develop(source: photo, camera: camera, seed: 42, filmStock: .color))
        XCTAssertGreaterThan(mono.meanLuminanceDifference(from: color), 6,
                             "Black-and-white tones are not the color master's luminance")
        let ramp = root.appendingPathComponent("ramp.png")
        try writeGrayRamp(to: ramp, side: 1024)
        let monoRamp = try DecodedPixels(NativePhotoRenderer.develop(source: ramp, camera: camera, seed: 42, filmStock: .blackAndWhite))
        let colorRamp = try DecodedPixels(NativePhotoRenderer.develop(source: ramp, camera: camera, seed: 42, filmStock: .color))
        // The step from a darker to a lighter middle tone, where the print curves differ most; the whole ramp's spread
        // says less, since both stocks reach black and white.
        func middleStep(_ pixels: DecodedPixels) -> Double {
            let rows = pixels.height / 4..<pixels.height * 3 / 4
            func tone(_ fraction: Double) -> Double {
                let column = Int(Double(pixels.width) * fraction)
                return pixels.meanLuminance(x: column - 8..<column + 8, y: rows)
            }
            return tone(0.65) - tone(0.35)
        }
        XCTAssertGreaterThan(middleStep(monoRamp), middleStep(colorRamp) * 1.1,
                             "Black-and-white is steeper through the middle tones (\(middleStep(monoRamp)) vs \(middleStep(colorRamp)))")
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

    /// Version 2's black-and-white print curve pivots on display mid-gray: an even mid-gray scene keeps its tone through
    /// the whole black-and-white chain, with and without grain, while darker tones print darker and lighter tones
    /// lighter. Version 2 stays renderable for Films that started with it.
    func testBlackAndWhiteKeepsDisplayMidGrayWithAndWithoutGrain() {
        for camera in [CameraID.mediumFormat6x6, .cinema16mm] {
            guard case let .monochrome(look) = LegacyLook.treatment(camera: camera, filmStock: .blackAndWhite) else {
                return XCTFail("\(camera) has no black-and-white treatment")
            }
            let clean = LegacyLook.Monochrome(spectral: look.spectral, curve: look.curve, grainAmplitude: 0, grainSize: look.grainSize)
            XCTAssertEqual(meanLevel(LegacyLook.monochrome(evenGray(128), clean, seed: 9, frame: 0)), 128, accuracy: 3,
                           "\(camera) without grain")
            XCTAssertEqual(meanLevel(LegacyLook.monochrome(evenGray(128), look, seed: 9, frame: 0)), 128, accuracy: 3,
                           "\(camera) with grain")
            XCTAssertLessThan(meanLevel(LegacyLook.monochrome(evenGray(64), clean, seed: 9, frame: 0)), 64 - 10,
                              "\(camera) prints a dark tone darker")
            XCTAssertGreaterThan(meanLevel(LegacyLook.monochrome(evenGray(192), clean, seed: 9, frame: 0)), 192 + 10,
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
        let colorFrames = try await decodedFrames(withStock)
        let framesWithout = try await decodedFrames(without)
        XCTAssertEqual(colorFrames.map(\.bytes), framesWithout.map(\.bytes))
    }

    /// A black-and-white 16mm Film's Developed Clip is monochrome in every frame, keeps the Camera's 24 frames per
    /// second and its length, and grains each frame afresh; the Developed Movie assembled from such clips is too.
    func testBlackAndWhiteSixteenMillimeterClipIsMonochromeInEveryFrame() async throws {
        let mono = root.appendingPathComponent("mono.mov"), color = root.appendingPathComponent("color.mov")
        for (url, stock) in [(mono, FilmStock.blackAndWhite), (color, .color)] {
            try await NativeMovieRenderer.developClip(source: movie, destination: url, camera: CameraCatalog.cinema16mm,
                filmStock: stock, seed: 7, orientation: .landscape, longEdge: 320)
        }
        let monoFrames = try await decodedFrames(mono)
        let colorFrames = try await decodedFrames(color)
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
        let movieFrames = try await decodedFrames(assembled)
        XCTAssertEqual(movieFrames.count, monoFrames.count * 2)
        for (index, frame) in movieFrames.enumerated() {
            XCTAssertLessThanOrEqual(frame.largestChannelSpread, 4, "Developed Movie frame \(index) is neutral gray")
        }
    }

    /// Version 3 is assigned from now on, and a capture assigned version 1 or 2 before the update still renders, so a
    /// Film that was developing finishes. An unknown version does not.
    func testEarlierTreatmentVersionStillRenders() throws {
        XCTAssertEqual(NativePhotoRenderer.treatmentVersion, "film-look-3")
        let film = try Film(camera: CameraCatalog.mediumFormat6x6, title: "Roll", filmStock: .blackAndWhite)
        let run = DevelopmentRun(film: film)
        XCTAssertEqual(run.treatmentVersion, "film-look-3")
        XCTAssertTrue(run.rendersAssignedTreatment(TreatmentAssignment(sequenceNumber: 1, seed: 1)))
        for earlier in ["film-look-1-provisional", "film-look-2-provisional"] {
            XCTAssertTrue(run.rendersAssignedTreatment(TreatmentAssignment(sequenceNumber: 1, seed: 1, treatmentVersion: earlier)))
        }
        XCTAssertFalse(run.rendersAssignedTreatment(TreatmentAssignment(sequenceNumber: 1, seed: 1, treatmentVersion: "film-look-0-earlier")))
        let earlier = Data("{\"filmID\":\"\(film.id)\",\"treatmentVersion\":\"film-look-1-provisional\",\"assignments\":{},\"completedSequences\":[],\"isComplete\":false}".utf8)
        let restored = try JSONDecoder().decode(DevelopmentRun.self, from: earlier)
        XCTAssertTrue(restored.rendersAssignedTreatment(TreatmentAssignment(sequenceNumber: 1, seed: 1, treatmentVersion: nil)))
        XCTAssertEqual(restored.treatmentVersion(of: TreatmentAssignment(sequenceNumber: 1, seed: 1, treatmentVersion: nil)),
                       "film-look-1-provisional")
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

    /// A neutral ramp from black at the left to white at the right.
    private func writeGrayRamp(to url: URL, side: Int) throws {
        let context = try XCTUnwrap(CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        for column in 0..<side {
            let level = CGFloat(column) / CGFloat(side - 1)
            context.setFillColor(CGColor(srgbRed: level, green: level, blue: level, alpha: 1))
            context.fill(CGRect(x: column, y: 0, width: 1, height: side))
        }
        let image = try XCTUnwrap(context.makeImage())
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
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
}
