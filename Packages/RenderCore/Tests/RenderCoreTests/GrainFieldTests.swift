import CoreImage
import FilmDomain
import XCTest
@testable import RenderCore

/// What Core Image does differently from one renderer to another, held the same on all of them. These tests are run
/// on a Mac and inside the iOS simulator (`Scripts/validate-local.sh`): each began as a difference between the two
/// that no test on a Mac alone could see.
final class GrainFieldTests: XCTestCase {
    private func values(_ image: CIImage, _ bounds: CGRect) -> Fixtures.Tones { Fixtures.values(image.cropped(to: bounds)) }

    /// The correlation between the red of each pixel and of the one `lag` pixels across.
    private func correlation(_ tones: Fixtures.Tones, channel: Int = 0, lag: Int) -> Double {
        let values = tones.channel(channel)
        var product = 0.0, first = 0.0, second = 0.0, firstMean = 0.0, secondMean = 0.0
        var pairs: [(Double, Double)] = []
        for y in 0..<tones.height { for x in 0..<(tones.width - lag) { pairs.append((values[y * tones.width + x], values[y * tones.width + x + lag])) } }
        for pair in pairs { firstMean += pair.0; secondMean += pair.1 }
        firstMean /= Double(pairs.count); secondMean /= Double(pairs.count)
        for pair in pairs {
            product += (pair.0 - firstMean) * (pair.1 - secondMean)
            first += pow(pair.0 - firstMean, 2); second += pow(pair.1 - secondMean, 2)
        }
        return product / (first * second).squareRoot()
    }

    /// A tile is laid out one tile pixel to one picture pixel, whole and in order, and a move shifts it by whole
    /// pixels. Core Image's tiling filter left to its default does this on iOS and shrinks the tile to two fifths on
    /// a Mac.
    func testATileIsLaidOutOneToOneOnEveryRenderer() {
        let side = 8
        var cells = [Float](repeating: 1, count: side * side * 4)
        for row in 0..<side { for column in 0..<side {
            cells[(row * side + column) * 4] = Float(column) / 8
            cells[(row * side + column) * 4 + 1] = Float(row) / 8
        } }
        let tile = CIImage(bitmapData: cells.withUnsafeBufferPointer { Data(buffer: $0) }, bytesPerRow: side * 16,
                           size: CGSize(width: side, height: side), format: .RGBAf, colorSpace: nil)
        let bounds = CGRect(x: 0, y: 0, width: 24, height: 16)
        let plain = values(GrainField.tiled(tile), bounds)
        let moved = values(GrainField.tiled(tile, movedBy: CGPoint(x: 3.7, y: 2.2)), bounds)
        for y in 0..<16 { for x in 0..<24 {
            // Rows are read from the top of the picture, where the tile's first row sits at the top of each repeat.
            XCTAssertEqual(plain.pixel(x: x, y: y)[0], Double(x % 8) / 8, accuracy: 0.0005, "red at \(x), \(y)")
            XCTAssertEqual(plain.pixel(x: x, y: y)[1], Double(y % 8) / 8, accuracy: 0.0005, "green at \(x), \(y)")
            XCTAssertEqual(moved.pixel(x: x, y: y)[0], Double((x + 3) % 8) / 8, accuracy: 0.0005, "moved red at \(x), \(y)")
        } }
    }

    /// A negative film's grain reaches the picture with the clumps its field was given: neighboring pixels are alike
    /// by the amounts the reference's field measures, across the frame as Core Image lays the tiles out. Shrunk
    /// tiles, as a Mac once laid them, leave neighbors barely alike.
    func testANegativeFilmsGrainKeepsItsClumpsThroughCoreImage() throws {
        struct Passes: Decodable {
            struct Grain: Decodable { let width: Int; let lags: [Int]; let greenAcrossLags: [Double] }
            let grain: Grain
        }
        for (folder, treatment) in [("Cinema16mmColor", FilmLook.cinemaColor), ("MediumFormatColor", FilmLook.mediumFormatColor)] {
            let fixture = try JSONDecoder().decode(Passes.self, from: Data(contentsOf: Fixtures.url("\(folder)/passes.json"))).grain
            let scene = try XCTUnwrap(treatment.scene), grain = try XCTUnwrap(scene.grain)
            let extent = CGRect(x: 0, y: 0, width: fixture.width, height: 128)
            let grained = DevelopedTreatment(treatment, seed: 31).grained(Fixtures.light(0.5, in: extent), grain, width: Double(fixture.width),
                                                                         referenceWidth: scene.referenceWidth, frame: 2)
            let tones = Fixtures.values(grained)
            for (lag, want) in zip(fixture.lags, fixture.greenAcrossLags) where lag <= 4 {
                XCTAssertEqual(correlation(tones, channel: 1, lag: lag), want, accuracy: 0.03, "\(folder): green, \(lag) across")
            }
        }
    }

    /// Every other look's grain has the clumps the captain approved on the review boards: at the smallest clump, 1.2
    /// pixels, a pixel and its neighbor are alike by about 0.68, the next but one by about 0.22, and four apart not
    /// at all. Its strength is the look's own on every renderer (`FilmLookTests`).
    func testAGrainsClumpsAreTheSameOnEveryRenderer() throws {
        let grain = FilmLook.Grain(amplitude: 10, size: 1.2 / 512)
        let treatment = FilmLook.Treatment(
            emulsion: .color(FilmLook.ColorEmulsion(warmth: 0, saturation: 1, tone: FilmLook.ToneCurve(contrast: 1), grain: grain)),
            lens: FilmLook.Lens())
        let tones = try Fixtures.tones(DevelopedTreatment(treatment, seed: 5).apply(to: Fixtures.even(tone: 0.46, width: 512, height: 256)))
        XCTAssertEqual(correlation(tones, lag: 1), 0.68, accuracy: 0.03)
        XCTAssertEqual(correlation(tones, lag: 2), 0.22, accuracy: 0.03)
        XCTAssertEqual(correlation(tones, lag: 4), 0, accuracy: 0.03)
    }

    /// Core Image takes a curve as a table no wider than the renderer's widest texture. The iOS simulator renders
    /// nothing at all through a table of 16,384 samples, which a Mac renders, so every curve stays at 4,096.
    func testEveryCurveFitsEveryRenderer() {
        XCTAssertLessThanOrEqual(SceneLight.curveSamples, 4096)
        for table in [SceneLight.opened, SceneLight.appleLog, SceneLight.appleLogDecoded, SceneLight.cubeTone] {
            XCTAssertEqual(table.count, SceneLight.curveSamples * 3 * MemoryLayout<Float>.size)
        }
        // The curve into Apple Log, read between its samples as Core Image reads it, stays close to the curve itself.
        let even = Fixtures.light(0.02, in: CGRect(x: 0, y: 0, width: 4, height: 4))
        let encoded = Fixtures.values(SceneLight.curve(even, SceneLight.appleLog, upTo: SceneLight.appleLogRange))
        XCTAssertEqual(encoded.pixel(x: 1, y: 1)[0], FilmLook.NegativeFilm.appleLogEncoded(0.02), accuracy: 0.0005)
    }
}
