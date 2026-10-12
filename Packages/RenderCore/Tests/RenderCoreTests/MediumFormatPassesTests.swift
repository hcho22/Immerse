import CoreImage
import FilmDomain
import XCTest
@testable import RenderCore

/// The 6×6 Medium Format's passes on its color Film Stock are section 5 of the captain's spec
/// (`Probes/FilmLookCalibration/6x6/2026-10-12-6x6-color-film-stock-look-spec.md`): a mild lens vignette and very fine
/// grain, and nothing else. The spec gives formulas and numbers, not reference code, so `make_fixtures.py` beside it
/// writes the passes out from them, with the 16mm reference's own functions where the spec says the shader is the
/// same. The fixture frames are developed through the captain's own table; what is random is compared by its
/// statistics.
final class MediumFormatPassesTests: XCTestCase {
    private struct Passes: Decodable {
        struct Grain: Decodable {
            let width: Int
            let deviation: [Double], expectedDeviation: [Double]
            let redGreen: Double, redBlue: Double, greenBlue: Double
            let lags: [Int], greenAcrossLags: [Double], greenDownLags: [Double], redAcrossLags: [Double]
            let spreadOnMiddleGray: [Double]
        }
        /// Section 5's numbers, as `make_fixtures.py` holds them.
        struct Constants: Decodable {
            struct Vignette: Decodable { let amount: Double, start: Double, end: Double, power: Double }
            struct Grain: Decodable {
                let deviation: [Double], strength: Double, size: Double, secondOctave: [Double], shared: Double, ceiling: Double
            }
            struct SixteenMillimeterGrain: Decodable { let deviation: [Double], strength: Double }
            let vignette: Vignette, grain: Grain, sixteenMillimeterGrain: SixteenMillimeterGrain, referenceWidth: Double
        }
        let grain: Grain
        let constants: Constants
    }

    private static let folder = "MediumFormatColor"
    private static let passes: Passes = try! JSONDecoder().decode(Passes.self, from: Data(contentsOf: Fixtures.url("\(folder)/passes.json")))
    private static let displayP3 = CGColorSpace(name: CGColorSpace.displayP3)!
    /// The side of the 6×6's developed master.
    private static let masterSide = 3072

    private var look: FilmLook.Treatment { FilmLook.mediumFormatColor }
    private var scene: FilmLook.ScenePasses { FilmLook.mediumFormatColor.scene! }
    private var film: FilmLook.NegativeFilm {
        guard case let .negative(film) = look.emulsion else { fatalError("The 6×6 color stock is a negative film") }
        return film
    }

    /// The fixture frame as the phone delivers a photograph: its bytes are Display P3 tones.
    private func frame() throws -> CIImage {
        let bytes = try Fixtures.bytes("\(Self.folder)/frame.png")
        let side = Int(Double(bytes.count / 4).squareRoot())
        return CIImage(bitmapData: Data(bytes), bytesPerRow: side * 4, size: CGSize(width: side, height: side), format: .RGBA8,
                       colorSpace: Self.displayP3)
    }

    /// The fixture frame developed with only the passes a test names.
    private func developed(seed: UInt64 = 9, _ change: (inout FilmLook.ScenePasses) -> Void) throws -> Fixtures.Tones {
        var treatment = look
        var passes = FilmLook.ScenePasses(referenceWidth: scene.referenceWidth, capture: scene.capture)
        change(&passes)
        treatment.scene = passes
        return try Fixtures.tones(DevelopedTreatment(treatment, seed: seed).apply(to: frame()))
    }

    // Tolerances for a whole frame against the reference's, in display tone (0 to 1): the mean difference, the
    // difference 99 percent of values stay within, and the largest. The reference frames are 8-bit and are his table
    // read tetrahedrally, as Development reads it; the tolerances also hold where Core Image's own cube reads it
    // (`NegativeFilmTests`).
    private func assertMatches(_ tones: Fixtures.Tones, _ fixture: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let expected = try Fixtures.bytes("\(Self.folder)/\(fixture)")
        XCTAssertEqual(expected.count, tones.values.count, file: file, line: line)
        var differences: [Double] = []
        for index in stride(from: 0, to: expected.count, by: 4) {
            for channel in 0..<3 { differences.append(abs(Double(tones.values[index + channel]) - Double(expected[index + channel]) / 255)) }
        }
        differences.sort()
        let mean = differences.reduce(0, +) / Double(differences.count), most = differences[differences.count * 99 / 100]
        XCTAssertLessThan(mean, 0.003, "\(fixture): mean \(mean)", file: file, line: line)
        XCTAssertLessThan(most, 0.01, "\(fixture): 99 percent within \(most)", file: file, line: line)
        XCTAssertLessThan(differences.last!, 0.04, "\(fixture): worst \(differences.last!)", file: file, line: line)
    }

    // MARK: - What the spec gives the Camera, and what it leaves out

    /// Every constant of the passes is section 5's: the vignette's amount, reach and curve, and the grain's per-layer
    /// strengths, default strength, size, second octave and shared part, at the spec's frame width. The grain stays
    /// under the spec's ceiling of 0.6 times the 16mm Cinema's.
    func testEveryConstantIsTheSpecs() throws {
        let spec = Self.passes.constants
        XCTAssertEqual(scene.referenceWidth, spec.referenceWidth)
        XCTAssertEqual(scene.vignette, FilmLook.ScenePasses.Vignette(amount: spec.vignette.amount, start: spec.vignette.start,
                                                                     end: spec.vignette.end, power: spec.vignette.power))
        XCTAssertEqual(scene.grain, FilmLook.ScenePasses.Grain(
            deviation: FilmLook.RGB(spec.grain.deviation[0], spec.grain.deviation[1], spec.grain.deviation[2]),
            strength: spec.grain.strength, size: spec.grain.size, secondOctaveSize: spec.grain.secondOctave[0],
            secondOctaveWeight: spec.grain.secondOctave[1], shared: spec.grain.shared))
        XCTAssertEqual(GrainField.count, 8, "Eight tiles, a new one and a new offset for each photograph")

        let grain = try XCTUnwrap(scene.grain), cinema = try XCTUnwrap(FilmLook.cinemaColor.scene?.grain)
        XCTAssertEqual([cinema.deviation.red, cinema.deviation.green, cinema.deviation.blue], spec.sixteenMillimeterGrain.deviation)
        XCTAssertEqual(cinema.strength, spec.sixteenMillimeterGrain.strength)
        for (ours, theirs) in [(grain.deviation.red, cinema.deviation.red), (grain.deviation.green, cinema.deviation.green),
                               (grain.deviation.blue, cinema.deviation.blue)] {
            XCTAssertLessThanOrEqual(ours * grain.strength, spec.grain.ceiling * theirs * cinema.strength)
        }
    }

    /// What the spec lists as off for this Camera is off: no halation, no softening of the picture or its edges, no
    /// weave, flicker, dust or hair, no flash look and no variation from print to print. A photograph arrives on
    /// Display P3's primaries.
    func testThePassesTheSpecLeavesOutAreOff() {
        XCTAssertNil(scene.halation)
        XCTAssertNil(scene.softEdges)
        XCTAssertEqual(scene.softness, 0)
        XCTAssertNil(scene.weave)
        XCTAssertEqual(scene.capture, .displayP3)
        XCTAssertEqual(look.lens, FilmLook.Lens())
        XCTAssertNil(look.halation)
        XCTAssertNil(look.gate)
        XCTAssertNil(look.flash)
        XCTAssertNil(look.printVariation)
    }

    // MARK: - The passes with nothing random

    /// With no passes the photograph is the captain's table alone, through the spec's way in for a photograph.
    func testThePhotographWithNoPassesIsTheTableAlone() throws {
        try assertMatches(developed { _ in }, "frame-look-only.png")
    }

    /// The lens vignette: the spec's fall of 0.18 at the corners, about 0.3 of a stop, from nothing at 0.30 of the way
    /// out along its curve of 1.6, in the scene's light before the film.
    func testTheLensVignetteMatchesTheSpec() throws {
        try assertMatches(developed { $0.vignette = self.scene.vignette }, "frame-vignette.png")

        // On an even gray, the center is untouched and the corner has 0.82 of the scene's light.
        try XCTSkipUnless(TableReading.kernel != nil, "Core Image cannot run the tetrahedral reader here")
        var treatment = look
        treatment.scene = FilmLook.ScenePasses(referenceWidth: scene.referenceWidth, capture: scene.capture, vignette: scene.vignette)
        let level = 118.0 / 255
        let even = try Fixtures.tones(DevelopedTreatment(treatment, seed: 1).apply(
            to: Fixtures.even(tone: level, width: 240, height: 240, colorSpace: Self.displayP3)))
        let table = film.appleLogTable(side: 33)
        func expected(_ share: Double) -> FilmLook.RGB {
            let tone = FilmLook.NegativeFilm.appleLogEncoded(share * FilmLook.NegativeFilm.displayLight(level))
            return FilmLook.NegativeFilm.tetrahedral(table, side: 33, at: FilmLook.RGB(tone, tone, tone))
        }
        let center = even.pixel(x: 120, y: 120), corner = even.pixel(x: 0, y: 0)
        let whole = expected(1), fallen = expected(1 - scene.vignette!.amount)
        XCTAssertEqual(center[1], whole.green, accuracy: 0.002)
        XCTAssertEqual(corner[1], fallen.green, accuracy: 0.002)
        XCTAssertLessThan(corner[1], center[1] - 0.03, "Darker corners")
        XCTAssertEqual(log2(1 - scene.vignette!.amount), -0.29, accuracy: 0.01, "About 0.3 of a stop")
    }

    /// Nothing softens the picture: the fine detail of the test frame, checks two pixels wide, keeps the contrast the
    /// reference's has, where the least blur would take most of it away.
    func testNothingSoftensThePicture() throws {
        let tones = try developed { $0.vignette = self.scene.vignette; $0.grain = self.scene.grain }
        let expected = try Fixtures.bytes("\(Self.folder)/frame-vignette.png")
        func spread(_ value: (Int) -> Double) -> Double {
            var values: [Double] = []
            for y in 134..<202 { for x in 110..<158 { values.append(value((y * tones.width + x) * 4 + 1)) } }
            let mean = values.reduce(0, +) / Double(values.count)
            return (values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count)).squareRoot()
        }
        let got = spread { Double(tones.values[$0]) }, want = spread { Double(expected[$0]) / 255 }
        XCTAssertGreaterThan(want, 0.15, "The checks are there")
        XCTAssertEqual(got, want, accuracy: want * 0.02)
    }

    // MARK: - Grain

    /// The grain field has the make-up the spec's numbers give the 16mm's shader, measured as that shader's own
    /// field measures at the width of the 6×6's master: each layer shares most of its grain with the others, and
    /// neighboring pixels are alike by the same amounts across and down, from its two octaves.
    func testTheGrainFieldMeasuresAsTheSpecsDoes() {
        let grain = scene.grain!, fixture = Self.passes.grain
        XCTAssertEqual(fixture.width, Self.masterSide)
        let side = GrainField.side
        let values = GrainField.field(size: grain.size * Double(fixture.width), grain: grain, seed: 4)
        func layer(_ channel: Int) -> [Double] { stride(from: channel, to: values.count, by: 4).map { Double(values[$0]) } }
        func correlation(_ first: [Double], _ second: [Double]) -> Double {
            let count = Double(first.count)
            let firstMean = first.reduce(0, +) / count, secondMean = second.reduce(0, +) / count
            var product = 0.0, firstSpread = 0.0, secondSpread = 0.0
            for index in first.indices {
                product += (first[index] - firstMean) * (second[index] - secondMean)
                firstSpread += pow(first[index] - firstMean, 2); secondSpread += pow(second[index] - secondMean, 2)
            }
            return product / (firstSpread * secondSpread).squareRoot()
        }
        func shifted(_ values: [Double], across: Int, down: Int) -> [Double] {
            (0..<values.count).map { values[(($0 / side + down) % side) * side + ($0 % side + across) % side] }
        }
        let red = layer(0), green = layer(1), blue = layer(2)
        XCTAssertEqual(correlation(red, green), fixture.redGreen, accuracy: 0.01)
        XCTAssertEqual(correlation(red, blue), fixture.redBlue, accuracy: 0.01)
        XCTAssertEqual(correlation(green, blue), fixture.greenBlue, accuracy: 0.01)
        for (index, lag) in fixture.lags.enumerated() {
            XCTAssertEqual(correlation(green, shifted(green, across: lag, down: 0)), fixture.greenAcrossLags[index], accuracy: 0.02, "green, \(lag) across")
            XCTAssertEqual(correlation(green, shifted(green, across: 0, down: lag)), fixture.greenDownLags[index], accuracy: 0.02, "green, \(lag) down")
            XCTAssertEqual(correlation(red, shifted(red, across: lag, down: 0)), fixture.redAcrossLags[index], accuracy: 0.02, "red, \(lag) across")
        }
    }

    /// Added to a photograph's Apple Log tones, the grain has the spec's strength in each layer at the master's width
    /// (its per-pixel deviation, its default strength of 1.5, scaled with the frame's width), within 5 percent; it
    /// leaves the tone where it was; each photograph has a pattern of its own; and a photograph keeps the one it was
    /// given, since a Developed Treatment is assigned once.
    func testTheGrainHasTheSpecsStrengthAndEachPhotographItsOwn() {
        let grain = scene.grain!, fixture = Self.passes.grain
        let extent = CGRect(x: 0, y: 0, width: fixture.width, height: 256)
        func field(seed: UInt64) -> Fixtures.Tones {
            Fixtures.values(DevelopedTreatment(look, seed: seed).grained(Fixtures.light(0.5, in: extent), grain, width: Double(fixture.width),
                                                                         referenceWidth: scene.referenceWidth, frame: 0))
        }
        let first = field(seed: 77), second = field(seed: 78), again = field(seed: 77)
        for channel in 0..<3 {
            let values = first.channel(channel)
            let mean = values.reduce(0, +) / Double(values.count)
            let deviation = (values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count)).squareRoot()
            XCTAssertEqual(mean, 0.5, accuracy: 0.0002, "The grain adds no tone of its own")
            XCTAssertEqual(deviation, fixture.expectedDeviation[channel], accuracy: fixture.expectedDeviation[channel] * 0.05, "layer \(channel)")
            XCTAssertEqual(fixture.deviation[channel], fixture.expectedDeviation[channel], accuracy: fixture.expectedDeviation[channel] * 0.05)
        }
        XCTAssertGreaterThan(first.meanDifference(from: second), 0.001, "Another photograph has another pattern")
        XCTAssertEqual(first.meanDifference(from: again), 0, "The same photograph keeps its pattern")
    }

    /// Through the whole of Development the grain is very fine: on an even middle gray at the master's width it
    /// spreads each channel's tones as the spec's does through the captain's table, within a tenth, which is about
    /// one 8-bit step in green.
    func testTheGrainIsVeryFineOnMiddleGray() throws {
        try XCTSkipUnless(TableReading.kernel != nil, "Core Image cannot run the tetrahedral reader here")
        var treatment = look
        treatment.scene = FilmLook.ScenePasses(referenceWidth: scene.referenceWidth, capture: scene.capture, grain: scene.grain)
        // The phone tone nearest middle gray's light of 0.18.
        let gray = Fixtures.even(tone: 118.0 / 255, width: Self.masterSide, height: 256, colorSpace: Self.displayP3)
        let tones = try Fixtures.tones(DevelopedTreatment(treatment, seed: 21).apply(to: gray))
        for channel in 0..<3 {
            let values = tones.channel(channel)
            let mean = values.reduce(0, +) / Double(values.count)
            let spread = (values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count)).squareRoot()
            let want = Self.passes.grain.spreadOnMiddleGray[channel]
            XCTAssertEqual(spread, want, accuracy: want * 0.1, "channel \(channel): \(spread) against the spec's \(want)")
        }
        XCTAssertEqual(Self.passes.grain.spreadOnMiddleGray[1] * 255, 1.3, accuracy: 0.2, "About one 8-bit step in green")
    }

    // MARK: - The whole photograph

    /// The whole photograph, with its vignette and grain, beside the spec's own. Their grain was drawn differently, so
    /// they are compared in 12 x 12 blocks of 20 pixels: every block with no edge in it has the same mean tone to
    /// 0.006.
    func testTheWholeDevelopedPhotographComparesWithTheSpecs() throws {
        let tones = try Fixtures.tones(DevelopedTreatment(look, seed: 3).apply(to: frame()))
        let expected = try Fixtures.bytes("\(Self.folder)/frame-developed.png")
        let block = 20
        var even = 0
        for row in 0..<(tones.height / block) { for column in 0..<(tones.width / block) {
            var worst = 0.0, range = 0.0
            for channel in 0..<3 {
                var got = 0.0, want = 0.0, low = 1.0, high = 0.0
                for y in 0..<block { for x in 0..<block {
                    let offset = ((row * block + y) * tones.width + column * block + x) * 4 + channel
                    let value = Double(expected[offset]) / 255
                    got += Double(tones.values[offset]); want += value
                    low = min(low, value); high = max(high, value)
                } }
                worst = max(worst, abs(got - want) / Double(block * block))
                range = max(range, high - low)
            }
            // An edge spreads a block's tones by more than this; grain and the vignette's fall spread them by less.
            guard range < 0.12 else { continue }
            even += 1
            XCTAssertLessThan(worst, 0.006, "block \(column), \(row)")
        } }
        XCTAssertGreaterThan(even, 60, "Most of the frame is compared")
    }
}
