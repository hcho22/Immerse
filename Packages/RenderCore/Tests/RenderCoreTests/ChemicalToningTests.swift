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
        let camera = CameraCatalog.disposable1990s
        // This is an explicit experimental print process, not a change to a Camera package.
        let master = try NativePhotoRenderer.develop(source: root.appendingPathComponent("synthetic-developed-photo.jpg"),
            camera: camera, seed: 42, process: .silverGelatin)
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
        let run = Data("{\"filmID\":\"\(id)\",\"treatmentVersion\":\"film-look-1-provisional\",\"assignments\":{},\"completedSequences\":[],\"isComplete\":false}".utf8)
        let restored = try JSONDecoder().decode(DevelopmentRun.self, from: run)
        XCTAssertNil(restored.printProcess)
        XCTAssertEqual(restored.filmID, id)
        XCTAssertEqual(DevelopmentRun(filmID: id).printProcess, .color)
        XCTAssertEqual(try JSONDecoder().decode(DevelopmentRun.self,
            from: JSONEncoder().encode(DevelopmentRun(filmID: id, printProcess: .silverGelatin))).printProcess, .silverGelatin)
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
