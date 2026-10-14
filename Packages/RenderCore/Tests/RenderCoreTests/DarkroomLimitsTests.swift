import CoreGraphics
import CoreImage
import FilmDomain
import Foundation
import ImageIO
import RenderCore
import UniformTypeIdentifiers
import XCTest

/// The Darkroom's limits are the captain's of 2026-10-13 (DEC-11): print exposure and Dodge/Burn each run to 3 stops
/// either way, filtration to 30 and contrast grades from 0 to 5. These tests hold the limits themselves, a defined
/// picture at every end, the same print for a recipe saved under the earlier limits (2 stops and 1 stop), and a
/// refusal, not a clamp, for a stored value outside them.
final class DarkroomLimitsTests: XCTestCase {
    private let disposable = CameraCatalog.disposable1990s

    func testTheLimitsAreTheCaptains() throws {
        XCTAssertEqual(DarkroomLimits.printExposureStops, -3.0...3.0)
        XCTAssertEqual(DarkroomLimits.exposureStep, 0.1)
        XCTAssertEqual(DarkroomLimits.contrastGrades, 0...5)
        XCTAssertEqual(DarkroomLimits.colorFiltration, -30.0...30.0)
        XCTAssertEqual(DarkroomLimits.localExposureStops, 3)
        for camera in CameraCatalog.all.filter({ $0.medium == .photo }) {
            for recipe in atTheLimits() {
                XCTAssertNoThrow(try NativePhotoRenderer.validate(recipe, camera: camera), "\(camera.id) \(recipe)")
            }
            for recipe in justOutsideTheLimits() {
                XCTAssertThrowsError(try NativePhotoRenderer.validate(recipe, camera: camera), "\(camera.id) \(recipe)") {
                    XCTAssertEqual($0 as? NativeRenderError, .invalidRecipe)
                }
            }
        }
    }

    /// Print exposure is the print's light multiplied by two for each stop, clipped honestly at white: every patch of
    /// the chart prints where that arithmetic puts it at both ends, on gray and on color.
    func testPrintExposureAtBothEndsPrintsEveryToneWhereTheStopsPutIt() throws {
        let chart = try Chart()
        for stops in [DarkroomLimits.printExposureStops.lowerBound, DarkroomLimits.printExposureStops.upperBound] {
            let printed = try DecodedPixels(NativePhotoRenderer.print(
                master: chart.master, recipe: DarkroomRecipe(printExposureStops: stops), camera: disposable))
            XCTAssertEqual([printed.width, printed.height], [Chart.width, Chart.height])
            for patch in 0..<Chart.patches {
                let expected = chart.patch(patch).map { Chart.exposed($0, stops: stops) }
                assertEqual(printed.mean(around: Chart.center(of: patch)), expected, accuracy: 3, "\(stops) stops, patch \(patch)")
            }
        }
    }

    /// Every other control at each end, alone and all together with exposure and Dodge/Burn at theirs, prints a whole
    /// picture of the right size whose flat patches stay flat: an invalid value would print as a hole or a ring.
    func testEveryControlAtEachEndPrintsADefinedPicture() throws {
        let chart = try Chart()
        let corner = [MaskPoint(x: 0, y: 0), MaskPoint(x: 1, y: 1)]
        var recipes: [(String, DarkroomRecipe, PhotoPrintProcess)] = []
        for grade in [DarkroomLimits.contrastGrades.lowerBound, DarkroomLimits.contrastGrades.upperBound] {
            recipes.append(("grade \(grade)", DarkroomRecipe(contrastGrade: grade), .color))
        }
        for amount in [DarkroomLimits.colorFiltration.lowerBound, DarkroomLimits.colorFiltration.upperBound] {
            recipes.append(("cyan \(amount)", DarkroomRecipe(colorFiltration: ColorFiltration(cyan: amount)), .color))
            recipes.append(("magenta \(amount)", DarkroomRecipe(colorFiltration: ColorFiltration(magenta: amount)), .color))
            recipes.append(("yellow \(amount)", DarkroomRecipe(colorFiltration: ColorFiltration(yellow: amount)), .color))
            for stops in [DarkroomLimits.printExposureStops.lowerBound, DarkroomLimits.printExposureStops.upperBound] {
                for grade in [DarkroomLimits.contrastGrades.lowerBound, DarkroomLimits.contrastGrades.upperBound] {
                    for kind in [LocalMask.Kind.dodge, .burn] {
                        recipes.append(("everything: \(stops) stops, grade \(grade), filtration \(amount), \(kind)", DarkroomRecipe(
                            printExposureStops: stops, contrastGrade: grade,
                            colorFiltration: ColorFiltration(cyan: amount, magenta: amount, yellow: amount),
                            dodgeBurnMasks: [LocalMask(kind: kind, points: corner, exposureStops: DarkroomLimits.localExposureStops)]), .color))
                    }
                }
            }
        }
        for chemistry in ChemicalToning.Chemistry.allCases {
            for amount in [0.0, 1.0] {
                for stops in [DarkroomLimits.printExposureStops.lowerBound, DarkroomLimits.printExposureStops.upperBound] {
                    recipes.append(("\(chemistry) \(amount) at \(stops) stops", DarkroomRecipe(
                        printExposureStops: stops, contrastGrade: 5,
                        dodgeBurnMasks: [LocalMask(kind: .dodge, points: corner, exposureStops: DarkroomLimits.localExposureStops)],
                        chemicalToning: ChemicalToning(chemistry: chemistry, amount: amount)), .silverGelatin))
                }
            }
        }
        for (name, recipe, process) in recipes {
            let camera = process == .silverGelatin ? CameraCatalog.mediumFormat6x6 : disposable
            let printed = try DecodedPixels(NativePhotoRenderer.print(master: chart.master, recipe: recipe, camera: camera, process: process))
            XCTAssertEqual([printed.width, printed.height], [Chart.width, Chart.height], name)
            // The corner strokes reach 72 pixels in, so the middle of every patch is clear of them.
            for patch in 0..<Chart.patches {
                XCTAssertLessThanOrEqual(printed.spread(around: Chart.center(of: patch)), 3, "\(name), patch \(patch) is flat")
            }
            // Gray patches keep their order from dark to light.
            let grays = (0..<Chart.grays.count).map { printed.mean(around: Chart.center(of: $0)).reduce(0, +) }
            for (darker, lighter) in zip(grays, grays.dropFirst()) {
                XCTAssertLessThanOrEqual(darker, lighter + 3, "\(name): grays stay in order \(grays)")
            }
        }
        // A crop at its smallest and at each corner, with everything else at an end.
        for crop in [Crop(x: 0, y: 0, width: 0.2, height: 0.2), Crop(x: 0.8, y: 0.8, width: 0.2, height: 0.2),
                     Crop(x: 0, y: 0, width: 1, height: 1)] {
            let recipe = DarkroomRecipe(printExposureStops: 3, contrastGrade: 5,
                                        colorFiltration: ColorFiltration(cyan: -30, magenta: 30, yellow: -30), crop: crop,
                                        dodgeBurnMasks: [LocalMask(kind: .burn, points: corner, exposureStops: 3)])
            let printed = try DecodedPixels(NativePhotoRenderer.print(master: chart.master, recipe: recipe, camera: disposable))
            XCTAssertEqual(printed.width, Int((crop.width * Double(Chart.width)).rounded()), "\(crop)")
            XCTAssertEqual(printed.height, Int((crop.height * Double(Chart.height)).rounded()), "\(crop)")
        }
    }

    /// Exposure and Dodge/Burn at their ends together: 6 stops from the developed print where they agree and none
    /// where they oppose, with the rest of the print at the print exposure and a smooth edge between.
    func testPrintExposureAndDodgeBurnAtTheirEndsTogether() throws {
        let chart = try Chart()
        let limit = DarkroomLimits.localExposureStops
        for stops in [-limit, limit] {
            for kind in [LocalMask.Kind.dodge, .burn] {
                let local = kind == .dodge ? limit : -limit
                let recipe = DarkroomRecipe(printExposureStops: stops, dodgeBurnMasks: [
                    LocalMask(kind: kind, points: (0..<Chart.patches).map(Chart.point(of:)), exposureStops: limit)])
                let printed = try DecodedPixels(NativePhotoRenderer.print(master: chart.master, recipe: recipe, camera: disposable))
                for patch in 0..<Chart.patches {
                    let name = "\(stops) stops with \(kind) \(limit), patch \(patch)"
                    let center = Chart.center(of: patch)
                    let stroke = chart.patch(patch).map { Chart.exposed($0, stops: stops + local) }
                    let around = chart.patch(patch).map { Chart.exposed($0, stops: stops) }
                    assertEqual(printed.mean(around: center, radius: 3), stroke, accuracy: 4, "\(name): under the stroke")
                    // Past the stroke's 72 pixel reach the patch is at the print exposure alone.
                    assertEqual(printed.mean(around: (center.x + 76, center.y + 76), radius: 2), around, accuracy: 4, "\(name): beside it")
                    // From the stroke's middle outward each channel only ever moves toward the print exposure. JPEG blocks
                    // ripple a steep edge by a few levels, so the profile is read as a running mean of five pixels.
                    let profile = (-2...78).map { printed.channels(x: center.x + $0, y: center.y) }
                    for channel in 0..<3 {
                        let values = (0...76).map { start in profile[start..<start + 5].reduce(0) { $0 + Int($1[channel]) } / 5 }
                        let rising = stroke[channel] <= around[channel]
                        for (inner, outer) in zip(values, values.dropFirst()) {
                            XCTAssertLessThanOrEqual(rising ? inner : outer, (rising ? outer : inner) + 3,
                                                     "\(name): channel \(channel) is smooth outward \(values)")
                        }
                    }
                }
            }
        }
    }

    /// Strokes add up where they overlap, but never past the limit: sixty strokes at 3 stops print the stroke's middle
    /// where one does, and eight dodges followed by eight burns stay within 3 stops of the print everywhere. Unbounded,
    /// those ran past what the renderer can hold and printed a ring with a dark middle.
    func testOverlappingStrokesNeverPassTheLimit() throws {
        let chart = try Chart()
        let limit = DarkroomLimits.localExposureStops
        let points = (0..<Chart.patches).map(Chart.point(of:))
        for kind in [LocalMask.Kind.dodge, .burn] {
            let stroke = LocalMask(kind: kind, points: points, exposureStops: limit)
            let one = try DecodedPixels(NativePhotoRenderer.print(master: chart.master,
                recipe: DarkroomRecipe(dodgeBurnMasks: [stroke]), camera: disposable))
            let sixty = try DecodedPixels(NativePhotoRenderer.print(master: chart.master,
                recipe: DarkroomRecipe(dodgeBurnMasks: Array(repeating: stroke, count: 60)), camera: disposable))
            for patch in 0..<Chart.patches {
                let center = Chart.center(of: patch)
                assertEqual(sixty.mean(around: center, radius: 3), one.mean(around: center, radius: 3), accuracy: 2,
                            "sixty \(kind) strokes, patch \(patch)")
            }
        }
        let dodge = LocalMask(kind: .dodge, points: points, exposureStops: limit)
        let burn = LocalMask(kind: .burn, points: points, exposureStops: limit)
        for masks in [Array(repeating: dodge, count: 8) + Array(repeating: burn, count: 8),
                      Array(repeating: burn, count: 8) + Array(repeating: dodge, count: 8)] {
            let printed = try DecodedPixels(NativePhotoRenderer.print(master: chart.master,
                recipe: DarkroomRecipe(dodgeBurnMasks: masks), camera: disposable))
            for patch in 0..<Chart.patches {
                let center = Chart.center(of: patch)
                let lightest = chart.patch(patch).map { Chart.exposed($0, stops: limit) }
                let darkest = chart.patch(patch).map { Chart.exposed($0, stops: -limit) }
                for offset in 0...76 {
                    let pixel = printed.channels(x: center.x + offset, y: center.y)
                    for channel in 0..<3 {
                        // JPEG moves a single pixel of a saturated color by a few levels.
                        XCTAssertLessThanOrEqual(Double(pixel[channel]), lightest[channel] + 8, "patch \(patch) at \(offset)")
                        XCTAssertGreaterThanOrEqual(Double(pixel[channel]), darkest[channel] - 8, "patch \(patch) at \(offset)")
                    }
                }
            }
        }
    }

    /// A recipe saved under the earlier limits (exposure to 2 stops, a stroke to 1) prints the bytes the build before
    /// the wider limits printed. `EarlierDarkroom` is that build's printing, kept here unchanged.
    func testARecipeSavedUnderTheEarlierLimitsPrintsTheSameBytes() throws {
        let chart = try Chart()
        let strokes = [
            LocalMask(kind: .dodge, points: [MaskPoint(x: 0.3, y: 0.3), MaskPoint(x: 0.32, y: 0.33)], exposureStops: 0.4),
            LocalMask(kind: .burn, points: [MaskPoint(x: 0.7, y: 0.6)], exposureStops: 0.4),
            LocalMask(kind: .dodge, points: [MaskPoint(x: 0.3, y: 0.3)], exposureStops: 1),
            LocalMask(kind: .burn, points: [MaskPoint(x: 0.05, y: 0.95)], exposureStops: 1),
            LocalMask(kind: .burn, points: [MaskPoint(x: 0.05, y: 0.95)], exposureStops: 1)
        ]
        var color: [DarkroomRecipe] = [
            DarkroomRecipe(printExposureStops: 2), DarkroomRecipe(printExposureStops: -2),
            DarkroomRecipe(printExposureStops: 0.7, contrastGrade: 3, colorFiltration: ColorFiltration(cyan: 8, magenta: -3, yellow: 5)),
            DarkroomRecipe(dodgeBurnMasks: strokes),
            // Seven strokes of the strength the Darkroom gave every stroke, on one spot.
            DarkroomRecipe(dodgeBurnMasks: Array(repeating: LocalMask(kind: .dodge, points: [MaskPoint(x: 0.5, y: 0.5)], exposureStops: 0.4), count: 7)),
            DarkroomRecipe(dodgeBurnMasks: Array(repeating: LocalMask(kind: .burn, points: [MaskPoint(x: 0.5, y: 0.5)], exposureStops: 0.4), count: 7))
        ]
        for stops in [-2.0, 2.0] { for grade in [0, 5] { for amount in [-30.0, 30.0] {
            color.append(DarkroomRecipe(printExposureStops: stops, contrastGrade: grade,
                                        colorFiltration: ColorFiltration(cyan: amount, magenta: -amount, yellow: amount),
                                        dodgeBurnMasks: strokes))
        } } }
        for recipe in color {
            XCTAssertEqual(try NativePhotoRenderer.print(master: chart.master, recipe: recipe, camera: disposable),
                           try EarlierDarkroom.print(master: chart.master, recipe: recipe), "\(recipe)")
            var cropped = recipe
            cropped.crop = Crop(x: 0.1, y: 0.2, width: 0.6, height: 0.5)
            XCTAssertEqual(try NativePhotoRenderer.print(master: chart.master, recipe: cropped, camera: disposable),
                           try EarlierDarkroom.print(master: chart.master, recipe: cropped), "\(cropped)")
        }
        for chemistry in ChemicalToning.Chemistry.allCases {
            let recipe = DarkroomRecipe(printExposureStops: -2, contrastGrade: 5, dodgeBurnMasks: strokes,
                                        chemicalToning: ChemicalToning(chemistry: chemistry, amount: 0.5))
            XCTAssertEqual(try NativePhotoRenderer.print(master: chart.master, recipe: recipe, camera: CameraCatalog.mediumFormat6x6,
                                                         process: .silverGelatin),
                           try EarlierDarkroom.print(master: chart.master, recipe: recipe), "\(recipe)")
        }
        // An Instant print: the picture alone is printed and put back on its card.
        let card = try Chart.instantCard()
        for recipe in [DarkroomRecipe(printExposureStops: -2, contrastGrade: 5, dodgeBurnMasks: strokes),
                       DarkroomRecipe(printExposureStops: 2, colorFiltration: ColorFiltration(cyan: 30, magenta: -30, yellow: 30))] {
            XCTAssertEqual(try NativePhotoRenderer.print(master: card, recipe: recipe, camera: CameraCatalog.instant1970s),
                           try EarlierDarkroom.print(master: card, recipe: recipe, instant: true), "\(recipe)")
        }
        // The stored form the earlier build wrote still reads as the same recipe.
        let stored = Data(#"{"printExposureStops":-2,"contrastGrade":5,"dodgeBurnMasks":[{"kind":"burn","points":[{"x":0.5,"y":0.25}],"exposureStops":0.4}]}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(DarkroomRecipe.self, from: stored), DarkroomRecipe(printExposureStops: -2, contrastGrade: 5,
            dodgeBurnMasks: [LocalMask(kind: .burn, points: [MaskPoint(x: 0.5, y: 0.25)], exposureStops: 0.4)]))
    }

    /// A cropped 6×6 print is square in whole pixels wherever the crop sits. Each side of a crop is rounded out to whole
    /// pixels on its own, which printed a crop lying between pixels a pixel longer one way than the other: the first two
    /// crops are ones the Darkroom stored, saved to Photos at 619 × 618 and 629 × 628. A crop the build before printed
    /// square prints the same bytes, and one it printed off square prints the same picture without its last column or row.
    func testACropped6x6PrintIsSquareWhereverTheCropSits() throws {
        let master = try Chart.mediumFormatPrint()
        let crops = [
            Crop(x: 0.4192503206734682, y: 0.417404553250964, width: 0.20087639717385175, height: 0.20087639717385175),
            Crop(x: 0.424675768215624, y: 0, width: 0.20434599928557873, height: 0.20434599928557873),
            // A row too many where those two had a column: 618 × 619.
            Crop(x: 0.3, y: 0.61, width: 0.2009, height: 0.2009),
            // On whole pixels, and in the corner the sliders end in, where the crop's far edges meet the print's.
            Crop(x: 0.25, y: 0.25, width: 0.25, height: 0.25),
            Crop(x: 1 - 0.2009, y: 1 - 0.2009, width: 0.2009, height: 0.2009),
            Crop(x: 1 - 0.3337, y: 1 - 0.3337, width: 0.3337, height: 0.3337)
        ]
        var offSquare = 0
        for crop in crops {
            let recipe = DarkroomRecipe(crop: crop)
            let printed = try NativePhotoRenderer.print(master: master, recipe: recipe, camera: CameraCatalog.mediumFormat6x6)
            let earlier = try EarlierDarkroom.print(master: master, recipe: recipe)
            let today = try DecodedPixels(printed), before = try DecodedPixels(earlier)
            XCTAssertEqual([today.width, today.height], Array(repeating: min(before.width, before.height), count: 2), "\(crop)")
            if before.width == before.height {
                XCTAssertEqual(printed, earlier, "\(crop) printed square before and prints the same bytes")
                continue
            }
            offSquare += 1
            guard today.width <= before.width, today.height <= before.height else { continue }
            // The same pixels from the top left corner, clear of the JPEG blocks the missing column or row reaches. Two
            // encodings of one picture differ by a few levels where patches meet (5 in the simulator); a picture moved
            // by a pixel differs there by the whole step between two patches.
            var furthest = 0
            for y in 0..<today.height - 16 {
                let new = today.bytes[y * today.width * 4..<(y * today.width + today.width - 16) * 4]
                let old = before.bytes[y * before.width * 4..<(y * before.width + today.width - 16) * 4]
                furthest = max(furthest, zip(new, old).map { abs(Int($0) - Int($1)) }.max() ?? 0)
            }
            XCTAssertLessThanOrEqual(furthest, 16, "\(crop) prints the picture it printed before")
        }
        XCTAssertEqual(offSquare, 3, "The first three printed a pixel off square before")
    }

    /// A stored value outside the limits, which only a build with wider limits or a damaged store can leave, is refused:
    /// the print is never quietly made at the nearest limit, and the developed master it would print is untouched.
    func testAValueOutsideTheLimitsIsRefusedAndNeverPrintedAtTheNearestLimit() throws {
        let chart = try Chart()
        for recipe in justOutsideTheLimits() {
            let stored = try JSONDecoder().decode(DarkroomRecipe.self, from: JSONEncoder().encode(recipe))
            XCTAssertEqual(stored, recipe, "A value outside the limits is read as it was stored")
            XCTAssertThrowsError(try NativePhotoRenderer.print(master: chart.master, recipe: stored, camera: disposable), "\(recipe)") {
                XCTAssertEqual($0 as? NativeRenderError, .invalidRecipe)
            }
        }
        XCTAssertEqual(try NativePhotoRenderer.print(master: chart.master, recipe: .original, camera: disposable), chart.master)
    }

    private func atTheLimits() -> [DarkroomRecipe] {
        let points = [MaskPoint(x: 0, y: 0), MaskPoint(x: 1, y: 1)]
        return [
            DarkroomRecipe(printExposureStops: 3), DarkroomRecipe(printExposureStops: -3),
            DarkroomRecipe(contrastGrade: 0), DarkroomRecipe(contrastGrade: 5),
            DarkroomRecipe(colorFiltration: ColorFiltration(cyan: 30, magenta: 30, yellow: 30)),
            DarkroomRecipe(colorFiltration: ColorFiltration(cyan: -30, magenta: -30, yellow: -30)),
            DarkroomRecipe(dodgeBurnMasks: [LocalMask(kind: .dodge, points: points, exposureStops: 3)]),
            DarkroomRecipe(dodgeBurnMasks: [LocalMask(kind: .burn, points: points, exposureStops: 3)]),
            DarkroomRecipe(printExposureStops: 3, contrastGrade: 5, colorFiltration: ColorFiltration(cyan: 30, magenta: -30, yellow: 30),
                           dodgeBurnMasks: [LocalMask(kind: .dodge, points: points, exposureStops: 3),
                                            LocalMask(kind: .burn, points: points, exposureStops: 3)])
        ]
    }

    private func justOutsideTheLimits() -> [DarkroomRecipe] {
        let point = [MaskPoint(x: 0.5, y: 0.5)]
        return [
            DarkroomRecipe(printExposureStops: 3.1), DarkroomRecipe(printExposureStops: -3.1),
            DarkroomRecipe(printExposureStops: 3.0000001), DarkroomRecipe(printExposureStops: 4),
            DarkroomRecipe(contrastGrade: -1), DarkroomRecipe(contrastGrade: 6),
            DarkroomRecipe(colorFiltration: ColorFiltration(cyan: 31)), DarkroomRecipe(colorFiltration: ColorFiltration(magenta: -31)),
            DarkroomRecipe(colorFiltration: ColorFiltration(yellow: 30.5)),
            DarkroomRecipe(dodgeBurnMasks: [LocalMask(kind: .dodge, points: point, exposureStops: 3.1)]),
            DarkroomRecipe(dodgeBurnMasks: [LocalMask(kind: .burn, points: point, exposureStops: 3.1)]),
            DarkroomRecipe(dodgeBurnMasks: [LocalMask(kind: .burn, points: point, exposureStops: -3.1)]),
            DarkroomRecipe(dodgeBurnMasks: [LocalMask(kind: .dodge, points: point, exposureStops: 3),
                                            LocalMask(kind: .dodge, points: point, exposureStops: 3.5)])
        ]
    }

    private func assertEqual(_ actual: [Double], _ expected: [Double], accuracy: Double, _ message: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        for channel in 0..<3 {
            XCTAssertEqual(actual[channel], expected[channel], accuracy: accuracy, "\(message): \(actual) against \(expected)",
                           file: file, line: line)
        }
    }
}

/// A chart of flat patches, twelve grays above twelve colors, as a developed master.
private struct Chart {
    static let side = 160
    static let columns = 6
    static let grays: [UInt8] = [0, 8, 24, 48, 80, 112, 144, 176, 208, 232, 247, 255]
    static let colors: [[UInt8]] = [
        [200, 40, 40], [40, 180, 60], [40, 60, 200], [230, 210, 40], [40, 200, 210], [200, 50, 190],
        [120, 60, 30], [240, 170, 140], [90, 120, 160], [30, 70, 40], [250, 250, 200], [20, 10, 40]
    ]
    static let patches = grays.count + colors.count
    static let width = side * columns
    static let height = side * patches / columns

    let master: Data
    private let decoded: DecodedPixels

    init() throws {
        var bytes = [UInt8](repeating: 255, count: Self.width * Self.height * 4)
        for y in 0..<Self.height { for x in 0..<Self.width {
            let patch = y / Self.side * Self.columns + x / Self.side
            let color = patch < Self.grays.count ? [UInt8](repeating: Self.grays[patch], count: 3) : Self.colors[patch - Self.grays.count]
            for channel in 0..<3 { bytes[(y * Self.width + x) * 4 + channel] = color[channel] }
        } }
        master = try Self.jpeg(bytes, width: Self.width, height: Self.height)
        decoded = try DecodedPixels(master)
    }

    /// The chart's top left 2048 pixel square, tiled, on an Instant print's white card.
    static func instantCard() throws -> Data {
        let card = InstantPrintCard.self
        var bytes = [UInt8](repeating: 255, count: card.width * card.height * 4)
        for y in 0..<card.pictureSide { for x in 0..<card.pictureSide {
            let patch = (y / side * columns + x / side) % patches
            let color = patch < grays.count ? [UInt8](repeating: grays[patch], count: 3) : colors[patch - grays.count]
            for channel in 0..<3 { bytes[((y + card.sideBorder) * card.width + x + card.sideBorder) * 4 + channel] = color[channel] }
        } }
        return try jpeg(bytes, width: card.width, height: card.height)
    }

    /// The chart, tiled over a developed 6×6 print.
    static func mediumFormatPrint() throws -> Data {
        let edge = DevelopedPhotoSize.mediumFormatSide
        let tiles = (0..<patches).map { $0 < grays.count ? [UInt8](repeating: grays[$0], count: 3) : colors[$0 - grays.count] }
        var bytes: [UInt8] = [], row: [UInt8] = []
        for y in 0..<edge {
            // Every row of a band of patches is the same.
            if y % side == 0 { row = (0..<edge).flatMap { tiles[(y / side * columns + $0 / side) % patches] + [255] } }
            bytes += row
        }
        return try jpeg(bytes, width: edge, height: edge)
    }

    private static func jpeg(_ source: [UInt8], width: Int, height: Int) throws -> Data {
        var bytes = source
        let image = try bytes.withUnsafeMutableBytes { buffer in
            try XCTUnwrap(CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage())
        }
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 1] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }

    static func center(of patch: Int) -> (x: Int, y: Int) {
        (patch % columns * side + side / 2, patch / columns * side + side / 2)
    }

    /// The middle of a patch as a Dodge/Burn point, a fraction of the picture from its top left corner.
    static func point(of patch: Int) -> MaskPoint {
        let center = center(of: patch)
        return MaskPoint(x: Double(center.x) / Double(width), y: Double(center.y) / Double(height))
    }

    /// The patch as the master holds it, in 8-bit levels.
    func patch(_ patch: Int) -> [Double] { decoded.mean(around: Self.center(of: patch)) }

    /// An sRGB level given `stops` more exposure in linear light and clipped at black and white.
    static func exposed(_ level: Double, stops: Double) -> Double {
        let encoded = level / 255
        let linear = encoded <= 0.04045 ? encoded / 12.92 : pow((encoded + 0.055) / 1.055, 2.4)
        let lit = min(1, max(0, linear * pow(2, stops)))
        return 255 * (lit <= 0.0031308 ? lit * 12.92 : 1.055 * pow(lit, 1 / 2.4) - 0.055)
    }
}

private extension DecodedPixels {
    func channels(x: Int, y: Int) -> [UInt8] { Array(bytes[(y * width + x) * 4..<(y * width + x) * 4 + 3]) }

    /// The mean red, green and blue of the square reaching `radius` pixels from a point.
    func mean(around center: (x: Int, y: Int), radius: Int = 30) -> [Double] {
        var sums = [0.0, 0.0, 0.0]
        for y in center.y - radius...center.y + radius { for x in center.x - radius...center.x + radius {
            for channel in 0..<3 { sums[channel] += Double(bytes[(y * width + x) * 4 + channel]) }
        } }
        let count = Double((2 * radius + 1) * (2 * radius + 1))
        return sums.map { $0 / count }
    }

    /// The largest difference of any channel across the square reaching `radius` pixels from a point.
    func spread(around center: (x: Int, y: Int), radius: Int = 4) -> Int {
        var lowest = [255, 255, 255], highest = [0, 0, 0]
        for y in center.y - radius...center.y + radius { for x in center.x - radius...center.x + radius {
            for channel in 0..<3 {
                let value = Int(bytes[(y * width + x) * 4 + channel])
                lowest[channel] = min(lowest[channel], value); highest[channel] = max(highest[channel], value)
            }
        } }
        return zip(highest, lowest).map(-).max()!
    }
}

/// The Darkroom's printing as the build before the 2026-10-13 limits made it, kept unchanged so a recipe saved then
/// can be held to the bytes it printed. Never bring it up to date with `NativePhotoRenderer`.
private enum EarlierDarkroom {
    static func print(master: Data, recipe: DarkroomRecipe, instant: Bool = false) throws -> Data {
        var image = normalize(try XCTUnwrap(CIImage(data: master, options: [.applyOrientationProperty: true])))
        let card = InstantPrintCard.self
        if instant {
            image = normalize(image.cropped(to: CGRect(x: card.sideBorder, y: card.bottomBorder, width: card.pictureSide, height: card.pictureSide)))
        }
        image = adjust(image, recipe: recipe)
        if instant {
            let paper = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: card.width, height: card.height))
            image = normalize(image).transformed(
                by: CGAffineTransform(translationX: CGFloat(card.sideBorder), y: CGFloat(card.bottomBorder))
            ).composited(over: paper)
        }
        let context = CIContext(options: [.cacheIntermediates: false])
        return try XCTUnwrap(context.jpegRepresentation(of: image, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, options: [
            kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.94
        ]))
    }

    private static func normalize(_ image: CIImage) -> CIImage {
        image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
    }

    private static func adjust(_ source: CIImage, recipe: DarkroomRecipe) -> CIImage {
        var image = source.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: recipe.printExposureStops])
        if let grade = recipe.contrastGrade {
            image = image.applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 0.7 + Double(grade) * 0.15])
        }
        if let color = recipe.colorFiltration {
            image = image.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 1 - color.cyan / 150, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 1 - color.magenta / 150, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 1 - color.yellow / 150, w: 0)
            ])
        }
        for mask in recipe.dodgeBurnMasks {
            let ev = (mask.kind == .dodge ? 1.0 : -1.0) * abs(mask.exposureStops)
            let adjusted = image.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: ev])
            var combined = CIImage(color: .black).cropped(to: image.extent)
            for point in mask.points {
                let gradient = CIFilter(name: "CIRadialGradient", parameters: [
                    "inputCenter": CIVector(x: point.x * image.extent.width, y: (1 - point.y) * image.extent.height),
                    "inputRadius0": image.extent.width * 0.012,
                    "inputRadius1": image.extent.width * 0.075,
                    "inputColor0": CIColor.white, "inputColor1": CIColor.clear
                ])!.outputImage!.cropped(to: image.extent)
                combined = gradient.composited(over: combined)
            }
            image = adjusted.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: image, kCIInputMaskImageKey: combined
            ])
        }
        if let toning = recipe.chemicalToning {
            let toned: CIImage
            switch toning.chemistry {
            case .sepia:
                toned = image.applyingFilter("CISepiaTone", parameters: [kCIInputIntensityKey: toning.amount])
            case .selenium:
                let tinted = image.applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: 1.04, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: 0.94, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: 1.02, w: 0)
                ])
                let shadows = image.applyingFilter("CIColorInvert").applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: toning.amount, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: toning.amount, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: toning.amount, w: 0)
                ])
                toned = tinted.applyingFilter("CIBlendWithMask", parameters: [
                    kCIInputBackgroundImageKey: image, kCIInputMaskImageKey: shadows
                ])
            }
            image = toned
        }
        if let crop = recipe.crop {
            let size = image.extent.size
            image = normalize(image.cropped(to: CGRect(
                x: crop.x * size.width, y: (1 - crop.y - crop.height) * size.height,
                width: crop.width * size.width, height: crop.height * size.height
            ).integral))
        }
        return image
    }
}
