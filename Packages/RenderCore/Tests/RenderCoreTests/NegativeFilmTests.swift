import CoreImage
import FilmDomain
import XCTest
@testable import RenderCore

/// The color negative Film Stocks develop exactly as the captain's generators do
/// (`Probes/FilmLookCalibration`): the 16mm Cinema's with `vision3_250d_lut.py`'s "print" look, and the 6×6 Medium
/// Format's with `portra400_lut.py`'s "scan" look, read from the table that generator wrote. The fixtures are the
/// generators' own numbers, written by the `make_fixtures.py` beside each.
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
        /// For a stock read from the generator's table: tones between the table's own with the table's reading of
        /// them, the table's reading of the phone colors, and the matrices of the photograph's way in.
        let tableTones: [[Double]]?, tableRead: [[Double]]?, displayTable: [[Double]]?
        let displayP3ToRec2020: [[Double]]?, rec709ToDisplayP3: [[Double]]?
    }

    /// One color negative Film Stock and the generator's numbers for it.
    private struct Stock {
        let name: String
        let folder: String
        let treatment: FilmLook.Treatment
        /// The primaries a capture from this Camera arrives on.
        let capture: CGColorSpace
        let colors: Colors

        init(_ name: String, folder: String, treatment: FilmLook.Treatment, capture: CFString) {
            self.name = name
            self.folder = folder
            self.treatment = treatment
            self.capture = CGColorSpace(name: capture)!
            colors = try! JSONDecoder().decode(Colors.self, from: Data(contentsOf: Fixtures.url("\(folder)/colors.json")))
        }

        var film: FilmLook.NegativeFilm {
            guard case let .negative(film) = treatment.emulsion else { fatalError("\(name) is a negative film") }
            return film
        }

        /// The treatment with the per-frame passes set aside, but the capture's way in kept.
        var filmAlone: FilmLook.Treatment {
            var treatment = treatment
            treatment.scene = FilmLook.ScenePasses(referenceWidth: treatment.scene!.referenceWidth, capture: treatment.scene!.capture)
            return treatment
        }
    }

    private static let cinema = Stock("16mm color", folder: "Cinema16mmColor", treatment: FilmLook.cinemaColor, capture: CGColorSpace.sRGB)
    private static let mediumFormat = Stock("6x6 color", folder: "MediumFormatColor", treatment: FilmLook.mediumFormatColor,
                                            capture: CGColorSpace.displayP3)
    private static let stocks = [cinema, mediumFormat]

    private func gray(_ level: Double) -> FilmLook.RGB { FilmLook.RGB(level, level, level) }
    private func color(_ values: [Double]) -> FilmLook.RGB { FilmLook.RGB(values[0], values[1], values[2]) }

    // MARK: - The film

    /// Every constant of each film is its generator's, read from the generator's own file. The 16mm develops with the
    /// "print" look and the 6×6 with the "scan" look; neither generator's other look is in the app.
    func testEveryConstantIsTheGenerators() {
        func bands(_ rows: [[Double]]) -> [FilmLook.NegativeFilm.Band] { rows.map { FilmLook.NegativeFilm.Band($0[0], $0[1], $0[2]) } }
        XCTAssertEqual(Self.cinema.colors.constants.curve, "print")
        XCTAssertEqual(Self.mediumFormat.colors.constants.curve, "scan")
        for stock in Self.stocks {
            let generator = stock.colors.constants, film = stock.film
            XCTAssertEqual(film.output, generator.curve == "print" ? .print(maximumDensity: generator.maximumDensity) : .scan, stock.name)
            XCTAssertEqual(film.negativeGamma, color(generator.negativeGamma), stock.name)
            XCTAssertEqual(film.exposure, generator.exposure, stock.name)
            XCTAssertEqual(film.balance, color(generator.balance), stock.name)
            XCTAssertEqual(film.toe, generator.toe, stock.name)
            XCTAssertEqual(film.crosstalk, generator.crosstalk.map(color), stock.name)
            XCTAssertEqual(film.slope, color(generator.slope), stock.name)
            XCTAssertEqual(film.grayDensity, generator.grayDensity, stock.name)
            XCTAssertEqual(film.bias, color(generator.bias), stock.name)
            XCTAssertEqual(film.black, color(generator.black), stock.name)
            XCTAssertEqual(film.bands, bands(generator.bands), stock.name)
            XCTAssertEqual(film.finish, bands(generator.finish), stock.name)
            XCTAssertEqual(film.highlightDesaturation, generator.highlightDesaturation, stock.name)
            XCTAssertEqual(film.shadowDesaturation, generator.shadowDesaturation, stock.name)
            XCTAssertEqual(FilmLook.NegativeFilm.bandCenters, generator.bandCenters, stock.name)
            XCTAssertEqual(FilmLook.NegativeFilm.bandWidths, generator.bandWidths, stock.name)
        }
    }

    /// Every neutral value each generator states for its look, from six stops under middle gray to five over, within
    /// its tolerance of 0.02.
    func testTheFilmGivesEveryNeutralValueTheGeneratorStates() {
        for stock in Self.stocks {
            XCTAssertEqual(stock.colors.sanity.count, 6, stock.name)
            for (stops, expected) in stock.colors.sanity {
                let developed = stock.film.developed(scene: gray(0.18 * pow(2, Double(stops)!)))
                XCTAssertEqual(developed.red, expected[0], accuracy: 0.02, "\(stock.name): \(stops) stops, red")
                XCTAssertEqual(developed.green, expected[1], accuracy: 0.02, "\(stock.name): \(stops) stops, green")
                XCTAssertEqual(developed.blue, expected[2], accuracy: 0.02, "\(stock.name): \(stops) stops, blue")
            }
        }
        // The 16mm: daylight gray develops neutral; shadows lean a hair cool and highlights a hair warm.
        let cinema = Self.cinema.film
        let middle = cinema.developed(scene: gray(0.18)), shadow = cinema.developed(scene: gray(0.045)), light = cinema.developed(scene: gray(0.72))
        XCTAssertEqual(middle.red, middle.blue, accuracy: 0.001)
        XCTAssertGreaterThan(shadow.blue, shadow.red)
        XCTAssertGreaterThan(light.red, light.blue)
        // The 6×6: gray develops a little bright and warm, and the scan's black is lifted and a hair cool.
        let roll = Self.mediumFormat.film
        let warm = roll.developed(scene: gray(0.18)), black = roll.developed(scene: gray(0.18 / 64))
        XCTAssertGreaterThan(warm.red, warm.green)
        XCTAssertGreaterThan(warm.green, warm.blue)
        XCTAssertGreaterThan(black.blue, black.red)
        XCTAssertGreaterThan(black.green, 0.06, "A lifted scan black")
    }

    /// A neutral ramp from eight stops under middle gray to seven over never reverses, in any channel.
    func testANeutralRampNeverReverses() {
        for stock in Self.stocks {
            var last = gray(-1)
            for step in 0..<200 {
                let developed = stock.film.developed(scene: gray(0.18 * pow(2, -8 + 15 * Double(step) / 199)))
                XCTAssertGreaterThanOrEqual(developed.red, last.red - 1e-6, "\(stock.name): step \(step)")
                XCTAssertGreaterThanOrEqual(developed.green, last.green - 1e-6, "\(stock.name): step \(step)")
                XCTAssertGreaterThanOrEqual(developed.blue, last.blue - 1e-6, "\(stock.name): step \(step)")
                last = developed
            }
        }
    }

    /// Each film agrees with its generator on 704 scene colors (a neutral ramp, a 7 x 7 x 7 grid of phone colors and
    /// 300 random ones up to five stops over gray) and on 425 Apple Log tones, to 0.00002 in every channel. The
    /// fixture's values are rounded to six places.
    func testTheFilmMatchesTheGeneratorOnAWideSetOfColors() {
        for stock in Self.stocks {
            XCTAssertEqual(stock.colors.scene.count, 704)
            XCTAssertEqual(stock.colors.appleLog.count, 425)
            var worst = 0.0
            for (input, expected) in zip(stock.colors.scene, stock.colors.sceneDeveloped) {
                let developed = stock.film.developed(scene: color(input))
                worst = max(worst, abs(developed.red - expected[0]), abs(developed.green - expected[1]), abs(developed.blue - expected[2]))
            }
            XCTAssertLessThan(worst, 0.00002, "\(stock.name): scene colors")
            worst = 0
            for (input, expected) in zip(stock.colors.appleLog, stock.colors.appleLogDeveloped) {
                let developed = stock.film.developed(appleLog: color(input))
                worst = max(worst, abs(developed.red - expected[0]), abs(developed.green - expected[1]), abs(developed.blue - expected[2]))
            }
            XCTAssertLessThan(worst, 0.00002, "\(stock.name): Apple Log tones")
        }
    }

    /// The curve into Apple Log and the one back agree, and the phone's white opens to 2.6 in scene light.
    func testAppleLogAndSceneLight() {
        for light in [0.0, 0.005, 0.01, 0.18, 1, 2.6, 6] {
            XCTAssertEqual(FilmLook.NegativeFilm.appleLogDecoded(FilmLook.NegativeFilm.appleLogEncoded(light)), light, accuracy: 1e-9)
        }
        XCTAssertEqual(FilmLook.NegativeFilm.sceneLight(displayLight: 0.5), 0.5)
        XCTAssertEqual(FilmLook.NegativeFilm.sceneLight(displayLight: 1), 2.6, accuracy: 1e-12)
    }

    // MARK: - The 6×6's table

    /// The 6×6 is read from the generator's own table, the file the captain sent
    /// (`immerse_6x6_color_scan_applelog_33.cube`). The table the app makes from his constants is that file, tone for
    /// tone, at all 35,937 of its tones, to the file's six places.
    func testTheTableTheAppMakesIsTheCaptainsTable() throws {
        guard case let .appleLog(side) = Self.mediumFormat.film.table else { return XCTFail("The 6×6 is read from a table") }
        XCTAssertEqual(side, 33)
        let file = try Fixtures.table("MediumFormatColor/immerse_6x6_color_scan_applelog_33.cube")
        XCTAssertEqual(file.side, 33)
        let made = Self.mediumFormat.film.appleLogTable(side: side)
        XCTAssertEqual(made.count, 35_937)
        var worst = 0.0
        for (ours, his) in zip(made, file.tones) {
            // The file holds display tones between 0 and 1.
            func held(_ value: Double) -> Double { min(max(value, 0), 1) }
            worst = max(worst, abs(held(ours.red) - his.red), abs(held(ours.green) - his.green), abs(held(ours.blue) - his.blue))
        }
        XCTAssertLessThan(worst, 0.000001, "worst difference \(worst)")
        XCTAssertEqual(Self.cinema.film.table, .function, "The 16mm follows its generator's function, which sent no table")
    }

    /// The app reads a table between its tones tetrahedrally, as the captain's spec and his own preview do: on 3,000
    /// tones between the table's own, the app's reading of his file is his reader's, to 0.000002.
    func testTheTableIsReadTetrahedrally() throws {
        let file = try Fixtures.table("MediumFormatColor/immerse_6x6_color_scan_applelog_33.cube")
        let colors = Self.mediumFormat.colors
        let tones = try XCTUnwrap(colors.tableTones), expected = try XCTUnwrap(colors.tableRead)
        XCTAssertEqual(tones.count, 3000)
        var worst = 0.0
        for (tone, want) in zip(tones, expected) {
            let read = FilmLook.NegativeFilm.tetrahedral(file.tones, side: file.side, at: color(tone))
            worst = max(worst, abs(read.red - want[0]), abs(read.green - want[1]), abs(read.blue - want[2]))
        }
        XCTAssertLessThan(worst, 0.000002, "worst difference \(worst)")
        // The cube Core Image is handed holds that reading at every tone of the table and halfway between each pair.
        let cube = Self.mediumFormat.film.cube()
        XCTAssertEqual(cube.dimension, 65)
        let steps = cube.steps.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        let remainders = cube.remainders.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        for (red, green, blue) in [(0, 0, 0), (64, 64, 64), (32, 0, 64), (17, 40, 3), (1, 1, 1), (63, 2, 31)] {
            let read = FilmLook.NegativeFilm.tetrahedral(file.tones, side: file.side,
                                                         at: FilmLook.RGB(Double(red) / 64, Double(green) / 64, Double(blue) / 64))
            let index = (blue * 65 + green) * 65 + red
            for (channel, want) in [read.red, read.green, read.blue].enumerated() {
                // The two cubes Core Image is handed add up to the value: whole 8-bit steps and a share of one step.
                let whole = Double(steps[index * 4 + channel]), rest = Double(remainders[index * 4 + channel])
                XCTAssertEqual((whole * 255).rounded(), whole * 255, accuracy: 0.0001)
                XCTAssertTrue((0...1).contains(rest))
                XCTAssertEqual(whole + rest / 255, want, accuracy: 0.000002)
            }
        }
    }

    /// The matrices of a photograph's way in are the standards': Rec.709 to Display P3, and Display P3 to Rec.2020 as
    /// the spec has it computed.
    func testAPhotographsWayInUsesTheStandardsMatrices() throws {
        let colors = Self.mediumFormat.colors
        for (ours, theirs) in [(SceneLight.rec2020FromDisplayP3, try XCTUnwrap(colors.displayP3ToRec2020)),
                               (SceneLight.displayP3FromRec709, try XCTUnwrap(colors.rec709ToDisplayP3))] {
            for row in 0..<3 { for column in 0..<3 { XCTAssertEqual(ours[row][column], theirs[row][column], accuracy: 0.00000001) } }
        }
        XCTAssertEqual(Self.mediumFormat.treatment.scene?.capture, .displayP3)
        XCTAssertEqual(Self.cinema.treatment.scene?.capture, .rec709)
    }

    // MARK: - The film in the app's pipeline

    /// 216 phone colors, every mix of six levels of red, green and blue on the capture's own primaries, through
    /// Development's own steps with the per-frame passes set aside, as a picture of one row of blocks.
    private func developedPhoneColors(_ stock: Stock) throws -> [[Double]] {
        let colors = stock.colors.display
        // One row of blocks, so the picture reads the same whichever way its rows run.
        let block = 8, width = colors.count * block, height = block
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for (index, color) in colors.enumerated() {
            for y in 0..<block { for x in 0..<block {
                let offset = (y * width + index * block + x) * 4
                for channel in 0..<3 { bytes[offset + channel] = UInt8((color[channel] * 255).rounded()) }
            } }
        }
        let picture = CIImage(bitmapData: Data(bytes), bytesPerRow: width * 4, size: CGSize(width: width, height: height),
                              format: .RGBA8, colorSpace: stock.capture)
        let developed = try Fixtures.tones(DevelopedTreatment(stock.filmAlone, seed: 1).apply(to: picture))
        return colors.indices.map { developed.pixel(x: $0 * block + block / 2, y: block / 2) }
    }

    /// The worst and the mean difference, in any channel, between developed colors and the ones expected, and the
    /// difference 99 percent of values stay within.
    private func difference(_ developed: [[Double]], _ expected: [[Double]]) -> (worst: Double, mean: Double, most: Double) {
        var differences: [Double] = []
        for (pixel, want) in zip(developed, expected) { for channel in 0..<3 { differences.append(abs(pixel[channel] - want[channel])) } }
        differences.sort()
        return (differences.last!, differences.reduce(0, +) / Double(differences.count), differences[differences.count * 99 / 100])
    }

    /// The 16mm through the pipeline (the phone's highlights opened, Apple Log tones, the color cube): the 216 phone
    /// colors come out as the generator's exact function develops them, to 0.03 at worst and 0.003 on average
    /// (measured: 0.024 and 0.0005). The cube has 64 tones a side, read between its tones in straight lines, so the
    /// agreement is not exact. The worst color is the phone's purest green; every other is within 0.01. The
    /// generator's own tables, read as it reads them, are 0.073 (33 a side) and 0.068 (65 a side) off its exact
    /// function at that green.
    func testThePipelineDevelopsPhoneColorsAsTheGeneratorDoes() throws {
        let result = difference(try developedPhoneColors(Self.cinema), Self.cinema.colors.displayDeveloped)
        XCTAssertLessThan(result.worst, 0.03, "worst channel difference \(result.worst)")
        XCTAssertLessThan(result.mean, 0.003, "mean channel difference \(result.mean)")
    }

    /// The 6×6 through the pipeline (Display P3 opened, carried to Rec.2020, Apple Log tones, the color cube): the 216
    /// phone colors come out as the captain's own table gives them, read tetrahedrally, to 0.001 on average, 0.01 for
    /// 99 percent of values and 0.04 at worst (measured: 0.0006, 0.006 and 0.030, on a bright cyan). Core Image reads
    /// a cube in straight lines along each axis, so the cube holds the table's tetrahedral reading at twice its
    /// tones; what is left is the difference between the two readings inside those half-size cells, largest on the
    /// most saturated colors.
    ///
    /// His table is not his function between its tones: on these colors the two are 0.0025 apart on average and up to
    /// 0.08 apart on the most saturated ones, so the pipeline, which follows the table, is as far from the function.
    func testThePipelineDevelopsPhoneColorsAsTheCaptainsTableDoes() throws {
        let stock = Self.mediumFormat
        let developed = try developedPhoneColors(stock)
        let table = difference(developed, try XCTUnwrap(stock.colors.displayTable))
        XCTAssertLessThan(table.mean, 0.001, "mean difference from his table \(table.mean)")
        XCTAssertLessThan(table.most, 0.01, "99 percent within \(table.most) of his table")
        XCTAssertLessThan(table.worst, 0.04, "worst difference from his table \(table.worst)")
        let between = difference(try XCTUnwrap(stock.colors.displayTable), stock.colors.displayDeveloped)
        XCTAssertEqual(between.mean, 0.0025, accuracy: 0.0005, "His table and his function, on average")
        XCTAssertEqual(between.worst, 0.078, accuracy: 0.005, "His table and his function, at worst")
        let function = difference(developed, stock.colors.displayDeveloped)
        XCTAssertLessThan(function.mean, 0.004, "mean difference from his function \(function.mean)")
        XCTAssertLessThan(function.worst, 0.1, "worst difference from his function \(function.worst)")
    }

    /// Each generator's neutral values through the same steps, for every one a phone picture can reach (its white is
    /// 3.85 stops over gray), within the generator's tolerance of 0.02 and within 0.01 of its exact function; and a
    /// neutral ramp of phone tones never reverses.
    func testThePipelineGivesTheNeutralValuesTheGeneratorStates() throws {
        for stock in Self.stocks {
            for (stops, expected) in stock.colors.sanity where Double(stops)! < 4 {
                // The phone tone whose scene light is that many stops from middle gray: its white for 3.85 stops.
                let scene = 0.18 * pow(2, Double(stops)!)
                let tone = Double(stops)! > 3 ? 1 : FilmLook.NegativeFilm.displayTone(scene)
                let level = (tone * 255).rounded() / 255
                let exact = stock.film.developed(display: gray(level))
                let developed = try Fixtures.tones(DevelopedTreatment(stock.filmAlone, seed: 1).apply(
                    to: Fixtures.even(tone: level, colorSpace: stock.capture)))
                let pixel = developed.pixel(x: 8, y: 8)
                for (channel, wanted) in [exact.red, exact.green, exact.blue].enumerated() {
                    XCTAssertEqual(pixel[channel], wanted, accuracy: 0.01, "\(stock.name): \(stops) stops, channel \(channel)")
                    // The phone's tone is the nearest of its 256 to the stated light, a little off it in deep shadow.
                    XCTAssertEqual(pixel[channel], expected[channel], accuracy: 0.02, "\(stock.name): \(stops) stops, channel \(channel)")
                }
            }
            var bytes = [UInt8](repeating: 255, count: 256 * 4 * 4)
            for y in 0..<4 { for x in 0..<256 { for channel in 0..<3 { bytes[(y * 256 + x) * 4 + channel] = UInt8(x) } } }
            let ramp = CIImage(bitmapData: Data(bytes), bytesPerRow: 256 * 4, size: CGSize(width: 256, height: 4), format: .RGBA8,
                               colorSpace: stock.capture)
            let developed = try Fixtures.tones(DevelopedTreatment(stock.filmAlone, seed: 1).apply(to: ramp))
            for x in 1..<256 {
                for channel in 0..<3 {
                    XCTAssertGreaterThanOrEqual(developed.pixel(x: x, y: 2)[channel], developed.pixel(x: x - 1, y: 2)[channel] - 0.0005,
                                                "\(stock.name): tone \(x), channel \(channel)")
                }
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

    /// An even picture of one display tone, on sRGB's primaries unless another space is given.
    static func even(tone: Double, width: Int = 16, height: Int = 16,
                     colorSpace: CGColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!) -> CIImage {
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for index in stride(from: 0, to: bytes.count, by: 4) { for channel in 0..<3 { bytes[index + channel] = UInt8((tone * 255).rounded()) } }
        return CIImage(bitmapData: Data(bytes), bytesPerRow: width * 4, size: CGSize(width: width, height: height), format: .RGBA8,
                       colorSpace: colorSpace)
    }

    /// A color table file (.cube): its tones a side and its colors, red varying fastest.
    static func table(_ path: String) throws -> (side: Int, tones: [FilmLook.RGB]) {
        var side = 0
        var tones: [FilmLook.RGB] = []
        for line in try String(contentsOf: url(path), encoding: .utf8).split(separator: "\n") {
            let parts = line.split(separator: " ")
            if parts.first == "LUT_3D_SIZE" { side = Int(parts[1])! }
            if parts.count == 3, let red = Double(parts[0]), let green = Double(parts[1]), let blue = Double(parts[2]) {
                tones.append(FilmLook.RGB(red, green, blue))
            }
        }
        XCTAssertEqual(tones.count, side * side * side)
        return (side, tones)
    }

    /// A fixture picture, as the phone would deliver it.
    static func picture(_ path: String) throws -> CIImage {
        try XCTUnwrap(CIImage(contentsOf: url(path)))
    }
}
