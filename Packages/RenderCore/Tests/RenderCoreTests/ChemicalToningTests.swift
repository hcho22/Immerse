import CoreGraphics
import FilmDomain
import Foundation
import ImageIO
import RenderCore
import RenderFixtures
import XCTest

final class ChemicalToningTests: XCTestCase {
    func testApplicableToningChangesDecodedPrintButResetKeepsExactSilverMaster() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Toning-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try await RenderFixtureGenerator.writeFixtures(outputDirectory: root)
        // A black-and-white 6×6 Film, the one v1 Photo Film whose prints are silver gelatin (PRD 2.1 FR-07).
        let camera = CameraCatalog.mediumFormat6x6
        let master = try NativePhotoRenderer.develop(source: root.appendingPathComponent("synthetic-developed-photo.jpg"),
            camera: camera, seed: 42, filmStock: .blackAndWhite)
        let neutral = try pixels(master)
        XCTAssertLessThan(averageChannelDifference(neutral), 2)
        for chemistry in ChemicalToning.Chemistry.allCases {
            var recipe = DarkroomRecipe(chemicalToning: ChemicalToning(chemistry: chemistry, amount: 1))
            let toned = try NativePhotoRenderer.print(master: master, recipe: recipe, camera: camera, process: .silverGelatin)
            XCTAssertNotEqual(try pixels(toned), neutral)
            XCTAssertGreaterThan(averageChannelDifference(try pixels(toned)), 2)
            XCTAssertEqual(toned, try NativePhotoRenderer.print(master: master, recipe: recipe, camera: camera, process: .silverGelatin))
            XCTAssertThrowsError(try NativePhotoRenderer.print(master: master, recipe: recipe, camera: camera))
            recipe.resetToOriginal()
            XCTAssertEqual(try NativePhotoRenderer.print(master: master, recipe: recipe, camera: camera, process: .silverGelatin), master)
        }
        XCTAssertThrowsError(try NativePhotoRenderer.print(master: master,
            recipe: DarkroomRecipe(colorFiltration: ColorFiltration(cyan: 2)), camera: camera, process: .silverGelatin))
        for amount in [-0.1, 1.1, Double.infinity, .nan] {
            XCTAssertThrowsError(try NativePhotoRenderer.validate(
                DarkroomRecipe(chemicalToning: ChemicalToning(chemistry: .sepia, amount: amount)),
                camera: camera, process: .silverGelatin))
        }
    }

    func testOlderRecipeAndRunDecodeWithoutChangingOriginalOrAssigningAToner() throws {
        let recipe = Data(#"{"printExposureStops":0,"dodgeBurnMasks":[]}"#.utf8)
        let decoded = try JSONDecoder().decode(DarkroomRecipe.self, from: recipe)
        XCTAssertEqual(decoded, .original)
        let id = UUID()
        // Runs stored before Film Stock, with and without the print process they then recorded, which was always color.
        for process in ["", ",\"printProcess\":\"color\""] {
            let run = Data("{\"filmID\":\"\(id)\",\"treatmentVersion\":\"film-look-1-provisional\",\"assignments\":{},\"completedSequences\":[],\"isComplete\":false\(process)}".utf8)
            let restored = try JSONDecoder().decode(DevelopmentRun.self, from: run)
            XCTAssertEqual(restored.filmID, id)
            XCTAssertEqual(restored.treatmentVersion, "film-look-1-provisional")
        }
    }

    /// The print process follows the Film Stock alone: black-and-white prints are silver gelatin and take toning, and
    /// every other Film, including one loaded before Film Stock existed, prints in color.
    func testPrintProcessFollowsTheFilmStock() throws {
        XCTAssertEqual(PhotoPrintProcess(filmStock: .blackAndWhite), .silverGelatin)
        XCTAssertEqual(PhotoPrintProcess(filmStock: .color), .color)
        XCTAssertEqual(PhotoPrintProcess(filmStock: nil), .color)
        XCTAssertEqual(try Film(camera: CameraCatalog.mediumFormat6x6, title: "Roll", filmStock: .blackAndWhite).printProcess, .silverGelatin)
        XCTAssertEqual(try Film(camera: CameraCatalog.mediumFormat6x6, title: "Roll", filmStock: .color).printProcess, .color)
        for camera in CameraCatalog.all where camera.medium == .photo && camera.filmStocks.isEmpty {
            XCTAssertEqual(try Film(camera: camera, title: "Roll").printProcess, .color, camera.displayName)
        }
    }

    private func pixels(_ data: Data) throws -> [UInt8] {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try pixels.withUnsafeMutableBytes { bytes in
            let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return pixels
    }

    private func averageChannelDifference(_ pixels: [UInt8]) -> Double {
        var sum = 0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let red = Int(pixels[index])
            let green = Int(pixels[index + 1])
            let blue = Int(pixels[index + 2])
            sum += abs(red - green) + abs(green - blue)
        }
        return Double(sum) / Double(pixels.count / 4)
    }
}
