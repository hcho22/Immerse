@preconcurrency import AVFoundation
import CoreGraphics
import CoreImage
import FilmDomain
import Foundation
@testable import RenderCore
import RenderFixtures
import XCTest

/// Treatment versions 1 and 2 are frozen: a capture assigned either renders as the version 2 build rendered it, so a
/// Film loaded before each Camera had its own look keeps the look it started with (ADR 0013, RK-11).
///
/// The expected values are the mean red, green and blue of an 8 x 8 grid over each developed picture or Movie frame,
/// recorded from the version 2 build (0e69ed2) with the same fixtures and seeds. Means over large blocks hold to a
/// level or two across machines while any change to a look moves them by much more.
///
/// A Movie frame is measured as the look renders it, never read back from a Developed Clip: a clip is H.264 with no
/// color tags, so its reader guesses its color, and the same frames read back differ from one Mac to another by
/// several times what these tests allow (`Evidence/NativeApp/prd-2-slice-4-looks.md`, "What CI's Mac showed").
final class LegacyLookTests: XCTestCase {
    private var root: URL!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("LegacyLookTests-\(UUID())")
        var settings = RenderFixtureSettings.defaultExperimental
        settings.movieWidth = 160; settings.movieHeight = 96; settings.movieDurationSeconds = 0.4
        _ = try await RenderFixtureGenerator.writeFixtures(outputDirectory: root, settings: settings)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
    }

    private var photo: URL { root.appendingPathComponent("synthetic-developed-photo.jpg") }
    private var movie: URL { root.appendingPathComponent("synthetic-developed-movie.mov") }

    func testVersionTwoPhotosDevelopAsTheVersionTwoBuildDeveloped() throws {
        for expected in Self.photos {
            for version in ["film-look-2-provisional", "film-look-1-provisional"] where version == "film-look-2-provisional" || expected.filmStock != .blackAndWhite {
                let master = try NativePhotoRenderer.develop(source: photo, camera: CameraCatalog.package(for: expected.camera), seed: 42,
                                                             filmStock: expected.filmStock, treatmentVersion: version)
                let pixels = try DecodedPixels(master)
                let name = "\(expected.camera) \(expected.filmStock.map(\.rawValue) ?? "no Film Stock") \(version)"
                XCTAssertEqual("\(pixels.width)x\(pixels.height)", expected.size, name)
                assertClose(pixels.blockMeans(), expected.means, tolerance: 2, name)
            }
        }
    }

    func testVersionTwoMovieFramesDevelopAsTheVersionTwoBuildDeveloped() throws {
        let still = try XCTUnwrap(CIImage(contentsOf: photo))
        for expected in Self.movieFrames {
            let treatment = try DevelopedTreatment(version: "film-look-2-provisional", camera: expected.camera,
                                                   filmStock: expected.filmStock, seed: 7)
            let developed = try treatment.apply(to: Self.scene(still, frame: expected.frame), frame: expected.frame)
            let name = "\(expected.camera) \(expected.filmStock.map(\.rawValue) ?? "no Film Stock") frame \(expected.frame)"
            assertClose(pixels(developed).blockMeans(), expected.means, tolerance: 3, name)
        }
    }

    /// A Developed Clip develops with the version its capture was assigned: given version 2, it is not the clip the
    /// current version develops. Both are read back here, on one machine, so how it reads a clip is the same in each.
    func testAClipDevelopsWithTheVersionItIsGiven() async throws {
        func frames(_ version: String) async throws -> [[UInt8]] {
            let url = root.appendingPathComponent("\(version).mov")
            try await NativeMovieRenderer.developClip(source: movie, destination: url, camera: CameraCatalog.super8HomeMovie,
                seed: 7, orientation: .landscape, longEdge: 320, treatmentVersion: version)
            return try await decodedFrames(url).map(\.bytes)
        }
        let earlier = try await frames("film-look-2-provisional")
        let current = try await frames(NativePhotoRenderer.treatmentVersion)
        // Not XCTAssertNotEqual, whose failure prints every byte of both clips.
        XCTAssertTrue(earlier != current, "A clip given version 2 is not the current version's")
    }

    /// Frame `frame` of a 320 x 240 Movie scene: the fixture photo, drifting one pixel a frame.
    private static func scene(_ still: CIImage, frame: Int) -> CIImage {
        let bounds = CGRect(x: 0, y: 0, width: 320, height: 240)
        let scale = (bounds.width + 24) / still.extent.width
        return still.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(translationX: -CGFloat(frame), y: 0)).cropped(to: bounds)
    }

    /// A developed frame as sRGB pixels, rows from the top, with nothing between the look's render and the measure.
    private func pixels(_ image: CIImage) -> DecodedPixels {
        let width = Int(image.extent.width), height = Int(image.extent.height)
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        CIContext().render(image, toBitmap: &bytes, rowBytes: width * 4, bounds: image.extent, format: .RGBA8,
                           colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
        return DecodedPixels(width: width, height: height, bytes: bytes)
    }

    private func assertClose(_ actual: [Int], _ expected: [Int], tolerance: Int, _ name: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.count, expected.count, name, file: file, line: line)
        let largest = zip(actual, expected).map { abs($0 - $1) }.max() ?? 0
        XCTAssertLessThanOrEqual(largest, tolerance, "\(name) differs by up to \(largest) levels", file: file, line: line)
    }

    private struct Photo {
        let camera: CameraID
        let filmStock: FilmStock?
        let size: String
        let means: [Int]
    }

    private struct Frame {
        let camera: CameraID
        let filmStock: FilmStock?
        let frame: Int
        let means: [Int]
    }

    private static let photos: [Photo] = [
        Photo(camera: .disposable1990s, filmStock: nil, size: "640x426", means: [
            14, 19, 62, 99, 26, 146, 182, 36, 115, 52, 24, 52, 84, 25, 135, 167, 35, 147, 89, 26, 37, 58, 22, 110,
            21, 85, 119, 106, 92, 162, 186, 96, 46, 58, 93, 114, 92, 95, 177, 170, 95, 52, 93, 91, 96, 68, 87, 162,
            39, 141, 169, 112, 147, 72, 191, 152, 96, 75, 152, 169, 101, 151, 104, 175, 151, 80, 106, 148, 150, 80, 142, 129,
            63, 194, 130, 121, 201, 80, 197, 207, 151, 99, 208, 168, 111, 207, 71, 182, 206, 136, 127, 202, 180, 91, 194, 66,
            31, 70, 43, 109, 73, 115, 191, 80, 182, 69, 76, 54, 95, 75, 103, 175, 79, 178, 104, 75, 76, 71, 70, 80,
            16, 31, 75, 103, 39, 159, 186, 48, 96, 54, 37, 65, 87, 38, 148, 171, 47, 131, 92, 38, 48, 62, 34, 123,
            24, 96, 129, 107, 103, 148, 186, 106, 50, 60, 104, 124, 94, 106, 173, 171, 106, 47, 94, 102, 106, 70, 98, 166,
            43, 147, 166, 110, 153, 60, 187, 159, 105, 78, 159, 175, 100, 159, 85, 172, 158, 90, 107, 155, 156, 79, 147, 108
        ]),
        Photo(camera: .instant1970s, filmStock: nil, size: "2282x2774", means: [
            197, 187, 201, 180, 143, 188, 214, 148, 189, 143, 139, 143, 158, 140, 165, 187, 144, 195, 205, 146, 176, 185, 185, 187,
            172, 170, 202, 148, 114, 150, 196, 118, 104, 95, 112, 124, 116, 114, 167, 157, 116, 140, 185, 116, 103, 155, 168, 174,
            179, 203, 180, 157, 170, 113, 205, 175, 148, 114, 172, 179, 129, 172, 134, 166, 172, 119, 195, 173, 152, 166, 203, 209,
            178, 190, 176, 157, 150, 152, 206, 157, 180, 108, 148, 117, 126, 150, 123, 166, 153, 161, 195, 155, 172, 163, 189, 170,
            171, 166, 197, 148, 109, 162, 197, 113, 106, 94, 105, 117, 115, 108, 160, 157, 110, 154, 185, 111, 102, 154, 164, 170,
            176, 196, 186, 152, 158, 107, 201, 163, 137, 109, 160, 172, 125, 160, 143, 162, 160, 110, 190, 161, 141, 163, 196, 203,
            237, 246, 234, 231, 240, 225, 243, 241, 234, 222, 241, 234, 225, 241, 220, 234, 241, 226, 240, 241, 235, 234, 246, 245,
            255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255
        ]),
        Photo(camera: .mediumFormat6x6, filmStock: .color, size: "3072x3072", means: [
            99, 19, 122, 159, 25, 180, 202, 27, 105, 20, 17, 50, 85, 19, 111, 145, 23, 167, 201, 28, 147, 54, 18, 39,
            103, 83, 180, 162, 85, 105, 205, 86, 57, 26, 83, 113, 89, 85, 170, 148, 86, 150, 204, 85, 46, 59, 81, 95,
            106, 142, 108, 165, 144, 59, 208, 147, 117, 39, 146, 173, 94, 146, 154, 150, 145, 50, 207, 145, 101, 71, 142, 154,
            111, 201, 64, 168, 205, 118, 213, 207, 175, 54, 207, 160, 99, 207, 57, 154, 206, 104, 210, 205, 159, 86, 202, 181,
            105, 71, 113, 165, 77, 172, 209, 81, 153, 31, 71, 47, 92, 73, 101, 151, 76, 158, 208, 81, 180, 66, 71, 52,
            103, 67, 167, 163, 70, 150, 206, 70, 47, 24, 66, 97, 89, 68, 156, 149, 70, 179, 206, 70, 53, 58, 65, 80,
            104, 126, 148, 163, 127, 48, 206, 129, 100, 34, 129, 156, 92, 129, 179, 149, 128, 55, 205, 128, 84, 66, 125, 137,
            106, 180, 52, 163, 184, 100, 206, 186, 156, 49, 186, 180, 95, 186, 61, 149, 185, 86, 204, 184, 140, 80, 181, 183
        ]),
        Photo(camera: .mediumFormat6x6, filmStock: .blackAndWhite, size: "3072x3072", means: [
            54, 54, 54, 123, 123, 123, 151, 151, 151, 11, 11, 11, 42, 42, 42, 104, 104, 104, 157, 157, 157, 38, 38, 38,
            110, 110, 110, 133, 133, 133, 154, 154, 154, 55, 55, 55, 98, 98, 98, 135, 135, 135, 149, 149, 149, 75, 75, 75,
            150, 150, 150, 163, 163, 163, 202, 202, 202, 142, 142, 142, 159, 159, 159, 154, 154, 154, 196, 196, 196, 150, 150, 150,
            199, 199, 199, 223, 223, 223, 241, 241, 241, 213, 213, 213, 200, 200, 200, 219, 219, 219, 238, 238, 238, 216, 216, 216,
            99, 99, 99, 153, 153, 153, 184, 184, 184, 67, 67, 67, 91, 91, 91, 139, 139, 139, 187, 187, 187, 89, 89, 89,
            93, 93, 93, 138, 138, 138, 148, 148, 148, 39, 39, 39, 80, 80, 80, 134, 134, 134, 146, 146, 146, 61, 61, 61,
            143, 143, 143, 146, 146, 146, 187, 187, 187, 116, 116, 116, 147, 147, 147, 141, 141, 141, 181, 181, 181, 127, 127, 127,
            176, 176, 176, 204, 204, 204, 228, 228, 228, 195, 195, 195, 180, 180, 180, 198, 198, 198, 223, 223, 223, 198, 198, 198
        ]),
    ]

    private static let movieFrames: [Frame] = [
        Frame(camera: .super8HomeMovie, filmStock: nil, frame: 0, means: [
            10, 25, 64, 88, 34, 142, 165, 45, 128, 98, 38, 44, 51, 32, 114, 134, 43, 169, 172, 45, 50, 16, 26, 73,
            25, 97, 126, 99, 103, 160, 170, 106, 51, 106, 106, 107, 66, 104, 171, 139, 105, 84, 178, 106, 78, 31, 97, 134,
            55, 156, 173, 109, 159, 76, 177, 164, 101, 127, 166, 164, 86, 164, 137, 147, 163, 75, 187, 163, 134, 59, 156, 171,
            80, 208, 121, 124, 213, 99, 187, 219, 157, 148, 220, 181, 104, 217, 87, 159, 218, 131, 199, 216, 186, 83, 207, 107,
            9, 5, 32, 88, 8, 114, 169, 19, 174, 99, 13, 43, 47, 6, 80, 136, 14, 157, 177, 22, 110, 13, 5, 39,
            15, 56, 93, 94, 65, 167, 170, 73, 82, 101, 67, 72, 57, 63, 140, 138, 71, 150, 177, 72, 47, 21, 57, 102,
            36, 121, 149, 102, 126, 124, 172, 130, 66, 112, 131, 131, 75, 129, 174, 141, 128, 59, 180, 129, 102, 42, 121, 156,
            65, 173, 160, 111, 178, 70, 177, 184, 122, 134, 186, 181, 91, 183, 99, 148, 182, 96, 188, 181, 153, 68, 173, 149
        ]),
        Frame(camera: .super8HomeMovie, filmStock: nil, frame: 2, means: [
            13, 25, 67, 91, 34, 143, 166, 45, 118, 87, 36, 46, 53, 30, 115, 135, 42, 165, 161, 43, 45, 18, 26, 76,
            27, 95, 128, 100, 101, 153, 170, 105, 50, 95, 104, 109, 69, 102, 170, 140, 104, 76, 167, 104, 79, 34, 96, 135,
            56, 153, 170, 110, 157, 71, 178, 162, 104, 117, 163, 165, 88, 161, 127, 148, 161, 77, 177, 160, 135, 62, 154, 167,
            80, 204, 113, 125, 210, 100, 187, 215, 158, 139, 217, 174, 104, 214, 85, 160, 214, 132, 191, 213, 185, 83, 204, 101,
            10, 5, 34, 91, 9, 116, 170, 20, 170, 88, 12, 37, 51, 6, 83, 137, 14, 158, 166, 20, 100, 16, 5, 43,
            17, 55, 95, 97, 65, 167, 170, 72, 74, 90, 65, 74, 60, 61, 142, 140, 70, 142, 166, 69, 47, 24, 56, 104,
            38, 119, 149, 104, 124, 115, 173, 128, 69, 101, 128, 131, 77, 127, 169, 142, 126, 56, 170, 127, 103, 44, 120, 157,
            66, 171, 153, 113, 175, 70, 177, 181, 123, 125, 183, 180, 92, 180, 92, 149, 180, 97, 178, 178, 153, 69, 171, 141
        ]),
        Frame(camera: .super8HomeMovie, filmStock: nil, frame: 5, means: [
            17, 26, 74, 97, 36, 148, 171, 46, 106, 72, 34, 50, 61, 31, 121, 140, 43, 161, 149, 42, 41, 24, 27, 82,
            32, 95, 132, 106, 102, 145, 175, 105, 52, 81, 103, 113, 75, 103, 172, 145, 103, 67, 154, 103, 84, 39, 96, 140,
            60, 153, 168, 115, 157, 67, 182, 162, 108, 105, 163, 169, 92, 161, 116, 153, 161, 81, 167, 160, 139, 65, 153, 162,
            82, 204, 105, 128, 210, 104, 192, 215, 162, 128, 216, 166, 107, 213, 86, 164, 214, 135, 182, 212, 185, 85, 204, 95,
            14, 5, 40, 97, 9, 121, 175, 21, 166, 72, 12, 33, 58, 7, 89, 143, 15, 163, 153, 19, 85, 21, 5, 48,
            22, 56, 101, 103, 66, 168, 175, 72, 65, 75, 64, 78, 67, 63, 147, 145, 70, 131, 153, 69, 50, 30, 57, 109,
            42, 119, 154, 108, 124, 103, 177, 128, 74, 89, 128, 135, 82, 127, 164, 147, 126, 54, 158, 126, 107, 49, 119, 160,
            68, 170, 145, 116, 175, 71, 182, 181, 127, 114, 182, 179, 95, 179, 85, 153, 179, 101, 169, 178, 157, 72, 170, 131
        ]),
        Frame(camera: .cinema16mm, filmStock: .color, frame: 0, means: [
            15, 35, 74, 97, 41, 151, 173, 48, 131, 101, 43, 48, 61, 40, 123, 141, 46, 177, 180, 46, 48, 22, 35, 83,
            24, 102, 133, 102, 107, 165, 176, 109, 45, 106, 110, 110, 70, 109, 179, 145, 109, 81, 184, 107, 76, 31, 102, 140,
            41, 159, 177, 107, 163, 63, 181, 167, 96, 120, 169, 167, 80, 168, 132, 149, 166, 65, 190, 165, 133, 47, 160, 174,
            59, 211, 105, 115, 217, 85, 186, 221, 153, 135, 223, 176, 89, 222, 66, 155, 221, 123, 197, 218, 185, 63, 211, 89,
            14, 6, 41, 98, 9, 123, 178, 16, 182, 103, 11, 46, 61, 7, 91, 144, 13, 166, 185, 16, 112, 21, 6, 50,
            18, 67, 102, 101, 72, 176, 177, 75, 81, 104, 74, 76, 65, 72, 149, 145, 75, 155, 185, 74, 44, 26, 67, 110,
            30, 125, 154, 104, 130, 123, 177, 132, 60, 110, 134, 133, 74, 133, 180, 145, 132, 51, 185, 131, 99, 37, 126, 162,
            48, 177, 158, 107, 182, 54, 178, 186, 117, 124, 188, 183, 81, 187, 84, 147, 186, 87, 188, 183, 151, 53, 177, 145
        ]),
        Frame(camera: .cinema16mm, filmStock: .color, frame: 2, means: [
            18, 35, 78, 101, 41, 154, 177, 48, 122, 91, 42, 52, 65, 39, 126, 145, 46, 175, 171, 45, 44, 25, 36, 87,
            27, 102, 136, 106, 107, 160, 180, 109, 45, 97, 109, 113, 74, 109, 181, 148, 109, 74, 175, 107, 79, 34, 102, 144,
            44, 160, 177, 111, 163, 59, 184, 167, 100, 111, 169, 170, 83, 168, 123, 152, 166, 68, 181, 165, 136, 51, 160, 172,
            60, 211, 98, 118, 217, 88, 189, 221, 156, 127, 223, 171, 92, 222, 66, 158, 221, 126, 190, 218, 186, 65, 211, 84,
            17, 6, 45, 103, 9, 127, 182, 17, 180, 93, 10, 42, 65, 7, 95, 148, 13, 170, 176, 16, 102, 25, 6, 54,
            21, 67, 105, 105, 72, 178, 181, 75, 73, 94, 73, 79, 70, 72, 152, 149, 75, 148, 176, 73, 46, 29, 67, 114,
            33, 126, 158, 107, 130, 115, 181, 132, 64, 100, 133, 136, 78, 133, 177, 149, 132, 49, 176, 130, 103, 40, 126, 166,
            50, 177, 153, 110, 182, 55, 182, 186, 120, 116, 188, 184, 84, 187, 78, 151, 186, 90, 180, 183, 154, 55, 177, 138
        ]),
        Frame(camera: .cinema16mm, filmStock: .color, frame: 5, means: [
            23, 36, 85, 107, 42, 160, 182, 48, 110, 76, 41, 57, 73, 40, 132, 150, 47, 171, 158, 45, 41, 31, 36, 93,
            32, 102, 141, 111, 107, 151, 186, 109, 47, 83, 109, 118, 80, 109, 183, 154, 108, 64, 162, 107, 85, 40, 103, 149,
            49, 160, 174, 116, 163, 56, 190, 167, 105, 98, 168, 175, 88, 167, 110, 158, 167, 73, 169, 165, 141, 56, 160, 166,
            63, 211, 89, 123, 217, 93, 195, 221, 161, 115, 223, 161, 97, 222, 68, 164, 221, 131, 180, 218, 187, 69, 211, 77,
            22, 6, 51, 109, 10, 132, 187, 18, 176, 77, 10, 38, 73, 8, 101, 154, 14, 175, 163, 15, 88, 30, 6, 60,
            27, 67, 111, 111, 73, 180, 186, 76, 63, 79, 73, 85, 77, 73, 158, 154, 75, 136, 162, 73, 50, 35, 68, 119,
            38, 126, 163, 113, 130, 102, 186, 133, 70, 88, 133, 141, 83, 133, 171, 154, 132, 47, 164, 130, 108, 46, 126, 170,
            54, 177, 144, 115, 182, 58, 187, 186, 125, 103, 188, 185, 89, 187, 70, 156, 186, 95, 169, 183, 159, 59, 177, 127
        ]),
        Frame(camera: .cinema16mm, filmStock: .blackAndWhite, frame: 0, means: [
            31, 31, 31, 82, 82, 82, 136, 136, 136, 82, 82, 82, 57, 57, 57, 121, 121, 121, 127, 127, 127, 35, 35, 35,
            91, 91, 91, 133, 133, 133, 143, 143, 143, 131, 131, 131, 122, 122, 122, 134, 134, 134, 157, 157, 157, 95, 95, 95,
            166, 166, 166, 162, 162, 162, 194, 194, 194, 194, 194, 194, 173, 173, 173, 176, 176, 176, 205, 205, 205, 167, 167, 167,
            205, 205, 205, 212, 212, 212, 235, 235, 235, 233, 233, 233, 211, 211, 211, 226, 226, 226, 237, 237, 237, 204, 204, 204,
            15, 15, 15, 60, 60, 60, 139, 139, 139, 77, 77, 77, 36, 36, 36, 104, 104, 104, 139, 139, 139, 18, 18, 18,
            53, 53, 53, 107, 107, 107, 135, 135, 135, 100, 100, 100, 82, 82, 82, 132, 132, 132, 135, 135, 135, 57, 57, 57,
            122, 122, 122, 144, 144, 144, 161, 161, 161, 156, 156, 156, 147, 147, 147, 144, 144, 144, 176, 176, 176, 126, 126, 126,
            182, 182, 182, 178, 178, 178, 210, 210, 210, 211, 211, 211, 183, 183, 183, 196, 196, 196, 216, 216, 216, 181, 181, 181
        ]),
        Frame(camera: .cinema16mm, filmStock: .blackAndWhite, frame: 2, means: [
            33, 33, 33, 86, 86, 86, 137, 137, 137, 77, 77, 77, 60, 60, 60, 124, 124, 124, 121, 121, 121, 37, 37, 37,
            92, 92, 92, 133, 133, 133, 144, 144, 144, 127, 127, 127, 124, 124, 124, 134, 134, 134, 154, 154, 154, 97, 97, 97,
            167, 167, 167, 162, 162, 162, 196, 196, 196, 192, 192, 192, 172, 172, 172, 178, 178, 178, 203, 203, 203, 168, 168, 168,
            205, 205, 205, 213, 213, 213, 236, 236, 236, 231, 231, 231, 212, 212, 212, 227, 227, 227, 236, 236, 236, 203, 203, 203,
            16, 16, 16, 64, 64, 64, 142, 142, 142, 70, 70, 70, 38, 38, 38, 109, 109, 109, 132, 132, 132, 19, 19, 19,
            55, 55, 55, 110, 110, 110, 136, 136, 136, 95, 95, 95, 85, 85, 85, 132, 132, 132, 131, 131, 131, 59, 59, 59,
            123, 123, 123, 143, 143, 143, 164, 164, 164, 153, 153, 153, 148, 148, 148, 145, 145, 145, 173, 173, 173, 128, 128, 128,
            182, 182, 182, 178, 178, 178, 211, 211, 211, 210, 210, 210, 182, 182, 182, 197, 197, 197, 215, 215, 215, 180, 180, 180
        ]),
        Frame(camera: .cinema16mm, filmStock: .blackAndWhite, frame: 5, means: [
            35, 35, 35, 91, 91, 91, 138, 138, 138, 69, 69, 69, 64, 64, 64, 128, 128, 128, 113, 113, 113, 40, 40, 40,
            95, 95, 95, 134, 134, 134, 149, 149, 149, 121, 121, 121, 127, 127, 127, 135, 135, 135, 149, 149, 149, 100, 100, 100,
            168, 168, 168, 162, 162, 162, 200, 200, 200, 189, 189, 189, 170, 170, 170, 181, 181, 181, 201, 201, 201, 168, 168, 168,
            204, 204, 204, 215, 215, 215, 237, 237, 237, 229, 229, 229, 212, 212, 212, 229, 229, 229, 235, 235, 235, 203, 203, 203,
            18, 18, 18, 69, 69, 69, 146, 146, 146, 59, 59, 59, 42, 42, 42, 115, 115, 115, 121, 121, 121, 21, 21, 21,
            57, 57, 57, 115, 115, 115, 138, 138, 138, 88, 88, 88, 89, 89, 89, 134, 134, 134, 125, 125, 125, 62, 62, 62,
            126, 126, 126, 142, 142, 142, 168, 168, 168, 148, 148, 148, 149, 149, 149, 147, 147, 147, 170, 170, 170, 131, 131, 131,
            181, 181, 181, 180, 180, 180, 213, 213, 213, 207, 207, 207, 182, 182, 182, 200, 200, 200, 213, 213, 213, 179, 179, 179
        ]),
    ]
}
