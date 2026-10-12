import CoreGraphics
import FilmDomain
import Foundation

/// A treatment version this build renders. A capture keeps the version it was assigned, so a Film develops with the
/// treatments it started with after an update changes a Camera's look (ADR 0013, CAM-01, RK-11). A version that
/// changes any look is a new case here and a new table; an earlier version's values never change.
enum TreatmentVersion: String, CaseIterable {
    /// The provisional shared look (`LegacyLook`).
    case one = "film-look-1-provisional"
    /// Version 1 plus a black-and-white treatment for the 6×6 Medium Format and the 16mm Cinema (`LegacyLook`).
    case two = "film-look-2-provisional"
    /// Each Camera's and Film Stock's own look, judged against its Format Reference (`FilmLook`).
    case three = "film-look-3"
}

/// Treatment version 3: every Camera's and Film Stock's Developed Treatment, in one place (PRD 2.1 sections 6.1 to
/// 6.3; ADRs 0013 to 0016).
///
/// Each look reproduces its Format Reference as it performed when new: nothing fades, yellows, shifts in dye or wears,
/// and every imperfection is one the format made at capture or processing (ADR 0013). The exceptions are the looks
/// `isCaptainsException` names, each given by the captain's own choice (ADR 0016). A
/// Format Reference's name is internal and stays in these comments; no product string carries it (ADR 0015). Spatial
/// values are fractions of the developed picture's long edge, so a look is the same at any size.
///
/// DEC-04 status: every value below is provisional until the captain approves that Camera's review board (QA-16); the
/// Instant's print-to-print variation stays provisional after that, pending a study of preserved 1970s prints.
enum FilmLook {
    /// The looks that depart from ADR 0013's fresh rule, each by the captain's own choice (ADR 0016): the Instant is
    /// faded, the Super 8 is muted with a highlight glow, and the color Film Stocks of the 16mm and the 6×6 are the
    /// looks he asked to have applied from his own files. The 16mm's whites sit a little under the rule's and its
    /// greens, cyans and purples are muted; the 6×6's blacks are lifted and its whites sit under the rule's. Every
    /// other Camera and Film Stock stays under ADR 0013.
    static func isCaptainsException(camera: CameraID, filmStock: FilmStock?) -> Bool {
        switch camera {
        case .instant1970s, .super8HomeMovie: true
        case .cinema16mm, .mediumFormat6x6: filmStock != .blackAndWhite
        default: false
        }
    }

    /// The treatment a capture develops with: one per Camera, and one per Film Stock on the Cameras that offer one. A
    /// Film loaded before Film Stock existed has none and develops in color.
    static func treatment(camera: CameraID, filmStock: FilmStock?) -> Treatment {
        switch (camera, filmStock) {
        case (.disposable1990s, _): disposable
        case (.instant1970s, _): instant
        case (.mediumFormat6x6, .blackAndWhite): mediumFormatBlackAndWhite
        case (.mediumFormat6x6, _): mediumFormatColor
        case (.super8HomeMovie, _): super8
        case (.cinema16mm, .blackAndWhite): cinemaBlackAndWhite
        case (.cinema16mm, _): cinemaColor
        }
    }

    /// 1990s Disposable. Format Reference: the Kodak Fun Saver single-use camera with flash and 800-speed color
    /// negative film, printed by a minilab. Warm, saturated color with heavy grain that grows in an underexposed dim
    /// scene, a plastic lens's soft, darker corners, and harsh direct flash that lights the subject flat and lets the
    /// background fall away. No light leaks, red-eye, dust or scratches (PRD 2.1 section 6.1).
    static let disposable = Treatment(
        emulsion: .color(ColorEmulsion(
            warmth: 0.055, layers: Layers(greenFromBlue: -0.05), saturation: 1.1,
            tone: ToneCurve(contrast: 1.1, midtones: 0.88, black: 0.015, white: 0.99),
            shadows: RGB(-0.004, 0.008, 0.004), highlights: RGB(0.004, 0.003, -0.006),
            grain: Grain(amplitude: 8, size: 0.0009, chroma: 0.3, shadows: 0.6)
        )),
        lens: Lens(edgeSoftness: 0.0012, edgeDarkening: 0.6),
        flash: Flash(falloff: 0.9, contrast: 0.1)
    )

    /// 1970s Instant. Format Reference: the original 1970s integral print. By the captain's choice on its review board
    /// on 2026-10-10 ("faded"), it develops as surviving prints look, not as fresh ones did (ADR 0016, an exception to
    /// ADR 0013 and to PRD 2.1 section 6.1's "brilliant, warm, saturated color"): lifted, milky blacks, softened
    /// whites, low contrast, muted color with aqua blues and olive greens, blue in the shadows and yellow in the
    /// highlights, soft detail and a coarse texture. Each print still differs slightly in color and density, with no
    /// uneven-chemistry or spread flaws; the size of that variation waits on a study of preserved 1970s prints (DEC-04).
    static let instant = Treatment(
        emulsion: .color(ColorEmulsion(
            warmth: 0.09, tint: -0.005, layers: Layers(redFromGreen: 0.12, greenFromBlue: 0.15, blueFromGreen: 0.15),
            saturation: 0.85,
            tone: ToneCurve(contrast: 0.82, midtones: 0.88, black: 0.13, white: 0.9),
            shadows: RGB(0, 0.008, 0.03), highlights: RGB(0.012, 0.004, -0.03),
            grain: Grain(amplitude: 4.5, size: 0.0014, chroma: 0.3)
        )),
        lens: Lens(softness: 0.0011, edgeSoftness: 0.001, edgeDarkening: 0.4),
        printVariation: PrintVariation(density: 0.12, warmth: 0.025, tint: 0.01)
    )

    /// 6×6 Medium Format, color Film Stock. Format Reference: a Hasselblad 500C with its 80mm lens and Kodak Portra
    /// 400, scanned as a modern lab scans the negative. This is the look the captain asked to have applied on
    /// 2026-10-12: every constant here is his generator's "scan" look and section 5 of his spec
    /// (`Probes/FilmLookCalibration/6x6`), which `NegativeFilmTests` and `ScenePassesTests` hold this to, and the
    /// picture is read from his own table of 33 tones a side. The negative's layer contrasts come from the
    /// manufacturer's curve as digitized in spectral_film_lut; the rest was fitted to that simulation and then
    /// finished by hand. Gentle contrast with slightly lifted, very slightly cool blacks, highlights that keep detail
    /// five stops over gray, cream-warm grays, quiet reds, pastel blues leaning to cyan and softer greens. Very fine
    /// grain and a mild lens vignette; no softening, halation, weave, flicker, dust or hair, and focus is optical
    /// only, so nothing blurs the background (PRD 2.1 sections 6.1 and FR-04).
    static let mediumFormatColor = Treatment(
        emulsion: .negative(NegativeFilm(
            negativeGamma: RGB(0.556, 0.550, 0.641),
            exposure: 0.25,
            balance: RGB(1.025, 1.000, 0.955),
            toe: -1.08,
            crosstalk: [RGB(1.1919, -0.2500, 0.0581), RGB(0.1446, 0.6054, 0.2500), RGB(0.0511, -0.0468, 0.9957)],
            output: .scan,
            slope: RGB(3.90, 3.98, 3.31),
            grayDensity: 0.80,
            black: RGB(0.0015, 0.0015, 0.0017),
            bands: [
                NegativeFilm.Band(-3.29, 0.378, -0.018), NegativeFilm.Band(-2.41, -0.152, 0.009),
                NegativeFilm.Band(4.97, -0.136, 0.012), NegativeFilm.Band(7.37, 0.289, 0.073),
                NegativeFilm.Band(-3.30, 0.304, 0.008), NegativeFilm.Band(-7.28, -0.054, 0.017),
                NegativeFilm.Band(-4.49, -0.153, 0.023)
            ],
            finish: [
                NegativeFilm.Band(3.0, -0.280, 0), NegativeFilm.Band(0, 0.080, 0.030), NegativeFilm.Band(0, 0, 0),
                NegativeFilm.Band(-8.0, -0.220, 0.060), NegativeFilm.Band(0, -0.250, 0), NegativeFilm.Band(0, -0.030, 0.030),
                NegativeFilm.Band(0, 0, 0)
            ],
            highlightDesaturation: 0.25, shadowDesaturation: 0.15,
            table: .appleLog(side: 33)
        )),
        lens: Lens(),
        scene: ScenePasses(
            referenceWidth: 3024,
            capture: .displayP3,
            vignette: ScenePasses.Vignette(amount: 0.18, start: 0.30, end: 1.0, power: 1.6),
            grain: ScenePasses.Grain(deviation: RGB(0.0011, 0.0014, 0.0025), strength: 1.5, size: 0.00027,
                                     secondOctaveSize: 2.5, secondOctaveWeight: 0.25, shared: 0.7)
        )
    )

    /// 6×6 Medium Format, black-and-white Film Stock. Format Reference: the same camera with Kodak Tri-X 400. High
    /// contrast with distinct grain, from a panchromatic silver layer (PRD 2.1 section 6.1).
    static let mediumFormatBlackAndWhite = Treatment(
        emulsion: .monochrome(MonochromeEmulsion(
            spectral: RGB(0.30, 0.55, 0.15),
            tone: ToneCurve(contrast: 1.5, midtones: 0.86, shoulder: 0.05, black: 0.004, white: 0.985),
            grain: Grain(amplitude: 8, size: 0.0008)
        )),
        lens: Lens(softness: 0.0003, edgeDarkening: 0.2)
    )

    /// 1960s Super 8 Home Movie. Format Reference: the Kodak Instamatic M4 with Kodachrome II at 18 frames per second,
    /// projected. By the captain's choice on its review board on 2026-10-10 ("muted with a glow"), its color is not
    /// PRD 2.1 section 6.2's "strong, rich color" (ADR 0016): lower contrast, slightly desaturated color, darker
    /// shadows, lowered whites, teal in the shadows and warmth in the highlights, a soft picture, and a warm
    /// reddish-orange glow around bright highlights. Its fine grain, unsteady frame, brightness flicker, and dust and
    /// hair in the gate are as the PRD sets them; scratches and other wear are not added.
    static let super8 = Treatment(
        emulsion: .color(ColorEmulsion(
            warmth: 0.05, saturation: 0.9,
            tone: ToneCurve(contrast: 1.0, midtones: 1.08, white: 0.93),
            shadows: RGB(-0.006, 0.01, 0.012), highlights: RGB(0.014, 0.006, -0.012),
            grain: Grain(amplitude: 3.5, size: 0.0012, chroma: 0.25)
        )),
        halation: Halation(threshold: 0.75, radius: 0.01, strength: 0.3, color: RGB(1, 0.35, 0.1)),
        lens: Lens(softness: 0.0016, edgeSoftness: 0.0015, edgeDarkening: 0.45),
        gate: Gate(jitter: 0.0035, weave: 0.002, weavePeriod: 1.7, flicker: 0.06, dust: 0.6, hair: 0.5)
    )

    /// 16mm Cinema, color Film Stock. Format Reference: the Bolex H16 Reflex with Kodak Vision3 250D, printed to Kodak
    /// Vision 2383 and shown as a print. This is the look the captain asked to have applied on 2026-10-12: every
    /// constant here is his generator's "print" look and his reference for the per-frame passes
    /// (`Probes/FilmLookCalibration/16mm`), which `NegativeFilmTests` and `ScenePassesTests` hold this to. The
    /// negative's layer contrasts are the manufacturer's curves as digitized in spectral_film_lut; the rest was fitted
    /// to that simulation and then timed by hand. One constant is not his file's: with the look on its board he found
    /// the blacks too strong for color and asked for "the black up to 4 percent", so `black` is raised from his
    /// file's 0.0009, 0.0009, 0.0010 to put black at 4 percent of the tone scale, its slight cool tint kept (ADR
    /// 0016). A long soft highlight shoulder, muted cyans and purples and olive greens, daylight neutral with
    /// slightly warm highlights and cool shadows. Its daylight balance is fixed, so warm indoor light develops orange
    /// and Development does not correct it (PRD 2.1 sections 6.2 and 6.3). Visible grain, a red highlight glow (a
    /// deliberate departure: the reference film's backing prevents it), minor jitter and weave, and soft, darkened
    /// edges; no flicker, dust or hair.
    static let cinemaColor = Treatment(
        emulsion: .negative(NegativeFilm(
            negativeGamma: RGB(0.474, 0.555, 0.535),
            fixedBalance: 5500,
            toe: -7.0,
            crosstalk: [RGB(1.1452, -0.1926, 0.0474), RGB(0.0873, 0.7649, 0.1478), RGB(-0.0658, 0.0083, 1.0574)],
            output: .print(maximumDensity: 4.39),
            slope: RGB(4.64, 3.92, 3.96),
            grayDensity: 0.694,
            black: RGB(0.0030, 0.0030, 0.0033),
            bands: [
                NegativeFilm.Band(2.51, -0.009, -0.030), NegativeFilm.Band(1.45, -0.062, 0.010),
                NegativeFilm.Band(-0.80, -0.027, 0.002), NegativeFilm.Band(-2.09, -0.169, 0.005),
                NegativeFilm.Band(-2.05, -0.393, 0.025), NegativeFilm.Band(-0.55, -0.134, 0.015),
                NegativeFilm.Band(1.78, -0.463, 0.056)
            ],
            finish: [
                NegativeFilm.Band(0, 0, 0), NegativeFilm.Band(0, 0.040, 0.020), NegativeFilm.Band(0, 0, 0),
                NegativeFilm.Band(-5.0, -0.050, 0), NegativeFilm.Band(0, 0, 0), NegativeFilm.Band(0, 0, 0),
                NegativeFilm.Band(0, 0, 0)
            ],
            highlightDesaturation: 0.379, shadowDesaturation: 0
        )),
        lens: Lens(),
        scene: ScenePasses(
            referenceWidth: 1440,
            halation: ScenePasses.Halation(threshold: 1.0, near: 0.004, far: 0.015, nearTint: RGB(1.00, 0.45, 0.10),
                                           farTint: RGB(1.00, 0.12, 0.02), strength: 0.45),
            softEdges: ScenePasses.SoftEdges(blur: 0.0030, start: 0.45, end: 1.05),
            vignette: ScenePasses.Vignette(amount: 0.22, start: 0.35, end: 1.0, power: 1.5),
            softness: 0.0005,
            grain: ScenePasses.Grain(deviation: RGB(0.0028, 0.0034, 0.0062), strength: 1.5, size: 0.00042,
                                     secondOctaveSize: 2.5, secondOctaveWeight: 0.35, shared: 0.7),
            weave: ScenePasses.Weave(across: 0.0006, down: 0.0008, frequencies: [0.7, 1.9], jitter: 0.2, rotation: 0.015,
                                     overscale: 1.006)
        )
    )

    /// 16mm Cinema, black-and-white Film Stock. Format Reference: the same camera with Eastman Double-X. Visible grain,
    /// a neutral highlight glow, minor jitter and weave, and soft, darkened edges (PRD 2.1 section 6.2).
    static let cinemaBlackAndWhite = Treatment(
        emulsion: .monochrome(MonochromeEmulsion(
            spectral: RGB(0.29, 0.56, 0.15),
            tone: ToneCurve(contrast: 1.4, black: 0.01, white: 0.985),
            grain: Grain(amplitude: 5.5, size: 0.001)
        )),
        halation: Halation(threshold: 0.75, radius: 0.008, strength: 0.25, color: RGB(1, 1, 1)),
        lens: Lens(softness: 0.0004, edgeSoftness: 0.0012, edgeDarkening: 0.5),
        gate: Gate(jitter: 0.0012, weave: 0.0012, weavePeriod: 2.4)
    )
}

extension FilmLook {
    /// One Camera's, or one Film Stock's, Developed Treatment: what the film and its processing do, and what the
    /// Camera's lens, flash and gate add.
    struct Treatment: Equatable {
        var emulsion: Emulsion
        /// A glow around bright highlights, from light the base reflects back into the emulsion.
        var halation: Halation?
        var lens: Lens
        /// How direct flash develops, on an exposure the flash lit.
        var flash: Flash?
        /// How much one print differs from the next, chosen once per print from its seed.
        var printVariation: PrintVariation?
        /// A Movie Camera's frame-to-frame imperfections.
        var gate: Gate?
        /// What a Camera with a `negative` emulsion does to the picture in scene light. Such a treatment develops
        /// through these alone: its `halation`, `lens` and `gate`, which work on display tones, stay empty.
        var scene: ScenePasses?

        init(emulsion: Emulsion, halation: Halation? = nil, lens: Lens, flash: Flash? = nil,
             printVariation: PrintVariation? = nil, gate: Gate? = nil, scene: ScenePasses? = nil) {
            self.emulsion = emulsion
            self.halation = halation
            self.lens = lens
            self.flash = flash
            self.printVariation = printVariation
            self.gate = gate
            self.scene = scene
        }
    }

    enum Emulsion: Equatable {
        case color(ColorEmulsion)
        case monochrome(MonochromeEmulsion)
        /// A color negative developed from the scene's light (`NegativeFilm`); its grain is one of the `ScenePasses`.
        case negative(NegativeFilm)

        var grain: Grain {
            switch self {
            case let .color(emulsion): emulsion.grain
            case let .monochrome(emulsion): emulsion.grain
            case .negative: Grain(amplitude: 0, size: 0)
            }
        }
    }

    /// The passes a Camera with a negative emulsion makes on the scene's light, in this order: a glow around strong
    /// highlights, soft edges, darkened edges and overall softness before the film; the film's grain, added to the
    /// Apple Log tones the film is asked in; and, after the film, the gate's weave. They follow the captain's
    /// reference for the 16mm's per-frame passes. Lengths are fractions of the frame's width, and amounts given per
    /// pixel hold at `referenceWidth` and scale with the frame's width from there.
    struct ScenePasses: Equatable {
        /// A glow around strong highlights: the scene light above `threshold` (linear, middle gray 0.18), spread
        /// near and far, tinted, and added back at `strength`, two fifths from the near spread and three from the far.
        struct Halation: Equatable {
            var threshold: Double
            var near: Double
            var far: Double
            var nearTint: RGB
            var farTint: RGB
            var strength: Double
        }

        /// Softness toward the edges: the picture gives way to a copy blurred by `blur`, from nothing at `start` to
        /// all of it at `end`, as distances from the center where 1 is the corner.
        struct SoftEdges: Equatable {
            var blur: Double
            var start: Double
            var end: Double
        }

        /// Darker edges: the light falls by `amount` at `end`, from none at `start`, along a curve of `power`.
        struct Vignette: Equatable {
            var amount: Double
            var start: Double
            var end: Double
            var power: Double
        }

        /// The film's grain, new on every frame: each layer's deviation in Apple Log units per pixel, times
        /// `strength`; the size of its clumps, with a second, coarser octave of `secondOctaveSize` times that size at
        /// `secondOctaveWeight`; and the share of every layer's grain that all three have in common.
        struct Grain: Equatable {
            var deviation: RGB
            var strength: Double
            var size: Double
            var secondOctaveSize: Double
            var secondOctaveWeight: Double
            var shared: Double
        }

        /// The gate's unsteadiness: a slow sway `across` and `down` the frame, the sum of two sines at `frequencies`
        /// in hertz whose phases a clip keeps; a small jump on every frame, `jitter` pixels of deviation; a turn of
        /// up to `rotation` degrees either way; all drawn from a picture enlarged by `overscale`, so no edge shows.
        struct Weave: Equatable {
            var across: Double
            var down: Double
            var frequencies: [Double]
            var jitter: Double
            var rotation: Double
            var overscale: Double
        }

        /// The primaries the phone's picture is on when its highlights are opened: Rec.709 for a Movie clip, Display
        /// P3 for a photograph.
        enum Capture: Equatable {
            case rec709
            case displayP3
        }

        /// The frame width at which per-pixel amounts are given.
        var referenceWidth: Double
        var capture = Capture.rec709
        var halation: Halation?
        var softEdges: SoftEdges?
        var vignette: Vignette?
        /// Softness over the whole picture, as a blur radius.
        var softness: Double = 0
        var grain: Grain?
        var weave: Weave?
    }

    /// A color film and its print: color balance, color, tone and grain, applied to display tones.
    struct ColorEmulsion: Equatable {
        /// Moves the color balance warmer (positive) or cooler, as a gain on red and the opposite on blue in linear
        /// light; 0.05 is a clearly warm balance.
        var warmth: Double
        /// Moves the balance toward magenta (positive) or green, as a gain off green in linear light.
        var tint: Double = 0
        /// How much each dye layer also records, or with a negative value loses, another layer's color, in linear
        /// light: red from green turns greens toward olive, red from blue below zero turns blues toward cyan and
        /// warms skin, green from blue turns blues toward aqua, and blue from green quiets yellows or, below zero,
        /// strengthens greens. Neutral tones stay neutral.
        var layers = Layers()
        /// Color strength around each pixel's luminance in linear light; 1 keeps the capture's.
        var saturation: Double
        /// The print's characteristic curve, on each channel's display tone. A curve steeper than the identity also
        /// strengthens middle-tone color, as a print does.
        var tone: ToneCurve
        /// Color added to the deepest shadows and to the brightest highlights, as display tones.
        var shadows: RGB = .zero
        var highlights: RGB = .zero
        var grain: Grain
        /// The light color temperature, in kelvin, a stock with a fixed balance records as neutral. A Movie clip recorded
        /// in warmer light develops warm and in cooler light cool, against the light its capture recorded
        /// (`SceneWhiteBalance`); nil follows the phone's white balance.
        var fixedBalance: Double? = nil
    }

    /// A black-and-white film and its print: one silver layer exposed by the capture's light.
    struct MonochromeEmulsion: Equatable {
        /// How strongly the film records red, green and blue light, in linear light; they sum to 1.
        var spectral: RGB
        var tone: ToneCurve
        var grain: Grain
    }

    /// A print curve over display tones from black to white: an S that keeps display mid-gray where it is, or a curve
    /// drawn through given points.
    struct ToneCurve: Equatable {
        /// The curve's slope at mid-gray: 1 keeps the capture's contrast and higher values deepen shadows and brighten
        /// highlights.
        var contrast: Double
        /// A power applied to the tone before the curve: above 1 darkens the middle tones and below 1 lightens them.
        var midtones: Double = 1
        /// A curve drawn point by point, as (capture tone, print tone) pairs on the 0 to 255 scale a point curve is
        /// usually written in, from capture black (0) to capture white (255) with rising tones. When given, it
        /// replaces the S of `contrast`; `midtones`, `shoulder`, `black` and `white` still apply around it.
        var points: [CGPoint] = []
        /// A soft shoulder: how far the upper tones are pulled down, as display tone at three-quarter gray, with
        /// black and white left where they are. Negative film rolls its highlights off gently.
        var shoulder: Double = 0
        /// The display tones of the print's deepest black and brightest white.
        var black: Double = 0
        var white: Double = 1

        func callAsFunction(_ tone: Double) -> Double {
            let x = pow(min(max(tone, 0), 1), midtones)
            guard x > 0, x < 1 else { return black + (white - black) * x }
            let curved: Double
            if points.isEmpty {
                let rising = pow(x, contrast)
                curved = rising / (rising + pow(1 - x, contrast))
            } else {
                curved = min(max(Self.interpolate(points, at: x * 255) / 255, 0), 1)
            }
            // Largest at three-quarter gray, where the factor is 1, and nothing at black or white.
            let rolled = curved - shoulder * (256.0 / 27) * curved * curved * curved * (1 - curved)
            return black + (white - black) * rolled
        }

        /// The smooth curve through the points that never overshoots them or turns back (a monotone cubic).
        static func interpolate(_ points: [CGPoint], at x: Double) -> Double {
            guard points.count > 1, let first = points.first, let last = points.last else { return x }
            if x <= first.x { return first.y }
            if x >= last.x { return last.y }
            let count = points.count
            let widths = (0..<count - 1).map { points[$0 + 1].x - points[$0].x }
            let slopes = (0..<count - 1).map { (points[$0 + 1].y - points[$0].y) / widths[$0] }
            // Tangents: the harmonic mean of the neighboring slopes, flat where the slope changes sign.
            var tangents = [CGFloat](repeating: 0, count: count)
            tangents[0] = slopes[0]
            tangents[count - 1] = slopes[count - 2]
            for index in 1..<count - 1 where slopes[index - 1] * slopes[index] > 0 {
                let left = 2 * widths[index] + widths[index - 1], right = widths[index] + 2 * widths[index - 1]
                tangents[index] = (left + right) / (left / slopes[index - 1] + right / slopes[index])
            }
            let segment = (0..<count - 1).last { points[$0].x <= x } ?? 0
            let width = widths[segment], t = (x - points[segment].x) / width
            let t2 = t * t, t3 = t2 * t
            return (2 * t3 - 3 * t2 + 1) * points[segment].y + (t3 - 2 * t2 + t) * width * tangents[segment]
                + (-2 * t3 + 3 * t2) * points[segment + 1].y + (t3 - t2) * width * tangents[segment + 1]
        }
    }

    struct Grain: Equatable {
        /// Strength: the standard deviation it adds to an even mid-gray, in 8-bit display levels.
        var amplitude: Double
        /// The size of a grain clump, as a fraction of the picture's long edge; never below 1.2 pixels, the smallest
        /// clump whose strength `DevelopedTreatment.clumpedNoiseDeviation` is calibrated for.
        var size: Double
        /// 0 is gray grain, the same in every channel; 1 gives each color layer its own.
        var chroma: Double = 0
        /// Extra grain in the shadows, as a share of `amplitude`: an underexposed negative printed up shows its grain.
        var shadows: Double = 0
    }

    struct Halation: Equatable {
        /// The luminance, in linear light from 0 to 1, above which a highlight glows.
        var threshold: Double
        /// The spread of the glow, as a fraction of the picture's long edge.
        var radius: Double
        /// How much of the light above the threshold returns as glow.
        var strength: Double
        /// The glow's color: red where it reaches only the red-recording layer, white in black-and-white.
        var color: RGB
    }

    struct Lens: Equatable {
        /// Softness over the whole picture, as a blur radius in fractions of the long edge.
        var softness: Double = 0
        /// A veil of diffused light: the share of the picture replaced by a wide blur of itself, which lowers local
        /// contrast and smooths skin without losing fine detail, as negative clarity does.
        var diffusion: Double = 0
        /// Extra softness toward the corners, as the corners' blur radius in fractions of the long edge.
        var edgeSoftness: Double = 0
        /// How much darker the corners are than the center, in stops.
        var edgeDarkening: Double = 0
    }

    struct Flash: Equatable {
        /// How much darker the corners are than the center on an exposure the flash lit, in stops: the flash's narrow
        /// spread and its falloff with distance.
        var falloff: Double
        /// Extra print contrast on an exposure the flash lit.
        var contrast: Double
    }

    struct PrintVariation: Equatable {
        /// The largest change in density, in stops either way.
        var density: Double
        /// The largest change in warmth and tint either way, in the units of `ColorEmulsion`.
        var warmth: Double
        var tint: Double
    }

    struct Gate: Equatable {
        /// The largest frame-to-frame jump of the picture, as a fraction of its height.
        var jitter: Double
        /// The largest slow sideways sway, as a fraction of the picture's width, and the time it takes to sway back.
        var weave: Double
        var weavePeriod: Double
        /// The largest frame-to-frame change in brightness, in stops either way.
        var flicker: Double = 0
        /// The expected number of dust specks on a frame.
        var dust: Double = 0
        /// The chance that a clip was filmed with a hair in the gate.
        var hair: Double = 0
    }

    struct Layers: Equatable {
        var redFromGreen: Double = 0
        var redFromBlue: Double = 0
        var greenFromBlue: Double = 0
        var blueFromGreen: Double = 0
    }

    struct RGB: Equatable {
        var red: Double
        var green: Double
        var blue: Double

        init(_ red: Double, _ green: Double, _ blue: Double) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        static let zero = RGB(0, 0, 0)
    }
}
