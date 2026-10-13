import CoreImage
import FilmDomain
import ImageIO
import XCTest
@testable import RenderCore

/// The 16mm Cinema's per-frame passes on its color Film Stock match the captain's reference
/// (`Probes/FilmLookCalibration/16mm/effects_16mm_reference.py`): its order and constants for halation, soft darkened
/// edges, overall softness, grain and weave. The fixture frames are that reference's own output for one small test
/// frame, written by `make_fixtures.py` beside it; what is random in the reference is compared by its statistics.
final class ScenePassesTests: XCTestCase {
    private struct Passes: Decodable {
        struct Weave: Decodable {
            struct Frame: Decodable { let time: Double, dx: Double, dy: Double, degrees: Double }
            let frame: Frame
            let phases: [[Double]], times: [Double], offsetsAtReferenceWidth: [[Double]]
        }
        struct Grain: Decodable {
            let width: Int
            let deviation: [Double], expectedDeviation: [Double]
            let redGreen: Double, redBlue: Double, greenBlue: Double
            let lags: [Int], greenAcrossLags: [Double], greenDownLags: [Double], redAcrossLags: [Double]
        }
        /// The reference file's own constants, as it holds them.
        struct Constants: Decodable {
            struct Halation: Decodable { let threshold: Double, near: Double, far: Double, nearTint: [Double], farTint: [Double], strength: Double }
            struct Edges: Decodable { let blur: Double, start: Double, end: Double, vignette: Double }
            struct Grain: Decodable { let deviation: [Double], strength: Double, size: Double, secondOctave: [Double], shared: Double }
            struct Weave: Decodable { let amplitude: [Double], frequencies: [Double], jitter: Double, rotation: Double, overscale: Double }
            let halation: Halation, edges: Edges, softness: Double, grain: Grain, weave: Weave, referenceWidth: Double
        }
        let weave: Weave
        let grain: Grain
        let constants: Constants
    }

    private static let passes: Passes = try! JSONDecoder().decode(Passes.self, from: Data(contentsOf: Fixtures.url("Cinema16mmColor/passes.json")))

    private var look: FilmLook.Treatment { FilmLook.cinemaColor }
    private var scene: FilmLook.ScenePasses { FilmLook.cinemaColor.scene! }

    /// The fixture frame developed with only the passes a test names.
    private func developed(_ change: (inout FilmLook.ScenePasses) -> Void) throws -> Fixtures.Tones {
        var treatment = look
        var passes = FilmLook.ScenePasses(referenceWidth: scene.referenceWidth)
        change(&passes)
        treatment.scene = passes
        return try Fixtures.tones(DevelopedTreatment(treatment, seed: 9).apply(to: Fixtures.picture("Cinema16mmColor/frame.png")))
    }

    /// The mean and the 99th-percentile difference in display tone between a developed frame and a fixture frame.
    private func difference(_ tones: Fixtures.Tones, from fixture: String) throws -> (mean: Double, most: Double, worst: Double) {
        let expected = try Fixtures.bytes("Cinema16mmColor/\(fixture)")
        XCTAssertEqual(expected.count, tones.values.count)
        var differences: [Double] = []
        for index in stride(from: 0, to: expected.count, by: 4) {
            for channel in 0..<3 { differences.append(abs(Double(tones.values[index + channel]) - Double(expected[index + channel]) / 255)) }
        }
        differences.sort()
        return (differences.reduce(0, +) / Double(differences.count), differences[differences.count * 99 / 100], differences.last!)
    }

    /// Every constant of the passes is the reference file's, read from the file itself.
    func testEveryConstantIsTheReferences() {
        let reference = Self.passes.constants
        func color(_ values: [Double]) -> FilmLook.RGB { FilmLook.RGB(values[0], values[1], values[2]) }
        XCTAssertEqual(scene.referenceWidth, reference.referenceWidth)
        XCTAssertEqual(scene.halation, FilmLook.ScenePasses.Halation(
            threshold: reference.halation.threshold, near: reference.halation.near, far: reference.halation.far,
            nearTint: color(reference.halation.nearTint), farTint: color(reference.halation.farTint), strength: reference.halation.strength))
        XCTAssertEqual(scene.softEdges, FilmLook.ScenePasses.SoftEdges(blur: reference.edges.blur, start: reference.edges.start, end: reference.edges.end))
        // The reference writes the vignette's reach and curve in its formula: from 0.35 to the corner, to the power 1.5.
        XCTAssertEqual(scene.vignette, FilmLook.ScenePasses.Vignette(amount: reference.edges.vignette, start: 0.35, end: 1.0, power: 1.5))
        XCTAssertEqual(scene.softness, reference.softness)
        XCTAssertEqual(scene.grain, FilmLook.ScenePasses.Grain(
            deviation: color(reference.grain.deviation), strength: reference.grain.strength, size: reference.grain.size,
            secondOctaveSize: reference.grain.secondOctave[0], secondOctaveWeight: reference.grain.secondOctave[1], shared: reference.grain.shared))
        XCTAssertEqual(scene.weave, FilmLook.ScenePasses.Weave(
            across: reference.weave.amplitude[0], down: reference.weave.amplitude[1], frequencies: reference.weave.frequencies,
            jitter: reference.weave.jitter, rotation: reference.weave.rotation, overscale: reference.weave.overscale))
    }

    // MARK: - The passes with nothing random

    // Tolerances for a whole frame against the reference's, in display tone (0 to 1): the mean difference, the
    // difference 99 percent of values stay within, and the largest. The reference frames are 8-bit, the cube is read
    // between its tones, and Core Image's blur treats a frame's border a little differently from the reference's, so
    // a few pixels at the rim of a lamp differ most.
    private func assertMatches(_ tones: Fixtures.Tones, _ fixture: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let result = try difference(tones, from: fixture)
        XCTAssertLessThan(result.mean, 0.003, "\(fixture): mean \(result.mean)", file: file, line: line)
        XCTAssertLessThan(result.most, 0.01, "\(fixture): 99 percent within \(result.most)", file: file, line: line)
        XCTAssertLessThan(result.worst, 0.08, "\(fixture): worst \(result.worst)", file: file, line: line)
    }

    /// With no passes the frame is the film alone.
    func testTheFrameWithNoPassesIsTheFilmAlone() throws {
        try requireTetrahedralReader()
        try assertMatches(developed { _ in }, "frame-look-only.png")
    }

    /// Halation: the reference's threshold, its near and far spreads and tints, and its strength.
    func testHalationMatchesTheReference() throws {
        try requireTetrahedralReader()
        try assertMatches(developed { $0.halation = self.scene.halation }, "frame-halation.png")
    }

    /// Soft, darkened edges: the reference's blur toward the corners and its vignette.
    func testSoftDarkenedEdgesMatchTheReference() throws {
        try requireTetrahedralReader()
        try assertMatches(developed { $0.softEdges = self.scene.softEdges; $0.vignette = self.scene.vignette }, "frame-soft-edges.png")
    }

    /// Halation, soft darkened edges and overall softness together, in the reference's order, then the film.
    func testEveryPassBeforeTheGrainMatchesTheReference() throws {
        try requireTetrahedralReader()
        try assertMatches(developed {
            $0.halation = self.scene.halation; $0.softEdges = self.scene.softEdges; $0.vignette = self.scene.vignette
            $0.softness = self.scene.softness
        }, "frame-passes.png")
    }

    /// A portrait clip is the same film turned on its side: its glow, blur and grain are the size a landscape clip's
    /// are, because lengths follow the frame's long edge. The reference only ever develops a landscape frame, so the
    /// fixture frame is turned a quarter turn, developed, turned back and held to the same reference frame; and an
    /// even gray frame gets grain of the same strength either way up. Lengths taken from the frame's width would
    /// give the portrait frame three quarters of the blur and of the grain.
    func testAPortraitFrameDevelopsAsTheSameFilmTurnedOnItsSide() throws {
        try requireTetrahedralReader()
        func atOrigin(_ image: CIImage) -> CIImage {
            image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
        }
        var treatment = look
        treatment.scene = FilmLook.ScenePasses(referenceWidth: scene.referenceWidth, halation: scene.halation, softEdges: scene.softEdges,
                                               vignette: scene.vignette, softness: scene.softness)
        let turned = atOrigin(try Fixtures.picture("Cinema16mmColor/frame.png").oriented(.right))
        XCTAssertEqual(turned.extent.size, CGSize(width: 240, height: 320))
        let developed = try DevelopedTreatment(treatment, seed: 9).apply(to: turned)
        try assertMatches(Fixtures.tones(atOrigin(developed.oriented(.left))), "frame-passes.png")

        treatment.scene = FilmLook.ScenePasses(referenceWidth: scene.referenceWidth, grain: scene.grain)
        func spread(width: Int, height: Int) throws -> Double {
            let tones = try Fixtures.tones(DevelopedTreatment(treatment, seed: 5).apply(to: Fixtures.even(tone: 0.46, width: width, height: height)))
            let values = tones.channel(1)
            let mean = values.reduce(0, +) / Double(values.count)
            return (values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count)).squareRoot()
        }
        let landscape = try spread(width: 1440, height: 1080), portrait = try spread(width: 1080, height: 1440)
        XCTAssertGreaterThan(landscape, 0.004, "The grain is visible")
        XCTAssertEqual(portrait, landscape, accuracy: landscape * 0.05, "The same grain whichever way the Camera was held")
    }

    /// The reference's own checks of these passes: halation leaves a frame with no strong highlight alone, a glow is
    /// red, then green, then blue, and never negative, and the vignette takes its full amount at the corner and
    /// nothing at the center.
    func testHalationAndVignetteBehaveAsTheReferenceChecksThem() throws {
        try requireTetrahedralReader()
        let extent = CGRect(x: 0, y: 0, width: 320, height: 240)
        func raw(_ image: CIImage) -> Fixtures.Tones { Fixtures.values(image.cropped(to: extent)) }
        let flat = Fixtures.light(0.18, in: extent)
        let untouched = raw(DevelopedTreatment.glow(flat, scene.halation!, width: 320))
        XCTAssertEqual(untouched.pixel(x: 40, y: 40)[0], 0.18, accuracy: 0.0005)
        let spot = Fixtures.light(8, in: CGRect(x: 158, y: 118, width: 4, height: 4)).composited(over: flat)
        let glow = raw(DevelopedTreatment.glow(spot, scene.halation!, width: 320)).pixel(x: 175, y: 120).map { $0 - 0.18 }
        XCTAssertGreaterThan(glow[0], glow[1])
        XCTAssertGreaterThan(glow[1], glow[2])
        XCTAssertGreaterThanOrEqual(glow[2], -0.0005)
        let vignette = scene.vignette!
        let fall = raw(DevelopedTreatment.radialStep(extent, from: vignette.start, to: vignette.end))
        XCTAssertEqual(fall.pixel(x: 0, y: 0)[0], 1, accuracy: 0.02, "The whole amount at the corner")
        XCTAssertEqual(fall.pixel(x: 160, y: 120)[0], 0, accuracy: 0.0005, "Nothing at the center")
        var treatment = look
        treatment.scene = FilmLook.ScenePasses(referenceWidth: scene.referenceWidth, vignette: vignette)
        let white = try Fixtures.tones(DevelopedTreatment(treatment, seed: 1).apply(to: Fixtures.even(tone: 0.5, width: 320, height: 240)))
        XCTAssertLessThan(white.pixel(x: 1, y: 1)[1], white.pixel(x: 160, y: 120)[1] - 0.03, "Darker corners")
    }

    // MARK: - Weave

    /// The clip's slow sway is the reference's: two sines on each axis with the clip's phases, at its amplitudes.
    func testTheSwayIsTheReferences() {
        let weave = scene.weave!, fixture = Self.passes.weave
        for (time, expected) in zip(fixture.times, fixture.offsetsAtReferenceWidth) {
            let sway = FilmLook.ScenePasses.Weave.sway(weave, time: time, width: scene.referenceWidth,
                                                       phases: (fixture.phases[0], fixture.phases[1]))
            XCTAssertEqual(sway.dx, expected[0], accuracy: 1e-9, "\(time) s across")
            XCTAssertEqual(sway.dy, expected[1], accuracy: 1e-9, "\(time) s down")
        }
        // It never exceeds its amplitude, whatever the phases.
        for step in 0..<400 {
            let sway = FilmLook.ScenePasses.Weave.sway(weave, time: Double(step) / 24, width: 1920, phases: ([0.3, 5.1], [2.2, 4.0]))
            XCTAssertLessThanOrEqual(abs(sway.dx), weave.across * 1920 + 1e-9)
            XCTAssertLessThanOrEqual(abs(sway.dy), weave.down * 1920 + 1e-9)
        }
    }

    /// One frame's weave, with the move and turn the reference drew, resamples the frame as the reference does: drawn
    /// from a picture enlarged by its over-scale, with no empty edge.
    func testAWovenFrameMatchesTheReference() throws {
        let frame = Self.passes.weave.frame
        // The weave works on display tones, so the fixture is handed over as tones and taken back as light.
        let tones = try Fixtures.picture("Cinema16mmColor/frame-passes.png").applyingFilter("CILinearToSRGBToneCurve")
        let woven = DevelopedTreatment.woven(tones, dx: frame.dx, dy: frame.dy, degrees: frame.degrees, overscale: scene.weave!.overscale)
            .applyingFilter("CISRGBToneCurveToLinear")
        let result = try difference(Fixtures.tones(woven), from: "frame-weave.png")
        XCTAssertLessThan(result.mean, 0.002, "mean \(result.mean)")
        XCTAssertLessThan(result.most, 0.02, "99 percent within \(result.most)")
        // A move it can be seen to make: 3 pixels right and 2 down moves a mark that far.
        var bytes = [UInt8](repeating: 255, count: 64 * 48 * 4)
        for index in stride(from: 0, to: bytes.count, by: 4) { bytes[index] = 0; bytes[index + 1] = 0; bytes[index + 2] = 0 }
        for channel in 0..<3 { bytes[(20 * 64 + 30) * 4 + channel] = 255 }   // 30 across, 20 down from the top
        let mark = CIImage(bitmapData: Data(bytes), bytesPerRow: 64 * 4, size: CGSize(width: 64, height: 48), format: .RGBA8,
                           colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
        let moved = try Fixtures.tones(DevelopedTreatment.woven(mark, dx: 3, dy: 2, degrees: 0, overscale: 1))
        XCTAssertGreaterThan(moved.pixel(x: 33, y: 22)[0], 0.9)
        XCTAssertLessThan(moved.pixel(x: 30, y: 20)[0], 0.1)
    }

    /// The frame is unsteady from frame to frame, by no more than the reference's weave and over-scale move it, and
    /// its brightness does not flicker: the 16mm has no flicker, dust or hair.
    func testAClipWeavesSlightlyAndNeverFlickers() throws {
        try requireTetrahedralReader()
        let picture = try Fixtures.picture("Cinema16mmColor/frame.png")
        let weaving = DevelopedTreatment(look.with { $0.scene = FilmLook.ScenePasses(referenceWidth: 1440, weave: self.scene.weave) }, seed: 21)
        let still = try Fixtures.tones(DevelopedTreatment(look.with { $0.scene = FilmLook.ScenePasses(referenceWidth: 1440) }, seed: 21)
            .apply(to: picture))
        var moved = false
        for frame in 0..<8 {
            let tones = try Fixtures.tones(weaving.apply(to: picture, frame: frame, frameRate: 24))
            // The patches and the sky stay where they were to within the over-scale's pixel or two.
            XCTAssertLessThan(tones.meanDifference(from: still), 0.02, "frame \(frame)")
            if tones.meanDifference(from: still) > 0.0005 { moved = true }
        }
        XCTAssertTrue(moved, "The frame is drawn from an enlarged, moving picture")
        // An even gray scene through every pass: the grain is new on each frame and the frame weaves, but the frame's
        // brightness stays where it was.
        let gray = Fixtures.even(tone: 0.5, width: 320, height: 240)
        let development = DevelopedTreatment(look, seed: 21)
        let means = try (0..<8).map { try Fixtures.tones(development.apply(to: gray, frame: $0, frameRate: 24)).mean() }
        XCTAssertLessThan(means.max()! - means.min()!, 0.001, "No brightness flicker: \(means)")
    }

    // MARK: - Grain

    /// The grain field has the reference's make-up, measured as the reference's own field measures at the width a
    /// landscape Movie develops at: each layer shares most of its grain with the others, and neighboring pixels are
    /// alike by the same amounts across and down, from its two octaves.
    func testTheGrainFieldMeasuresAsTheReferencesDoes() {
        let grain = scene.grain!, fixture = Self.passes.grain
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
        for layer in [red, green, blue] {
            let mean = layer.reduce(0, +) / Double(layer.count)
            XCTAssertEqual((layer.reduce(0) { $0 + pow($1 - mean, 2) } / Double(layer.count)).squareRoot(), 1, accuracy: 0.001)
        }
        XCTAssertEqual(correlation(red, green), fixture.redGreen, accuracy: 0.01)
        XCTAssertEqual(correlation(red, blue), fixture.redBlue, accuracy: 0.01)
        XCTAssertEqual(correlation(green, blue), fixture.greenBlue, accuracy: 0.01)
        for (index, lag) in fixture.lags.enumerated() {
            XCTAssertEqual(correlation(green, shifted(green, across: lag, down: 0)), fixture.greenAcrossLags[index], accuracy: 0.02, "green, \(lag) across")
            XCTAssertEqual(correlation(green, shifted(green, across: 0, down: lag)), fixture.greenDownLags[index], accuracy: 0.02, "green, \(lag) down")
            XCTAssertEqual(correlation(red, shifted(red, across: lag, down: 0)), fixture.redAcrossLags[index], accuracy: 0.02, "red, \(lag) across")
        }
    }

    /// Added to a frame's Apple Log tones, the grain has the reference's strength in each layer at that width (its
    /// per-pixel deviation, its strength of 1.5, scaled with the frame's width), within the 5 percent the reference's
    /// own check allows; it leaves the tone where it was; and every frame has a new pattern.
    func testTheGrainHasTheReferencesStrengthAndIsNewOnEveryFrame() {
        let grain = scene.grain!, fixture = Self.passes.grain
        let extent = CGRect(x: 0, y: 0, width: fixture.width, height: 256)
        let development = DevelopedTreatment(look, seed: 77)
        func field(_ frame: Int) -> Fixtures.Tones {
            Fixtures.values(development.grained(Fixtures.light(0.5, in: extent), grain, width: Double(fixture.width),
                                                referenceWidth: scene.referenceWidth, frame: frame))
        }
        let first = field(0), second = field(1)
        for channel in 0..<3 {
            let values = first.channel(channel)
            let mean = values.reduce(0, +) / Double(values.count)
            let deviation = (values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count)).squareRoot()
            XCTAssertEqual(mean, 0.5, accuracy: 0.0002, "The grain adds no tone of its own")
            XCTAssertEqual(deviation, fixture.expectedDeviation[channel], accuracy: fixture.expectedDeviation[channel] * 0.05, "layer \(channel)")
            XCTAssertEqual(fixture.deviation[channel], fixture.expectedDeviation[channel], accuracy: fixture.expectedDeviation[channel] * 0.05)
        }
        XCTAssertGreaterThan(first.meanDifference(from: second), 0.002, "A new pattern on the next frame")
    }

    // MARK: - The whole frame

    /// The whole frame, with its grain and weave, beside the reference's own developed frame. Their grain and weave
    /// were drawn differently, so they are compared part by part: in 16 x 12 blocks of 20 pixels, every block with no
    /// edge in it (the weave moves edges by a pixel or so) has the same mean tone to 0.012, and over the even gray
    /// field the grain is as strong within a fifth.
    func testTheWholeDevelopedFrameComparesWithTheReferences() throws {
        try requireTetrahedralReader()
        let tones = try Fixtures.tones(DevelopedTreatment(look, seed: 3).apply(to: Fixtures.picture("Cinema16mmColor/frame.png"),
                                                                                frame: 10, frameRate: 24))
        let expected = try Fixtures.bytes("Cinema16mmColor/frame-developed.png")
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
            // Grain alone spreads a block's tones by less than this; an edge spreads them by more.
            guard range < 0.12 else { continue }
            even += 1
            XCTAssertLessThan(worst, 0.012, "block \(column), \(row)")
        } }
        XCTAssertGreaterThan(even, 90, "Most of the frame is compared")
        // The even middle gray field of the test frame: 80 pixels square from (16, 130).
        func spread(_ value: (Int) -> Double) -> Double {
            var values: [Double] = []
            for y in 140..<200 { for x in 26..<86 { values.append(value((y * tones.width + x) * 4 + 1)) } }
            let mean = values.reduce(0, +) / Double(values.count)
            return (values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count)).squareRoot()
        }
        let got = spread { Double(tones.values[$0]) }, want = spread { Double(expected[$0]) / 255 }
        XCTAssertEqual(got, want, accuracy: want * 0.2, "grain over the even field: \(got) against the reference's \(want)")
        XCTAssertGreaterThan(want, 0.004, "The reference's grain is visible")
    }
}

private extension FilmLook.Treatment {
    func with(_ change: (inout FilmLook.Treatment) -> Void) -> FilmLook.Treatment {
        var copy = self
        change(&copy)
        return copy
    }
}

extension Fixtures.Tones {
    func channel(_ channel: Int) -> [Double] { stride(from: channel, to: values.count, by: 4).map { Double(values[$0]) } }

    func mean() -> Double {
        var total = 0.0
        for index in stride(from: 0, to: values.count, by: 4) { total += Double(values[index] + values[index + 1] + values[index + 2]) }
        return total / Double(values.count / 4 * 3)
    }

    func meanDifference(from other: Fixtures.Tones) -> Double {
        var total = 0.0
        for index in stride(from: 0, to: values.count, by: 4) {
            for channel in 0..<3 { total += Double(abs(values[index + channel] - other.values[index + channel])) }
        }
        return total / Double(values.count / 4 * 3)
    }
}

extension Fixtures {
    /// An image's values as Core Image holds them, unconverted: scene light or Apple Log tones. Rows from the top.
    /// Core Image works in 16-bit numbers unless a test asks for 32.
    static func values(_ image: CIImage, workingFormat: CIFormat? = nil) -> Tones {
        let width = Int(image.extent.width), height = Int(image.extent.height)
        var values = [Float](repeating: 0, count: width * height * 4)
        var options: [CIContextOption: Any] = [.cacheIntermediates: false]
        if let workingFormat { options[.workingFormat] = workingFormat.rawValue }
        CIContext(options: options).render(
            image, toBitmap: &values, rowBytes: width * 16, bounds: image.extent, format: .RGBAf, colorSpace: nil)
        return Tones(width: width, height: height, values: values)
    }

    /// An even field of one value, as Core Image holds it.
    static func light(_ value: Double, in extent: CGRect) -> CIImage {
        let width = Int(extent.width), height = Int(extent.height)
        var values = [Float](repeating: Float(value), count: width * height * 4)
        for index in stride(from: 3, to: values.count, by: 4) { values[index] = 1 }
        return CIImage(bitmapData: values.withUnsafeBufferPointer { Data(buffer: $0) }, bytesPerRow: width * 16,
                       size: CGSize(width: width, height: height), format: .RGBAf, colorSpace: nil)
            .transformed(by: CGAffineTransform(translationX: extent.minX, y: extent.minY))
    }

    /// A fixture picture's display tones as 8-bit red, green, blue and alpha, rows from the top.
    static func bytes(_ path: String) throws -> [UInt8] {
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url(path) as CFURL, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                                                  bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return bytes
    }
}
