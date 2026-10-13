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

/// Treatment versions 3 and 4: each Camera and Film Stock develops with its own fresh look and the imperfections PRD
/// 2.1 section 6 gives it (ADRs 0013 to 0015). The captain approved every Camera's look on its review board (DEC-04,
/// QA-16), and the Instant's contrast after the study of preserved 1970s prints, which is what version 4 changes.
/// These tests hold each look's character and bounds, not its numbers.
final class FilmLookTests: XCTestCase {
    private static let linear = CGColorSpace(name: CGColorSpace.linearSRGB)!
    private static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

    // MARK: - Versions

    /// A Film loaded today records version 4 in its Camera package, and Development assigns it to every capture; a Film
    /// whose package recorded version 3 keeps version 3, and one locked before packages recorded a version develops
    /// with version 2.
    func testDevelopmentAssignsTheTreatmentVersionTheFilmsPackageRecorded() throws {
        XCTAssertEqual(NativePhotoRenderer.treatmentVersion, "film-look-4")
        XCTAssertEqual(TreatmentVersion.current.rawValue, CameraCatalog.treatmentVersion)
        XCTAssertEqual(NativePhotoRenderer.renderableTreatmentVersions,
                       ["film-look-1-provisional", "film-look-2-provisional", "film-look-3", "film-look-4"])
        for camera in CameraCatalog.all { XCTAssertEqual(camera.treatmentVersion, "film-look-4", "\(camera.id)") }

        let today = try Film(camera: CameraCatalog.mediumFormat6x6, title: "Today", filmStock: .color)
        var film = today
        _ = try film.recordSavedPhoto()
        var run = DevelopmentRun(film: film)
        try run.assignMissingTreatments(for: film)
        XCTAssertEqual(run.treatmentVersion, "film-look-4")
        XCTAssertEqual(run.assignments[1]?.treatmentVersion, "film-look-4")

        // An Instant pack loaded under version 3: its package says so, and every print keeps that version, the ones
        // exposed after the update too.
        let versionThree = CameraPackage(id: .instant1970s, displayName: "1970s Instant", medium: .photo, capacity: .exposures(10),
                                         revealRule: .instantPerExposure, treatmentVersion: "film-look-3")
        var pack = try Film(camera: try JSONDecoder().decode(CameraPackage.self, from: JSONEncoder().encode(versionThree)), title: "Pack")
        XCTAssertEqual(pack.treatmentVersion, "film-look-3")
        _ = try pack.recordSavedPhoto()
        var packRun = DevelopmentRun(film: pack)
        try packRun.assignMissingTreatments(for: pack)
        _ = try pack.recordSavedPhoto()
        try packRun.assignMissingTreatments(for: pack)
        XCTAssertEqual(packRun.treatmentVersion, "film-look-3")
        XCTAssertEqual(packRun.assignments.values.map(\.treatmentVersion), ["film-look-3", "film-look-3"])
        XCTAssertTrue(packRun.rendersAssignedTreatment(try XCTUnwrap(packRun.assignments[2])))

        // The package as the version 2 build locked it into a Film: no treatment version recorded.
        let locked = CameraPackage(id: .instant1970s, displayName: "1970s Instant", medium: .photo, capacity: .exposures(10),
                                   revealRule: .instantPerExposure)
        let encoded = try JSONEncoder().encode(locked)
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("treatmentVersion"))
        var earlier = try Film(camera: try JSONDecoder().decode(CameraPackage.self, from: encoded), title: "Earlier")
        XCTAssertEqual(earlier.treatmentVersion, "film-look-2-provisional")
        _ = try earlier.recordSavedPhoto()
        var earlierRun = DevelopmentRun(film: earlier)
        try earlierRun.assignMissingTreatments(for: earlier)
        XCTAssertEqual(earlierRun.treatmentVersion, "film-look-2-provisional")
        // An Instant print exposed after the update still develops with the version its Film started with.
        _ = try earlier.recordSavedPhoto()
        try earlierRun.assignMissingTreatments(for: earlier)
        XCTAssertEqual(earlierRun.assignments[2]?.treatmentVersion, "film-look-2-provisional")
        XCTAssertEqual(earlierRun.treatmentVersion(of: try XCTUnwrap(earlierRun.assignments[2])), "film-look-2-provisional")
    }

    func testAnUnknownTreatmentVersionIsRefusedRatherThanRenderedWithAnotherLook() throws {
        XCTAssertThrowsError(try DevelopedTreatment(version: "film-look-9", camera: .disposable1990s, filmStock: nil, seed: 1)) {
            XCTAssertEqual($0 as? NativeRenderError, .unrenderableTreatment)
        }
    }

    /// Version 3 is a new look for every Camera and Film Stock, and no two of them develop alike.
    func testEveryCameraAndFilmStockHasItsOwnLookUnlikeVersionTwo() throws {
        try requireTetrahedralReader()
        let scene = Self.colorChart(width: 480, height: 360)
        var looks: [String: DecodedPixels] = [:]
        for (camera, filmStock) in Self.treatments {
            let name = "\(camera) \(filmStock?.rawValue ?? "")"
            let current = try render(scene, camera: camera, filmStock: filmStock)
            let earlier = try render(scene, camera: camera, filmStock: filmStock, version: "film-look-2-provisional")
            XCTAssertGreaterThan(current.meanColorDifference(from: earlier), 4, "\(name) differs from version 2")
            // The two gentle color negative stocks, the 6×6's and the 16mm's, are the closest pair in color; what sets
            // them further apart is the 16mm's motion, glow and frame.
            for (other, pixels) in looks {
                XCTAssertGreaterThan(current.meanColorDifference(from: pixels), 2, "\(name) differs from \(other)")
            }
            looks[name] = current
        }
    }

    // MARK: - Fresh, not aged (ADR 0013)

    /// No look fades, yellows or shifts its dyes: blacks stay deep, white stays white, and color keeps its strength and
    /// its hue. Black-and-white stays neutral gray. The exceptions are the looks the captain chose himself (ADR 0016),
    /// each held to its chosen look by tests of its own: the Instant and the Super 8 below, and the 16mm's color Film
    /// Stock by `NegativeFilmTests` and `ScenePassesTests`.
    func testEveryLookIsFreshlyProcessedNotAged() {
        let exceptions = Self.treatments.filter { FilmLook.isCaptainsException(camera: $0.0, filmStock: $0.1) }
        XCTAssertEqual(exceptions.map { "\($0.0) \($0.1?.rawValue ?? "")" },
                       ["instant1970s ", "mediumFormat6x6 color", "super8HomeMovie ", "cinema16mm color"],
                       "Only the captain's choice takes a look out of ADR 0013")
        for (camera, filmStock) in Self.treatments where !FilmLook.isCaptainsException(camera: camera, filmStock: filmStock) {
            let treatment = FilmLook.treatment(camera: camera, filmStock: filmStock)
            let name = "\(camera) \(filmStock?.rawValue ?? "")"
            let develop = { (color: FilmLook.RGB) in DevelopedTreatment.develop(color, treatment.emulsion) }
            let black = develop(FilmLook.RGB(0.03, 0.03, 0.03))
            XCTAssertLessThan(max(black.red, black.green, black.blue), 0.06, "\(name): blacks stay deep, never faded")
            let white = develop(FilmLook.RGB(0.97, 0.97, 0.97))
            XCTAssertGreaterThan(min(white.red, white.green, white.blue), 0.9, "\(name): white stays bright")
            XCTAssertLessThan(white.red - white.blue, 0.045, "\(name): white is not yellowed")
            guard case .color = treatment.emulsion else {
                for color in Self.patches { let gray = develop(color); XCTAssertEqual(gray.red, gray.blue, accuracy: 0.0001, name) }
                continue
            }
            for color in Self.patches {
                let developed = develop(color)
                // A stock may be gentler in color than the capture, but never washed out.
                XCTAssertGreaterThan(chroma(developed), chroma(color) * 0.8, "\(name): \(color) keeps its color strength")
                // A stock renders hues its own way (the 6×6's color stock turns greens toward yellow and blues toward
                // cyan, as the captain's reference pictures do), but no hue wanders as a shifted dye would.
                XCTAssertLessThan(hueDistance(developed, color), 30, "\(name): \(color) keeps its hue")
            }
        }
    }

    /// The print curve always rises from its black to its white, whatever its contrast, midtones and shoulder, and a
    /// shoulder lowers the upper tones only.
    func testThePrintCurveRisesFromBlackToWhiteAndAShoulderLowersOnlyTheUpperTones() {
        for (camera, filmStock) in Self.treatments {
            let tone: FilmLook.ToneCurve
            switch FilmLook.treatment(camera: camera, filmStock: filmStock).emulsion {
            case let .color(film): tone = film.tone
            case let .monochrome(film): tone = film.tone
            // A negative film has no print curve of this kind; `NegativeFilmTests` holds its ramp.
            case .negative: continue
            }
            let levels = (0...100).map { tone(Double($0) / 100) }
            XCTAssertEqual(levels.first!, tone.black, accuracy: 0.0001, "\(camera)")
            XCTAssertEqual(levels.last!, tone.white, accuracy: 0.0001, "\(camera)")
            for (lower, upper) in zip(levels, levels.dropFirst()) { XCTAssertGreaterThan(upper, lower, "\(camera) rises") }
        }
        let plain = FilmLook.ToneCurve(contrast: 1), soft = FilmLook.ToneCurve(contrast: 1, shoulder: 0.08)
        XCTAssertEqual(soft(0.75), plain(0.75) - 0.08, accuracy: 0.001)
        XCTAssertEqual(soft(0.1), plain(0.1), accuracy: 0.002, "Shadows keep their place")
        XCTAssertEqual(soft(1), 1, accuracy: 0.0001)
    }

    /// The Instant develops with the faded look the captain chose on its review board on 2026-10-10 (ADR 0016): lifted,
    /// milky blacks, softened whites, muted color, and age-style tints, blue in the shadows and yellow in the
    /// highlights. Its contrast is the one he chose on 2026-10-13 ("B") after the study of preserved 1970s prints:
    /// more than the look had before, with black a little deeper, and still no more than the capture's own.
    func testTheInstantKeepsTheFadedLookWithTheContrastTheCaptainChoseAfterTheStudy() {
        let develop = { (color: FilmLook.RGB) in DevelopedTreatment.develop(color, FilmLook.instant.emulsion) }
        let before = { (color: FilmLook.RGB) in DevelopedTreatment.develop(color, FilmLook.instantVersion3.emulsion) }
        let black = develop(FilmLook.RGB(0.03, 0.03, 0.03)), white = develop(FilmLook.RGB(0.97, 0.97, 0.97))
        XCTAssertGreaterThan(min(black.red, black.green, black.blue), 0.1, "Blacks are lifted and milky (\(black))")
        XCTAssertLessThan(max(white.red, white.green, white.blue), 0.93, "Whites are softened (\(white))")
        XCTAssertGreaterThan(black.blue, black.red + 0.01, "Blue in the shadows (\(black))")
        XCTAssertGreaterThan(white.red, white.blue + 0.03, "Yellow in the highlights (\(white))")
        XCTAssertLessThan(black.green, before(FilmLook.RGB(0.03, 0.03, 0.03)).green - 0.03, "Black sits deeper than before the study")
        let contrast = { (look: (FilmLook.RGB) -> FilmLook.RGB) in
            look(FilmLook.RGB(0.75, 0.75, 0.75)).green - look(FilmLook.RGB(0.25, 0.25, 0.25)).green
        }
        XCTAssertLessThan(contrast(develop), 0.5, "No more contrast than the capture's 0.5 (\(contrast(develop)))")
        XCTAssertGreaterThan(contrast(develop), contrast(before) + 0.1, "More than before the study (\(contrast(before)))")
        for color in Self.patches {
            XCTAssertLessThan(chroma(develop(color)), chroma(color) * 0.9, "\(color) is muted")
        }
        // The curve is a print's: steepest in the middle, easing into black and into white.
        guard case let .color(film) = FilmLook.instant.emulsion else { return XCTFail("The Instant is a color film") }
        let slope = { (at: Double) in (film.tone(at + 0.01) - film.tone(at - 0.01)) / 0.02 }
        XCTAssertGreaterThan(slope(0.5), slope(0.08), "Shadows ease into black")
        XCTAssertGreaterThan(slope(0.5), slope(0.92), "Highlights ease into white")
    }

    /// Version 3 keeps the Instant as it was before the study, a curve flatter than the capture's and flattest in the
    /// middle, so an Instant Film loaded under version 3 develops as it would have. Every other Camera and Film Stock
    /// is the same in versions 3 and 4.
    func testVersionThreeKeepsTheInstantAsItWasBeforeTheStudy() {
        let earlier = FilmLook.treatment(version: .three, camera: .instant1970s, filmStock: nil)
        // Every value of version 3's Instant, as the version 3 build (5c3a217) had it. Version 3 is frozen, so this
        // copy never changes.
        XCTAssertEqual(earlier, FilmLook.Treatment(
            emulsion: .color(FilmLook.ColorEmulsion(
                warmth: 0.09, tint: -0.005,
                layers: FilmLook.Layers(redFromGreen: 0.12, greenFromBlue: 0.15, blueFromGreen: 0.15), saturation: 0.85,
                tone: FilmLook.ToneCurve(contrast: 0.82, midtones: 0.88, black: 0.13, white: 0.9),
                shadows: FilmLook.RGB(0, 0.008, 0.03), highlights: FilmLook.RGB(0.012, 0.004, -0.03),
                grain: FilmLook.Grain(amplitude: 4.5, size: 0.0014, chroma: 0.3)
            )),
            lens: FilmLook.Lens(softness: 0.0011, edgeSoftness: 0.001, edgeDarkening: 0.4),
            printVariation: FilmLook.PrintVariation(density: 0.12, warmth: 0.025, tint: 0.01)
        ))
        XCTAssertEqual(earlier, FilmLook.instantVersion3)
        XCTAssertNotEqual(earlier, FilmLook.treatment(version: .four, camera: .instant1970s, filmStock: nil))
        XCTAssertEqual(FilmLook.treatment(camera: .instant1970s, filmStock: nil), FilmLook.instant, "Today's is version 4's")
        guard case let .color(before) = earlier.emulsion else { return XCTFail("The Instant is a color film") }
        let develop = { (color: FilmLook.RGB) in DevelopedTreatment.develop(color, earlier.emulsion) }
        let quarter = develop(FilmLook.RGB(0.25, 0.25, 0.25)).green, threeQuarter = develop(FilmLook.RGB(0.75, 0.75, 0.75)).green
        XCTAssertLessThan(threeQuarter - quarter, 0.42, "Lower contrast than the capture's 0.5 (\(threeQuarter - quarter))")
        // The two versions' looks differ in nothing but the Instant's print curve.
        var sameButTheCurve = FilmLook.instant
        guard case var .color(emulsion) = sameButTheCurve.emulsion else { return XCTFail("The Instant is a color film") }
        emulsion.tone = before.tone
        sameButTheCurve.emulsion = .color(emulsion)
        XCTAssertEqual(sameButTheCurve, earlier)
        for (camera, filmStock) in Self.treatments where camera != .instant1970s {
            XCTAssertEqual(FilmLook.treatment(version: .three, camera: camera, filmStock: filmStock),
                           FilmLook.treatment(version: .four, camera: camera, filmStock: filmStock), "\(camera) \(String(describing: filmStock))")
        }
    }

    /// The Super 8 develops with the look the captain chose on its review board on 2026-10-10, "muted with a glow"
    /// (ADR 0016): lowered whites, no more contrast than the capture, color quieter than the capture's, teal in the
    /// shadows and warmth in the highlights, and a warm reddish-orange glow around bright highlights. Its blacks stay
    /// deep, and its gate imperfections are unchanged.
    func testTheSuperEightDevelopsMutedWithAGlowAsTheCaptainChose() throws {
        let treatment = FilmLook.super8
        let develop = { (color: FilmLook.RGB) in DevelopedTreatment.develop(color, treatment.emulsion) }
        let black = develop(FilmLook.RGB(0.03, 0.03, 0.03)), white = develop(FilmLook.RGB(0.97, 0.97, 0.97))
        XCTAssertLessThan(max(black.red, black.green, black.blue), 0.06, "Shadows stay dark (\(black))")
        XCTAssertLessThan(max(white.red, white.green, white.blue), 0.95, "Whites are lowered (\(white))")
        XCTAssertGreaterThan(white.red, white.blue + 0.01, "Warmth in the highlights (\(white))")
        XCTAssertGreaterThan(black.blue, black.red, "Teal in the shadows (\(black))")
        let quarter = develop(FilmLook.RGB(0.25, 0.25, 0.25)).green, threeQuarter = develop(FilmLook.RGB(0.75, 0.75, 0.75)).green
        XCTAssertLessThan(threeQuarter - quarter, 0.5, "No more contrast than the capture (\(threeQuarter - quarter))")
        for color in Self.patches {
            XCTAssertLessThan(chroma(develop(color)), chroma(color), "\(color) is quieter than the capture")
        }
        let halation = try XCTUnwrap(treatment.halation)
        XCTAssertGreaterThan(halation.color.red, halation.color.green, "The glow is reddish-orange")
        XCTAssertGreaterThan(halation.color.green, halation.color.blue, "The glow is reddish-orange")
        let gate = try XCTUnwrap(treatment.gate)
        XCTAssertGreaterThan(gate.flicker, 0)
        XCTAssertGreaterThan(gate.dust, 0)
        XCTAssertGreaterThan(gate.hair, 0)

        // Rendered: a bright light in a dark frame gets a warm ring, as the 16mm's does.
        let light = CIFilter(name: "CIRadialGradient", parameters: [
            "inputCenter": CIVector(x: 480, y: 480), "inputRadius0": 30, "inputRadius1": 31,
            "inputColor0": CIColor(red: 1, green: 1, blue: 1, colorSpace: Self.linear)!,
            "inputColor1": CIColor(red: 0.01, green: 0.01, blue: 0.01, colorSpace: Self.linear)!
        ])!.outputImage!.cropped(to: CGRect(x: 0, y: 0, width: 960, height: 960))
        var glowing = treatment
        glowing.gate = nil
        glowing.lens = FilmLook.Lens()
        glowing.emulsion = Self.identity(grain: FilmLook.Grain(amplitude: 0, size: 0))
        var plain = glowing
        plain.halation = nil
        let ring = try render(light, treatment: glowing).meanColor(x: 436..<444, y: 470..<490)
        let dark = try render(light, treatment: plain).meanColor(x: 436..<444, y: 470..<490)
        XCTAssertGreaterThan(ring.red, dark.red + 8, "A glow around the light (\(ring) vs \(dark))")
        XCTAssertGreaterThan(ring.red - dark.red, ring.blue - dark.blue + 6, "Warm, not white (\(ring) vs \(dark))")
    }

    // MARK: - The Disposable

    /// An exposure the flash lit develops with a hot center that falls away to darker corners and harsher contrast;
    /// the same scene without flash does not.
    func testTheDisposablesFlashLightsTheCenterAndLetsTheCornersFallAway() throws {
        let scene = CIImage(color: CIColor(red: 0.45, green: 0.4, blue: 0.35, colorSpace: Self.linear)!)
            .cropped(to: CGRect(x: 0, y: 0, width: 600, height: 400))
        let plain = try render(scene, camera: .disposable1990s, filmStock: nil)
        let flashed = try render(scene, camera: .disposable1990s, filmStock: nil, flashFired: true)
        let plainFalloff = plain.meanLuminance(x: 270..<330, y: 170..<230) - plain.meanLuminance(x: 0..<40, y: 0..<40)
        let flashFalloff = flashed.meanLuminance(x: 270..<330, y: 170..<230) - flashed.meanLuminance(x: 0..<40, y: 0..<40)
        XCTAssertGreaterThan(flashFalloff, plainFalloff + 25, "Flash falls away toward the corners (\(flashFalloff) vs \(plainFalloff))")
        XCTAssertGreaterThan(flashed.meanLuminance(x: 270..<330, y: 170..<230), plain.meanLuminance(x: 270..<330, y: 170..<230),
                             "Flash lights the center brighter")
        let develop = { (contrast: Bool) in
            DevelopedTreatment.develop(FilmLook.RGB(0.2, 0.2, 0.2), FilmLook.disposable.emulsion,
                                       extraContrast: contrast ? FilmLook.disposable.flash!.contrast : 0).green
        }
        XCTAssertLessThan(develop(true), develop(false), "Flash prints its shadows deeper")
    }

    /// The Disposable reads its flash from the capture's Exif Flash value, whose lowest bit records that it fired.
    func testTheFlashIsReadFromTheCapturesExif() {
        XCTAssertTrue(NativePhotoRenderer.flashFired([kCGImagePropertyExifDictionary as String: [kCGImagePropertyExifFlash as String: 1]]))
        XCTAssertTrue(NativePhotoRenderer.flashFired([kCGImagePropertyExifDictionary as String: [kCGImagePropertyExifFlash as String: 25]]))
        XCTAssertFalse(NativePhotoRenderer.flashFired([kCGImagePropertyExifDictionary as String: [kCGImagePropertyExifFlash as String: 16]]))
        XCTAssertFalse(NativePhotoRenderer.flashFired([:]))
    }

    /// Through `develop`, a capture whose Exif says the flash fired develops differently from the same pixels without.
    func testADevelopedDisposableExposureFollowsItsFlash() throws {
        try requireTetrahedralReader()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("FilmLookTests-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let plain = root.appendingPathComponent("plain.jpg"), flashed = root.appendingPathComponent("flash.jpg")
        let scene = CIImage(color: CIColor(red: 0.4, green: 0.35, blue: 0.3, colorSpace: Self.linear)!)
            .cropped(to: CGRect(x: 0, y: 0, width: 480, height: 360))
        try writeJPEG(scene, to: plain, flash: 16)
        try writeJPEG(scene, to: flashed, flash: 1)
        let camera = CameraCatalog.disposable1990s
        let withoutFlash = try DecodedPixels(NativePhotoRenderer.develop(source: plain, camera: camera, seed: 3))
        let withFlash = try DecodedPixels(NativePhotoRenderer.develop(source: flashed, camera: camera, seed: 3))
        XCTAssertGreaterThan(withFlash.meanColorDifference(from: withoutFlash), 5)
        // Every other Camera has no flash look, so the Exif changes nothing.
        let square = CameraCatalog.mediumFormat6x6
        XCTAssertEqual(try NativePhotoRenderer.develop(source: plain, camera: square, seed: 3, filmStock: .color),
                       try NativePhotoRenderer.develop(source: flashed, camera: square, seed: 3, filmStock: .color))
    }

    /// The Disposable's 800-speed grain is heavy, and heaviest in the shadows, so a dim scene without flash develops
    /// dark and grainy (PRD 2.1 FR-04).
    func testTheDisposablesGrainIsHeavyAndGrowsInADimScene() throws {
        try requireTetrahedralReader()
        let mid = try render(Self.even(0.5), camera: .disposable1990s, filmStock: nil)
        let dim = try render(Self.even(0.12), camera: .disposable1990s, filmStock: nil)
        let squareDim = try render(Self.even(0.12), camera: .mediumFormat6x6, filmStock: .color)
        XCTAssertGreaterThan(mid.centerDeviation, 3.5, "Heavy grain on a mid-gray scene (\(mid.centerDeviation))")
        XCTAssertGreaterThan(dim.centerDeviation, squareDim.centerDeviation * 3,
                             "A dim Disposable scene is far grainier than the 6×6's (\(dim.centerDeviation) vs \(squareDim.centerDeviation))")
    }

    // MARK: - Grain across the Cameras

    /// PRD 2.1 section 6: heavy grain on the Disposable, visible grain on the 16mm, fine grain on the Super 8 and very
    /// fine grain on the 6×6's color stock, whose black-and-white stock has distinct grain; the Instant shows soft
    /// detail with a coarse texture, lighter than the Disposable's grain. The two Movie Cameras' grain is not ranked
    /// against each other: the captain's board notes ask for a fine, organic grain with clean shadows on the 16mm's
    /// color stock, which leaves it about as fine as the Super 8's.
    func testGrainFollowsEachFormat() throws {
        try requireTetrahedralReader()
        var grain: [String: Double] = [:]
        for (camera, filmStock) in Self.treatments {
            var treatment = FilmLook.treatment(camera: camera, filmStock: filmStock)
            treatment.lens = FilmLook.Lens()
            treatment.gate = nil
            treatment.halation = nil
            var scene = Self.even(0.214)
            if let passes = treatment.scene {
                // A negative film's grain is one of its scene passes; the others are set aside like the lens and gate.
                // Its strength in each pixel grows with the frame's width, so it is measured on a strip as wide as
                // the Camera develops, a Developed Clip or the 6×6's master, not on the small square the other
                // formats are measured on.
                treatment.scene = FilmLook.ScenePasses(referenceWidth: passes.referenceWidth, capture: passes.capture, grain: passes.grain)
                scene = scene.clampedToExtent().cropped(to: CGRect(x: 0, y: 0, width: camera == .mediumFormat6x6 ? 3072 : 1920, height: 256))
            }
            let pixels = try render(scene, treatment: treatment)
            grain["\(camera) \(filmStock?.rawValue ?? "")"] = pixels.centerDeviation
        }
        let disposable = grain["disposable1990s "]!, cinema = grain["cinema16mm color"]!, super8 = grain["super8HomeMovie "]!
        let square = grain["mediumFormat6x6 color"]!, squareMono = grain["mediumFormat6x6 blackAndWhite"]!
        let instant = grain["instant1970s "]!
        XCTAssertGreaterThan(disposable, cinema, "\(grain)")
        XCTAssertGreaterThan(disposable, super8, "\(grain)")
        XCTAssertGreaterThan(cinema, square, "\(grain)")
        XCTAssertGreaterThan(super8, square, "\(grain)")
        XCTAssertGreaterThan(squareMono, square * 2.5, "\(grain)")
        XCTAssertLessThan(square, 2.5, "Very fine (\(square))")
        XCTAssertLessThan(instant, disposable, "The Instant's texture stays below the Disposable's heavy grain (\(grain))")
    }

    /// A grain's amplitude is the standard deviation, in 8-bit levels, it adds to an even mid-gray, at any clump size.
    func testGrainAmplitudeIsTheDeviationItAddsToMidGray() throws {
        for pixels in [1.25, 2, 4] {
            let grain = FilmLook.Grain(amplitude: 10, size: pixels / 512)
            let treatment = FilmLook.Treatment(emulsion: Self.identity(grain: grain), lens: FilmLook.Lens())
            let developed = try render(Self.even(0.214), treatment: treatment)
            XCTAssertEqual(developed.centerDeviation, 10, accuracy: 1.5, "\(pixels)-pixel clumps")
        }
    }

    /// Grain adds texture without moving the tone: an even mid-gray keeps its level.
    func testGrainKeepsTheTone() throws {
        for (camera, filmStock) in Self.treatments {
            var treatment = FilmLook.treatment(camera: camera, filmStock: filmStock)
            treatment.lens = FilmLook.Lens()
            treatment.gate = nil
            treatment.halation = nil
            treatment.emulsion = Self.identity(grain: treatment.emulsion.grain)
            let pixels = try render(Self.even(0.214), treatment: treatment)
            XCTAssertEqual(pixels.meanLuminance(x: 64..<448, y: 64..<448), 128, accuracy: 2, "\(camera) \(filmStock?.rawValue ?? "")")
        }
    }

    // MARK: - Lens

    /// The Disposable's plastic lens and both Movie Cameras soften and darken toward the corners; the 6×6's lens stays
    /// sharp to its corners.
    func testSoftDarkEdgesWhereTheFormatHasThem() throws {
        let side = 1536
        let checks = Self.checkerboard(side: CGFloat(side), square: 6)
        // The color Film Stocks of the 16mm and the 6×6 soften or darken their edges in scene light;
        // `ScenePassesTests` and `MediumFormatPassesTests` hold that.
        for (camera, filmStock, softens) in [(CameraID.disposable1990s, FilmStock?.none, true), (.super8HomeMovie, nil, true),
                                            (.cinema16mm, .blackAndWhite, true), (.mediumFormat6x6, .blackAndWhite, false)] {
            var treatment = FilmLook.treatment(camera: camera, filmStock: filmStock)
            treatment.emulsion = Self.identity(grain: FilmLook.Grain(amplitude: 0, size: 0))
            treatment.gate = nil
            let pixels = try render(checks, treatment: treatment)
            // The sharpness of the checks' edges relative to the local brightness, so darker corners alone do not
            // count as softer.
            let middle = side / 2 - 36..<side / 2 + 36, corner = 12..<84
            let center = pixels.edgeSharpness(x: middle, y: middle) / pow(pixels.meanLuminance(x: middle, y: middle), 2)
            let edge = pixels.edgeSharpness(x: corner, y: corner) / pow(pixels.meanLuminance(x: corner, y: corner), 2)
            if softens {
                XCTAssertLessThan(edge, center * 0.85, "\(camera) softens its corners (\(edge) vs \(center))")
            } else {
                XCTAssertGreaterThan(edge, center * 0.95, "\(camera) stays sharp to its corners (\(edge) vs \(center))")
            }
            // On an even field, since blurring the checks in linear light brightens them.
            let even = try render(Self.even(0.214, side: CGFloat(side)), treatment: treatment)
            XCTAssertLessThan(even.meanLuminance(x: corner, y: corner), even.meanLuminance(x: middle, y: middle) - 4,
                              "\(camera) darkens its corners")
        }
    }

    // MARK: - The Instant

    /// Each print differs slightly from the next in color and density, chosen once from its seed: the same seed
    /// always develops the same print, and no print is far from the look.
    func testEachInstantPrintVariesSlightlyAndKeepsItsOwnVariation() throws {
        let scene = Self.colorChart(width: 256, height: 256)
        let first = try render(scene, camera: .instant1970s, filmStock: nil, seed: 1)
        XCTAssertEqual(first.bytes, try render(scene, camera: .instant1970s, filmStock: nil, seed: 1).bytes, "Assigned once")
        var differences: [Double] = []
        var unvaried = FilmLook.instant
        unvaried.printVariation = nil
        let middle = try render(scene, treatment: unvaried, seed: 1)
        for seed in UInt64(2)...UInt64(9) {
            let print = try render(scene, camera: .instant1970s, filmStock: nil, seed: seed)
            differences.append(print.meanColorDifference(from: first))
            XCTAssertLessThan(print.meanColorDifference(from: middle), 12, "Print \(seed) stays close to the look")
        }
        XCTAssertGreaterThan(differences.max()!, 1.5, "Prints differ (\(differences))")
    }

    // MARK: - Movie Cameras

    /// Super 8: the frame jumps and weaves, its brightness flickers, and dust specks come and go, each bounded so no
    /// frame is ruined; a hair caught in the gate stays for the whole clip.
    func testSuperEightFramesAreUnsteadyFlickerAndCarryDust() throws {
        let scene = Self.colorChart(width: 320, height: 240)
        let treatment = DevelopedTreatment(FilmLook.super8, seed: 5)
        var clean = FilmLook.super8
        clean.gate = nil
        let still = try DevelopedTreatment(clean, seed: 5).apply(to: scene, frame: 0, frameRate: 18)
        let reference = try pixels(still)
        var means: [Double] = []
        var offsets: [Int] = []
        for frame in 0..<36 {
            let developed = try pixels(treatment.apply(to: scene, frame: frame, frameRate: 18))
            means.append(developed.meanLuminance(x: 0..<320, y: 0..<240))
            offsets.append(developed.verticalOffset(from: reference, searching: 12))
            XCTAssertLessThan(developed.meanColorDifference(from: reference), 40, "Frame \(frame) is never ruined")
        }
        XCTAssertGreaterThan(Set(offsets).count, 3, "The frame jumps (\(offsets))")
        XCTAssertLessThanOrEqual(offsets.map(abs).max()!, 3, "Only a little (\(offsets))")
        XCTAssertGreaterThan(means.max()! - means.min()!, 2, "Brightness flickers (\(means))")

        // Dust: on a plain field, some frames carry small dark specks and none carries many.
        var field = FilmLook.super8
        field.emulsion = Self.identity(grain: FilmLook.Grain(amplitude: 0, size: 0))
        field.lens = FilmLook.Lens()
        field.gate?.jitter = 0
        field.gate?.weave = 0
        field.gate?.flicker = 0
        field.gate?.hair = 0
        let plain = DevelopedTreatment(field, seed: 5)
        // At the size a Developed Clip is made, where a speck is a few pixels across.
        let specked = try (0..<36).map { try pixels(plain.apply(to: Self.even(0.5, side: 960), frame: $0, frameRate: 18)).darkPixels(below: 170) }
        XCTAssertGreaterThan(specked.filter { $0 > 0 }.count, 6, "Dust comes and goes (\(specked))")
        XCTAssertLessThan(specked.filter { $0 > 0 }.count, 30, "Not on every frame (\(specked))")
        XCTAssertLessThan(specked.max()!, 960 * 960 / 500, "No frame is covered (\(specked))")
    }

    /// A clip filmed with a hair in the gate shows it at the same place on every frame, at the edge of the picture.
    func testAHairInTheGateStaysForTheWholeClip() throws {
        var field = FilmLook.super8
        field.emulsion = Self.identity(grain: FilmLook.Grain(amplitude: 0, size: 0))
        field.lens = FilmLook.Lens()
        field.gate = FilmLook.Gate(jitter: 0, weave: 0, weavePeriod: 1, hair: 1)
        let gate = DevelopedTreatment(field, seed: 8)
        let frames = try (0..<6).map { try pixels(gate.apply(to: Self.even(0.5, side: 320), frame: $0, frameRate: 18)) }
        for frame in frames {
            XCTAssertGreaterThan(frame.darkPixels(below: 100), 8, "A hair is drawn")
            XCTAssertLessThan(frame.darkPixels(below: 100), 320 * 320 / 100, "It is only a hair")
            XCTAssertLessThan(frame.darkPixelsAwayFromEdges(below: 100, margin: 0.45), 1, "It reaches in from an edge")
        }
        XCTAssertLessThan(frames[0].meanColorDifference(from: frames[5]), 1, "It stays in place")
    }

    /// The 16mm Cinema glows around its highlights, red on the color Film Stock and neutral on black-and-white, and
    /// leaves a scene without highlights alone.
    func testTheSixteenMillimeterGlowsRedOnColorAndNeutralOnBlackAndWhite() throws {
        try requireTetrahedralReader()
        // A bright light 60 pixels across in a dark 960-pixel frame, the size a Developed Clip is made.
        let light = CIFilter(name: "CIRadialGradient", parameters: [
            "inputCenter": CIVector(x: 480, y: 480), "inputRadius0": 30, "inputRadius1": 31,
            "inputColor0": CIColor(red: 1, green: 1, blue: 1, colorSpace: Self.linear)!,
            "inputColor1": CIColor(red: 0.01, green: 0.01, blue: 0.01, colorSpace: Self.linear)!
        ])!.outputImage!.cropped(to: CGRect(x: 0, y: 0, width: 960, height: 960))
        for filmStock in [FilmStock.color, .blackAndWhite] {
            var glowing = FilmLook.treatment(camera: .cinema16mm, filmStock: filmStock)
            var plain: FilmLook.Treatment
            if let scene = glowing.scene {
                // The color stock glows in scene light, before its film: its halation alone, and then without it.
                glowing.scene = FilmLook.ScenePasses(referenceWidth: scene.referenceWidth, halation: scene.halation)
                plain = glowing
                plain.scene = FilmLook.ScenePasses(referenceWidth: scene.referenceWidth)
            } else {
                glowing.gate = nil
                glowing.lens = FilmLook.Lens()
                glowing.emulsion = Self.identity(grain: FilmLook.Grain(amplitude: 0, size: 0))
                plain = glowing
                plain.halation = nil
            }
            let glow = try render(light, treatment: glowing), none = try render(light, treatment: plain)
            // A ring just outside the light.
            let ring = glow.meanColor(x: 436..<444, y: 470..<490), dark = none.meanColor(x: 436..<444, y: 470..<490)
            XCTAssertGreaterThan(ring.red, dark.red + 8, "\(filmStock) glows (\(ring) vs \(dark))")
            if filmStock == .color {
                XCTAssertGreaterThan(ring.red - dark.red, (ring.green - dark.green) * 3, "Red glow on color (\(ring) vs \(dark))")
            } else {
                XCTAssertEqual(ring.red, ring.blue, accuracy: 2, "Neutral glow on black-and-white (\(ring))")
            }
            let dimScene = try render(Self.even(0.3), treatment: glowing), dimPlain = try render(Self.even(0.3), treatment: plain)
            XCTAssertLessThan(dimScene.meanColorDifference(from: dimPlain), 0.5, "No highlight, no glow")
        }
    }

    /// The 16mm jitters and weaves a little, with no brightness flicker and no dust or hair. The color Film Stock
    /// weaves as the captain's reference does, in its scene passes, which have no flicker, dust or hair to give
    /// (`ScenePassesTests` holds the weave itself); the black-and-white stock weaves through its gate.
    func testTheSixteenMillimeterWeavesWithoutFlickerDustOrHair() throws {
        XCTAssertNil(FilmLook.cinemaColor.gate)
        XCTAssertNotNil(FilmLook.cinemaColor.scene?.weave)
        let gate = try XCTUnwrap(FilmLook.cinemaBlackAndWhite.gate)
        XCTAssertEqual(gate.flicker, 0)
        XCTAssertEqual(gate.dust, 0)
        XCTAssertEqual(gate.hair, 0)
        XCTAssertLessThan(gate.jitter, try XCTUnwrap(FilmLook.super8.gate).jitter, "Minor next to the Super 8")
        let scene = Self.colorChart(width: 320, height: 240)
        var still = FilmLook.cinemaBlackAndWhite
        still.gate = nil
        let reference = try render(scene, treatment: still)
        let moving = DevelopedTreatment(FilmLook.cinemaBlackAndWhite, seed: 4)
        var offsets: [Int] = []
        var means: [Double] = []
        for frame in 0..<24 {
            let developed = try pixels(moving.apply(to: scene, frame: frame, frameRate: 24))
            offsets.append(developed.horizontalOffset(from: reference, searching: 8))
            means.append(developed.meanLuminance(x: 40..<280, y: 40..<200))
        }
        XCTAssertGreaterThan(Set(offsets).count, 1, "It weaves (\(offsets))")
        XCTAssertLessThanOrEqual(offsets.map(abs).max()!, 2, "Only a little (\(offsets))")
        XCTAssertLessThan(means.max()! - means.min()!, 1.5, "No flicker (\(means))")
    }

    /// The 16mm's color Film Stock keeps a fixed daylight balance: a clip recorded in warm indoor light develops
    /// orange, daylight neutral and shade blue, against the light the capture recorded. Without a record, and on the
    /// black-and-white stock, the phone's white balance stands.
    func testTheSixteenMillimeterColorStockKeepsItsDaylightBalance() throws {
        try requireTetrahedralReader()
        var treatment = FilmLook.cinemaColor
        treatment.scene = nil
        let gray = Self.even(0.18, side: 256)
        func balance(_ light: SceneWhiteBalance?, _ look: FilmLook.Treatment = treatment) throws -> (red: Double, green: Double, blue: Double) {
            try pixels(DevelopedTreatment(look, seed: 3, sceneWhiteBalance: light).apply(to: gray)).meanColor(x: 64..<192, y: 64..<192)
        }
        let tungsten = try balance(SceneWhiteBalance(temperature: 3200, tint: 0))
        XCTAssertGreaterThan(tungsten.red - tungsten.blue, 40, "Warm indoor light develops orange (\(tungsten))")
        XCTAssertGreaterThan(tungsten.green - tungsten.blue, 10, "orange, not red (\(tungsten))")
        let daylight = try balance(SceneWhiteBalance(temperature: 5500, tint: 0))
        XCTAssertEqual(daylight.red, daylight.blue, accuracy: 3, "Daylight develops neutral (\(daylight))")
        let shade = try balance(SceneWhiteBalance(temperature: 8000, tint: 0))
        XCTAssertGreaterThan(shade.blue - shade.red, 8, "Shade develops cool (\(shade))")
        let unrecorded = try balance(nil)
        XCTAssertEqual(unrecorded.red, unrecorded.blue, accuracy: 3, "No record leaves the phone's balance (\(unrecorded))")
        var mono = FilmLook.cinemaBlackAndWhite
        mono.gate = nil
        let monoTungsten = try balance(SceneWhiteBalance(temperature: 3200, tint: 0), mono)
        XCTAssertEqual(monoTungsten.red, monoTungsten.blue, accuracy: 1, "Black-and-white stays gray")
        for other in [FilmLook.disposable, FilmLook.instant, FilmLook.mediumFormatColor, FilmLook.super8] {
            let lit = try balance(SceneWhiteBalance(temperature: 3200, tint: 0), other), unlit = try balance(nil, other)
            XCTAssertTrue(lit == unlit, "Only the 16mm's color stock keeps a fixed balance (\(lit) vs \(unlit))")
        }
    }

    /// A clip carries its recorded light in its QuickTime metadata, which Development reads.
    func testADevelopedClipReadsTheLightItWasRecordedIn() async throws {
        try requireTetrahedralReader()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("FilmLookTests-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("tungsten.mov"), plain = root.appendingPathComponent("plain.mov")
        try await writeGrayClip(to: source, light: SceneWhiteBalance(temperature: 3000, tint: 0))
        try await writeGrayClip(to: plain, light: nil)
        let recorded = try await NativeMovieRenderer.sceneWhiteBalance(of: AVURLAsset(url: source))
        XCTAssertEqual(recorded, SceneWhiteBalance(temperature: 3000, tint: 0))
        let unrecorded = try await NativeMovieRenderer.sceneWhiteBalance(of: AVURLAsset(url: plain))
        XCTAssertNil(unrecorded)
        let developed = root.appendingPathComponent("developed.mov")
        try await NativeMovieRenderer.developClip(source: source, destination: developed, camera: CameraCatalog.cinema16mm,
            filmStock: .color, seed: 2, orientation: .landscape, longEdge: 320)
        let frames = try await decodedFrames(developed)
        let frame = try XCTUnwrap(frames.first)
        let color = frame.meanColor(x: 120..<200, y: 90..<150)
        XCTAssertGreaterThan(color.red - color.blue, 30, "Orange (\(color))")
    }

    /// One second of even gray at 30 fps, with the light it was recorded in when given.
    private func writeGrayClip(to url: URL, light: SceneWhiteBalance?) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        if let light {
            let item = AVMutableMetadataItem()
            item.keySpace = .quickTimeMetadata
            item.key = SceneWhiteBalance.metadataKey as NSString
            item.value = light.metadataValue as NSString
            item.dataType = kCMMetadataBaseDataType_UTF8 as String
            writer.metadata = [item]
        }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 320, AVVideoHeightKey: 240])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 320, kCVPixelBufferHeightKey as String: 240])
        writer.add(input)
        XCTAssertTrue(writer.startWriting())
        writer.startSession(atSourceTime: .zero)
        for frame in 0..<30 {
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(2)) }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, try XCTUnwrap(adaptor.pixelBufferPool), &buffer)
            CIContext().render(Self.even(0.18, side: 320), to: try XCTUnwrap(buffer), bounds: CGRect(x: 0, y: 0, width: 320, height: 240),
                               colorSpace: CGColorSpaceCreateDeviceRGB())
            XCTAssertTrue(adaptor.append(try XCTUnwrap(buffer), withPresentationTime: CMTime(value: Int64(frame), timescale: 30)))
        }
        input.markAsFinished()
        await writer.finishWriting()
        XCTAssertEqual(writer.status, .completed)
    }

    // MARK: - Helpers

    private static let treatments: [(CameraID, FilmStock?)] = [
        (.disposable1990s, nil), (.instant1970s, nil), (.mediumFormat6x6, .color), (.mediumFormat6x6, .blackAndWhite),
        (.super8HomeMovie, nil), (.cinema16mm, .color), (.cinema16mm, .blackAndWhite)
    ]

    /// Mid-strength display colors across the hue circle and a skin tone.
    private static let patches = [
        FilmLook.RGB(0.7, 0.3, 0.3), FilmLook.RGB(0.3, 0.65, 0.3), FilmLook.RGB(0.3, 0.35, 0.7),
        FilmLook.RGB(0.7, 0.65, 0.3), FilmLook.RGB(0.76, 0.57, 0.47)
    ]

    /// A treatment's emulsion with no color or tone change, to look at one effect alone.
    private static func identity(grain: FilmLook.Grain) -> FilmLook.Emulsion {
        .color(FilmLook.ColorEmulsion(warmth: 0, saturation: 1, tone: FilmLook.ToneCurve(contrast: 1), grain: grain))
    }

    private static func even(_ linear: Double, side: CGFloat = 512) -> CIImage {
        CIImage(color: CIColor(red: linear, green: linear, blue: linear, colorSpace: Self.linear)!)
            .cropped(to: CGRect(x: 0, y: 0, width: side, height: side))
    }

    /// Bands of color across the hue circle over a dark-to-light ramp.
    private static func colorChart(width: CGFloat, height: CGFloat) -> CIImage {
        let hues = CIFilter(name: "CILinearGradient", parameters: [
            "inputPoint0": CIVector(x: 0, y: 0), "inputPoint1": CIVector(x: width, y: 0),
            "inputColor0": CIColor(red: 0.8, green: 0.1, blue: 0.1, colorSpace: Self.linear)!,
            "inputColor1": CIColor(red: 0.1, green: 0.2, blue: 0.8, colorSpace: Self.linear)!
        ])!.outputImage!
        let ramp = CIFilter(name: "CILinearGradient", parameters: [
            "inputPoint0": CIVector(x: 0, y: 0), "inputPoint1": CIVector(x: 0, y: height),
            "inputColor0": CIColor(red: 0.02, green: 0.02, blue: 0.02, colorSpace: Self.linear)!,
            "inputColor1": CIColor(red: 1, green: 1, blue: 1, colorSpace: Self.linear)!
        ])!.outputImage!
        let leaves = CIFilter(name: "CIRadialGradient", parameters: [
            "inputCenter": CIVector(x: width * 0.3, y: height * 0.6), "inputRadius0": height * 0.1, "inputRadius1": height * 0.3,
            "inputColor0": CIColor(red: 0.1, green: 0.6, blue: 0.15, colorSpace: Self.linear)!,
            "inputColor1": CIColor(red: 0.1, green: 0.6, blue: 0.15, alpha: 0, colorSpace: Self.linear)!
        ])!.outputImage!
        return leaves.composited(over: hues.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: ramp]))
            .cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
    }

    private static func checkerboard(side: CGFloat, square: CGFloat) -> CIImage {
        CIFilter(name: "CICheckerboardGenerator", parameters: [
            "inputCenter": CIVector(x: 0, y: 0), "inputWidth": square, "inputSharpness": 1,
            "inputColor0": CIColor(red: 0.6, green: 0.6, blue: 0.6, colorSpace: Self.linear)!,
            "inputColor1": CIColor(red: 0.05, green: 0.05, blue: 0.05, colorSpace: Self.linear)!
        ])!.outputImage!.cropped(to: CGRect(x: 0, y: 0, width: side, height: side))
    }

    private func render(_ scene: CIImage, camera: CameraID, filmStock: FilmStock?, version: String = NativePhotoRenderer.treatmentVersion,
                        seed: UInt64 = 7, flashFired: Bool = false) throws -> DecodedPixels {
        try pixels(DevelopedTreatment(version: version, camera: camera, filmStock: filmStock, seed: seed,
                                      flashFired: flashFired).apply(to: scene))
    }

    private func render(_ scene: CIImage, treatment: FilmLook.Treatment, seed: UInt64 = 7) throws -> DecodedPixels {
        try pixels(DevelopedTreatment(treatment, seed: seed).apply(to: scene))
    }

    private func pixels(_ image: CIImage) throws -> DecodedPixels {
        let width = Int(image.extent.width), height = Int(image.extent.height)
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        // Rows from the top, as a decoded photo's are.
        CIContext().render(image.transformed(by: CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -image.extent.height)),
                           toBitmap: &bytes, rowBytes: width * 4, bounds: CGRect(x: 0, y: 0, width: width, height: height),
                           format: .RGBA8, colorSpace: Self.sRGB)
        return DecodedPixels(width: width, height: height, bytes: bytes)
    }

    private func writeJPEG(_ image: CIImage, to url: URL, flash: Int) throws {
        let cgImage = try XCTUnwrap(CIContext().createCGImage(image, from: image.extent, format: .RGBA8, colorSpace: Self.sRGB))
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, cgImage, [kCGImagePropertyExifDictionary: [kCGImagePropertyExifFlash: flash]] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }

    private func chroma(_ color: FilmLook.RGB) -> Double {
        max(color.red, color.green, color.blue) - min(color.red, color.green, color.blue)
    }

    /// The distance between two colors' hues, in degrees.
    private func hueDistance(_ first: FilmLook.RGB, _ second: FilmLook.RGB) -> Double {
        func hue(_ color: FilmLook.RGB) -> Double {
            atan2(sqrt(3) * (color.green - color.blue), 2 * color.red - color.green - color.blue) * 180 / .pi
        }
        let difference = abs(hue(first) - hue(second))
        return min(difference, 360 - difference)
    }
}

extension DecodedPixels {
    private func luminance(at index: Int) -> Double {
        0.2126 * Double(bytes[index]) + 0.7152 * Double(bytes[index + 1]) + 0.0722 * Double(bytes[index + 2])
    }

    func meanLuminance(x: Range<Int>, y: Range<Int>) -> Double {
        var total = 0.0
        for row in y { for column in x { total += luminance(at: (row * width + column) * 4) } }
        return total / Double(x.count * y.count)
    }

    func meanColor(x: Range<Int>, y: Range<Int>) -> (red: Double, green: Double, blue: Double) {
        var sums = [0.0, 0.0, 0.0]
        for row in y { for column in x { for channel in 0..<3 { sums[channel] += Double(bytes[(row * width + column) * 4 + channel]) } } }
        let count = Double(x.count * y.count)
        return (sums[0] / count, sums[1] / count, sums[2] / count)
    }

    /// The mean absolute difference over red, green and blue from a picture of the same size, in 8-bit levels.
    func meanColorDifference(from other: DecodedPixels) -> Double {
        precondition(width == other.width && height == other.height)
        var total = 0.0
        for index in stride(from: 0, to: bytes.count, by: 4) {
            for channel in 0..<3 { total += abs(Double(bytes[index + channel]) - Double(other.bytes[index + channel])) }
        }
        return total / Double(width * height * 3)
    }

    /// The mean squared difference between horizontally neighboring pixels' luminance: how sharp edges are. Blurring
    /// an edge spreads its step over more pixels, which lowers this even where the step's size is unchanged.
    func edgeSharpness(x: Range<Int>, y: Range<Int>) -> Double {
        var total = 0.0
        for row in y { for column in x.dropLast() {
            let step = luminance(at: (row * width + column) * 4) - luminance(at: (row * width + column + 1) * 4)
            total += step * step
        } }
        return total / Double((x.count - 1) * y.count)
    }

    func darkPixels(below level: UInt8) -> Int {
        stride(from: 0, to: bytes.count, by: 4).filter { bytes[$0 + 1] < level }.count
    }

    /// Dark pixels more than `margin` of the picture's width and height in from every edge.
    func darkPixelsAwayFromEdges(below level: UInt8, margin: Double) -> Int {
        let insetX = Int(Double(width) * margin), insetY = Int(Double(height) * margin)
        var count = 0
        for row in insetY..<(height - insetY) { for column in insetX..<(width - insetX) where bytes[(row * width + column) * 4 + 1] < level {
            count += 1
        } }
        return count
    }

    /// The vertical shift, in whole pixels, that best lines this picture's middle up with another's.
    func verticalOffset(from other: DecodedPixels, searching range: Int) -> Int {
        bestOffset(against: other, searching: range) { shift, column, row in (row + shift, column) }
    }

    func horizontalOffset(from other: DecodedPixels, searching range: Int) -> Int {
        bestOffset(against: other, searching: range) { shift, column, row in (row, column + shift) }
    }

    private func bestOffset(against other: DecodedPixels, searching range: Int, _ move: (Int, Int, Int) -> (Int, Int)) -> Int {
        var best = (shift: 0, error: Double.infinity)
        for shift in -range...range {
            var error = 0.0
            for row in stride(from: height / 4, to: height * 3 / 4, by: 2) {
                for column in stride(from: width / 4, to: width * 3 / 4, by: 2) {
                    let (movedRow, movedColumn) = move(shift, column, row)
                    error += abs(luminance(at: (movedRow * width + movedColumn) * 4) - other.luminance(at: (row * width + column) * 4))
                }
            }
            if error < best.error { best = (shift, error) }
        }
        return best.shift
    }
}
