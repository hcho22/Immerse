import CoreImage
import FilmDomain
import XCTest
@testable import RenderCore

/// The 16mm Cinema's color Film Stock develops exactly as the captain's generator does
/// (`Probes/FilmLookCalibration/16mm/vision3_250d_lut.py`, its "print" look). The fixtures are that generator's own
/// numbers, written by `make_fixtures.py` beside it.
final class NegativeFilmTests: XCTestCase {
    private struct Colors: Decodable {
        /// The generator's own constants for the look, as its file holds them.
        struct Constants: Decodable {
            let curve: String
            let negativeGamma: [Double], exposure: Double, balance: [Double], toe: Double, crosstalk: [[Double]]
            let slope: [Double], grayDensity: Double, maximumDensity: Double, bias: [Double], black: [Double]
            let bands: [[Double]], finish: [[Double]], highlightDesaturation: Double, shadowDesaturation: Double
            let bandCenters: [Double], bandWidths: [Double]
        }
        let sanity: [String: [Double]]
        let constants: Constants
        let scene: [[Double]], sceneDeveloped: [[Double]]
        let appleLog: [[Double]], appleLogDeveloped: [[Double]]
        let display: [[Double]], displayDeveloped: [[Double]]
    }

    private static let colors: Colors = try! JSONDecoder().decode(Colors.self, from: Data(contentsOf: Fixtures.url("Cinema16mmColor/colors.json")))

    private var film: FilmLook.NegativeFilm {
        guard case let .negative(film) = FilmLook.cinemaColor.emulsion else { fatalError("The 16mm color stock is a negative film") }
        return film
    }

    private func gray(_ level: Double) -> FilmLook.RGB { FilmLook.RGB(level, level, level) }

    // MARK: - The film

    /// Every constant of the film is the generator's, read from the generator's own file.
    func testEveryConstantIsTheGenerators() {
        let generator = Self.colors.constants
        func color(_ values: [Double]) -> FilmLook.RGB { FilmLook.RGB(values[0], values[1], values[2]) }
        func bands(_ rows: [[Double]]) -> [FilmLook.NegativeFilm.Band] { rows.map { FilmLook.NegativeFilm.Band($0[0], $0[1], $0[2]) } }
        XCTAssertEqual(generator.curve, "print")
        XCTAssertEqual(film.output, .print(maximumDensity: generator.maximumDensity))
        XCTAssertEqual(film.negativeGamma, color(generator.negativeGamma))
        XCTAssertEqual(film.exposure, generator.exposure)
        XCTAssertEqual(film.balance, color(generator.balance))
        XCTAssertEqual(film.toe, generator.toe)
        XCTAssertEqual(film.crosstalk, generator.crosstalk.map(color))
        XCTAssertEqual(film.slope, color(generator.slope))
        XCTAssertEqual(film.grayDensity, generator.grayDensity)
        XCTAssertEqual(film.bias, color(generator.bias))
        XCTAssertEqual(film.black, color(generator.black))
        XCTAssertEqual(film.bands, bands(generator.bands))
        XCTAssertEqual(film.finish, bands(generator.finish))
        XCTAssertEqual(film.highlightDesaturation, generator.highlightDesaturation)
        XCTAssertEqual(film.shadowDesaturation, generator.shadowDesaturation)
        XCTAssertEqual(FilmLook.NegativeFilm.bandCenters, generator.bandCenters)
        XCTAssertEqual(FilmLook.NegativeFilm.bandWidths, generator.bandWidths)
    }

    /// Every neutral value the generator states for its print look, from six stops under middle gray to five over,
    /// within its tolerance of 0.02.
    func testTheFilmGivesEveryNeutralValueTheGeneratorStates() {
        XCTAssertEqual(Self.colors.sanity.count, 6)
        for (stops, expected) in Self.colors.sanity {
            let developed = film.developed(scene: gray(0.18 * pow(2, Double(stops)!)))
            XCTAssertEqual(developed.red, expected[0], accuracy: 0.02, "\(stops) stops, red")
            XCTAssertEqual(developed.green, expected[1], accuracy: 0.02, "\(stops) stops, green")
            XCTAssertEqual(developed.blue, expected[2], accuracy: 0.02, "\(stops) stops, blue")
        }
        // Daylight gray develops neutral; shadows lean a hair cool and highlights a hair warm.
        let middle = film.developed(scene: gray(0.18)), shadow = film.developed(scene: gray(0.045)), light = film.developed(scene: gray(0.72))
        XCTAssertEqual(middle.red, middle.blue, accuracy: 0.001)
        XCTAssertGreaterThan(shadow.blue, shadow.red)
        XCTAssertGreaterThan(light.red, light.blue)
    }

    /// A neutral ramp from eight stops under middle gray to seven over never reverses, in any channel.
    func testANeutralRampNeverReverses() {
        var last = gray(-1)
        for step in 0..<200 {
            let developed = film.developed(scene: gray(0.18 * pow(2, -8 + 15 * Double(step) / 199)))
            XCTAssertGreaterThanOrEqual(developed.red, last.red - 1e-6, "step \(step)")
            XCTAssertGreaterThanOrEqual(developed.green, last.green - 1e-6, "step \(step)")
            XCTAssertGreaterThanOrEqual(developed.blue, last.blue - 1e-6, "step \(step)")
            last = developed
        }
    }

    /// The film agrees with the generator on 704 scene colors (a neutral ramp, a 7 x 7 x 7 grid of phone colors and
    /// 300 random ones up to five stops over gray) and on 425 Apple Log tones, to 0.00002 in every channel. The
    /// fixture's values are rounded to six places.
    func testTheFilmMatchesTheGeneratorOnAWideSetOfColors() {
        XCTAssertEqual(Self.colors.scene.count, 704)
        XCTAssertEqual(Self.colors.appleLog.count, 425)
        var worst = 0.0
        for (input, expected) in zip(Self.colors.scene, Self.colors.sceneDeveloped) {
            let developed = film.developed(scene: FilmLook.RGB(input[0], input[1], input[2]))
            worst = max(worst, abs(developed.red - expected[0]), abs(developed.green - expected[1]), abs(developed.blue - expected[2]))
        }
        XCTAssertLessThan(worst, 0.00002, "scene colors")
        worst = 0
        for (input, expected) in zip(Self.colors.appleLog, Self.colors.appleLogDeveloped) {
            let developed = film.developed(appleLog: FilmLook.RGB(input[0], input[1], input[2]))
            worst = max(worst, abs(developed.red - expected[0]), abs(developed.green - expected[1]), abs(developed.blue - expected[2]))
        }
        XCTAssertLessThan(worst, 0.00002, "Apple Log tones")
    }

    /// The curve into Apple Log and the one back agree, and the phone's white opens to 2.6 in scene light.
    func testAppleLogAndSceneLight() {
        for light in [0.0, 0.005, 0.01, 0.18, 1, 2.6, 6] {
            XCTAssertEqual(FilmLook.NegativeFilm.appleLogDecoded(FilmLook.NegativeFilm.appleLogEncoded(light)), light, accuracy: 1e-9)
        }
        XCTAssertEqual(FilmLook.NegativeFilm.sceneLight(displayLight: 0.5), 0.5)
        XCTAssertEqual(FilmLook.NegativeFilm.sceneLight(displayLight: 1), 2.6, accuracy: 1e-12)
    }

    // MARK: - The film in the app's pipeline

    /// Through Development's own steps (the phone's highlights opened, Apple Log tones, the color cube), with the
    /// per-frame passes set aside: 216 phone colors, every mix of six levels of red, green and blue, come out as the
    /// generator's exact function develops them, to 0.03 at worst and 0.003 on average. The cube has 64 tones a side,
    /// read between its tones in straight lines, and Core Image keeps it in 8 bits, so the agreement is not exact. The
    /// worst color is the phone's purest green, 0.025 off; every other is within 0.01. The generator's own tables,
    /// read as it reads them, are 0.073 (33 a side) and 0.068 (65 a side) off its exact function at that green.
    func testThePipelineDevelopsPhoneColorsAsTheGeneratorDoes() throws {
        var treatment = FilmLook.cinemaColor
        treatment.scene = nil
        let colors = Self.colors.display
        // One row of blocks, so the picture reads the same whichever way its rows run.
        let columns = colors.count, block = 8
        let width = columns * block, height = block
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for (index, color) in colors.enumerated() {
            for y in 0..<block { for x in 0..<block {
                let offset = (((index / columns) * block + y) * width + (index % columns) * block + x) * 4
                for channel in 0..<3 { bytes[offset + channel] = UInt8((color[channel] * 255).rounded()) }
            } }
        }
        let picture = CIImage(bitmapData: Data(bytes), bytesPerRow: width * 4, size: CGSize(width: width, height: height),
                              format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
        let developed = try Fixtures.tones(DevelopedTreatment(treatment, seed: 1).apply(to: picture))
        var worst = 0.0, total = 0.0
        for (index, expected) in Self.colors.displayDeveloped.enumerated() {
            let pixel = developed.pixel(x: (index % columns) * block + block / 2, y: (index / columns) * block + block / 2)
            for channel in 0..<3 {
                let difference = abs(pixel[channel] - expected[channel])
                worst = max(worst, difference)
                total += difference
            }
        }
        XCTAssertLessThan(worst, 0.03, "worst channel difference \(worst)")
        XCTAssertLessThan(total / Double(colors.count * 3), 0.003, "mean channel difference \(total / Double(colors.count * 3))")
    }

    /// The generator's neutral values through the same steps, for every one a phone picture can reach (its white is
    /// 3.85 stops over gray), within its tolerance of 0.02; and a neutral ramp of phone tones never reverses.
    func testThePipelineGivesTheNeutralValuesTheGeneratorStates() throws {
        var treatment = FilmLook.cinemaColor
        treatment.scene = nil
        for (stops, expected) in Self.colors.sanity where Double(stops)! < 4 {
            // The phone tone whose scene light is that many stops from middle gray: its white for 3.85 stops.
            let scene = 0.18 * pow(2, Double(stops)!)
            let tone = Double(stops)! > 3 ? 1 : FilmLook.NegativeFilm.displayTone(scene)
            let level = (tone * 255).rounded() / 255
            let wanted = Double(stops)! > 3 ? expected : {
                let exact = film.developed(display: gray(level))
                return [exact.red, exact.green, exact.blue]
            }()
            let developed = try Fixtures.tones(DevelopedTreatment(treatment, seed: 1).apply(to: Fixtures.even(tone: level)))
            let pixel = developed.pixel(x: 8, y: 8)
            for channel in 0..<3 {
                XCTAssertEqual(pixel[channel], wanted[channel], accuracy: 0.01, "\(stops) stops, channel \(channel)")
                XCTAssertEqual(pixel[channel], expected[channel], accuracy: 0.02, "\(stops) stops, channel \(channel)")
            }
        }
        var bytes = [UInt8](repeating: 255, count: 256 * 4 * 4)
        for y in 0..<4 { for x in 0..<256 { for channel in 0..<3 { bytes[(y * 256 + x) * 4 + channel] = UInt8(x) } } }
        let ramp = CIImage(bitmapData: Data(bytes), bytesPerRow: 256 * 4, size: CGSize(width: 256, height: 4), format: .RGBA8,
                           colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
        let developed = try Fixtures.tones(DevelopedTreatment(treatment, seed: 1).apply(to: ramp))
        for x in 1..<256 {
            for channel in 0..<3 {
                XCTAssertGreaterThanOrEqual(developed.pixel(x: x, y: 2)[channel], developed.pixel(x: x - 1, y: 2)[channel] - 0.0005,
                                            "tone \(x), channel \(channel)")
            }
        }
    }
}

/// Fixture files and the pictures tests make and read.
enum Fixtures {
    static func url(_ path: String) -> URL {
        Bundle.module.url(forResource: "Fixtures", withExtension: nil)!.appendingPathComponent(path)
    }

    /// A developed picture's display tones (sRGB), unrounded, rows from the top.
    struct Tones {
        let width: Int, height: Int
        let values: [Float]

        func pixel(x: Int, y: Int) -> [Double] {
            let offset = (y * width + x) * 4
            return [Double(values[offset]), Double(values[offset + 1]), Double(values[offset + 2])]
        }
    }

    static func tones(_ image: CIImage) throws -> Tones {
        let width = Int(image.extent.width), height = Int(image.extent.height)
        var values = [Float](repeating: 0, count: width * height * 4)
        // Core Image writes a bitmap's rows from the top of the picture.
        CIContext(options: [.cacheIntermediates: false]).render(
            image, toBitmap: &values, rowBytes: width * 16, bounds: CGRect(x: 0, y: 0, width: width, height: height),
            format: .RGBAf, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
        return Tones(width: width, height: height, values: values)
    }

    /// An even picture of one display tone.
    static func even(tone: Double, width: Int = 16, height: Int = 16) -> CIImage {
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for index in stride(from: 0, to: bytes.count, by: 4) { for channel in 0..<3 { bytes[index + channel] = UInt8((tone * 255).rounded()) } }
        return CIImage(bitmapData: Data(bytes), bytesPerRow: width * 4, size: CGSize(width: width, height: height), format: .RGBA8,
                       colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
    }

    /// A fixture picture, as the phone would deliver it.
    static func picture(_ path: String) throws -> CIImage {
        try XCTUnwrap(CIImage(contentsOf: url(path)))
    }
}
