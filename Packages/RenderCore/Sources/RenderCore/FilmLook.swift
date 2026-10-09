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
/// 6.3; ADRs 0013 to 0015).
///
/// Each look reproduces its Format Reference as it performed when new: nothing fades, yellows, shifts in dye or wears,
/// and every imperfection is one the format made at capture or processing (ADR 0013). A Format Reference's name is
/// internal and stays in these comments; no product string carries it (ADR 0015). Spatial values are fractions of the
/// developed picture's long edge, so a look is the same at any size.
///
/// DEC-04 status: every value below is provisional until the captain approves that Camera's review board (QA-16); the
/// Instant's contrast and print-to-print variation stay provisional after that, pending a study of preserved 1970s
/// prints.
enum FilmLook {
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
            warmth: 0.05, saturation: 1.08,
            tone: ToneCurve(contrast: 1.1, midtones: 0.92, black: 0.03, white: 0.99),
            highlights: RGB(0.004, 0.003, -0.006),
            grain: Grain(amplitude: 7, size: 0.0007, chroma: 0.3, shadows: 0.6)
        )),
        lens: Lens(edgeSoftness: 0.0012, edgeDarkening: 0.6),
        flash: Flash(falloff: 0.9, contrast: 0.1)
    )

    /// 1970s Instant. Format Reference: the original 1970s integral print, fresh from the camera. Brilliant, warm,
    /// saturated color and soft detail, each print slightly different in color and density, with no uneven-chemistry
    /// or spread flaws (PRD 2.1 section 6.1). Its contrast and the size of its variation wait on a study of preserved
    /// 1970s prints (DEC-04).
    static let instant = Treatment(
        emulsion: .color(ColorEmulsion(
            warmth: 0.055, tint: 0.01, saturation: 1.22,
            tone: ToneCurve(contrast: 1.18, midtones: 0.97, black: 0.03, white: 0.98),
            shadows: RGB(0, 0.004, 0.012), highlights: RGB(0.004, 0.002, -0.006),
            grain: Grain(amplitude: 1.5, size: 0.0006, chroma: 0.2)
        )),
        lens: Lens(softness: 0.0007, edgeSoftness: 0.0008, edgeDarkening: 0.25),
        printVariation: PrintVariation(density: 0.12, warmth: 0.025, tint: 0.01)
    )

    /// 6×6 Medium Format, color Film Stock. Format Reference: a Hasselblad 500C with its 80mm lens and Kodak Portra
    /// 400. Natural, warm color, flattering skin tones, very fine grain and gentle contrast; focus is optical only, so
    /// nothing blurs the background (PRD 2.1 sections 6.1 and FR-04).
    static let mediumFormatColor = Treatment(
        emulsion: .color(ColorEmulsion(
            warmth: 0.04, saturation: 0.92,
            tone: ToneCurve(contrast: 1.04, midtones: 0.96, black: 0.02, white: 0.975),
            shadows: RGB(-0.002, 0.002, 0.004), highlights: RGB(0.008, 0.004, -0.006),
            grain: Grain(amplitude: 1.6, size: 0.0004, chroma: 0.15)
        )),
        lens: Lens(edgeDarkening: 0.2)
    )

    /// 6×6 Medium Format, black-and-white Film Stock. Format Reference: the same camera with Kodak Tri-X 400. High
    /// contrast with distinct grain, from a panchromatic silver layer (PRD 2.1 section 6.1).
    static let mediumFormatBlackAndWhite = Treatment(
        emulsion: .monochrome(MonochromeEmulsion(
            spectral: RGB(0.30, 0.55, 0.15),
            tone: ToneCurve(contrast: 1.5, black: 0.012, white: 0.985),
            grain: Grain(amplitude: 6.5, size: 0.0006)
        )),
        lens: Lens(edgeDarkening: 0.2)
    )

    /// 1960s Super 8 Home Movie. Format Reference: the Kodak Instamatic M4 with Kodachrome II at 18 frames per second,
    /// projected. Strong, rich color and fine grain, with an unsteady frame, brightness flicker, and dust and hair in
    /// the gate, each present from capture or first showing rather than from age (PRD 2.1 section 6.2).
    static let super8 = Treatment(
        emulsion: .color(ColorEmulsion(
            warmth: 0.05, saturation: 1.15,
            tone: ToneCurve(contrast: 1.3, midtones: 1.03, white: 0.99),
            shadows: RGB(0, -0.002, 0.006),
            grain: Grain(amplitude: 3, size: 0.0012, chroma: 0.25)
        )),
        lens: Lens(softness: 0.0009, edgeSoftness: 0.0015, edgeDarkening: 0.45),
        gate: Gate(jitter: 0.0035, weave: 0.002, weavePeriod: 1.7, flicker: 0.06, dust: 0.6, hair: 0.5)
    )

    /// 16mm Cinema, color Film Stock. Format Reference: the Bolex H16 Reflex with Kodak Vision3 250D. Visible grain, a
    /// red highlight glow (a deliberate departure: the reference film's backing prevents it), minor jitter and weave,
    /// and soft, darkened edges; no flicker, dust or hair. Its daylight balance is fixed, so warm indoor light develops
    /// orange and Development does not correct it (PRD 2.1 sections 6.2 and 6.3).
    static let cinemaColor = Treatment(
        emulsion: .color(ColorEmulsion(
            warmth: 0, saturation: 1.05,
            tone: ToneCurve(contrast: 1.12, black: 0.015, white: 0.98),
            grain: Grain(amplitude: 4, size: 0.0009, chroma: 0.3, shadows: 0.3),
            fixedBalance: 5500
        )),
        halation: Halation(threshold: 0.55, radius: 0.008, strength: 0.6, color: RGB(1, 0.18, 0.05)),
        lens: Lens(softness: 0.0004, edgeSoftness: 0.0012, edgeDarkening: 0.5),
        gate: Gate(jitter: 0.0012, weave: 0.0012, weavePeriod: 2.4)
    )

    /// 16mm Cinema, black-and-white Film Stock. Format Reference: the same camera with Eastman Double-X. Visible grain,
    /// a neutral highlight glow, minor jitter and weave, and soft, darkened edges (PRD 2.1 section 6.2).
    static let cinemaBlackAndWhite = Treatment(
        emulsion: .monochrome(MonochromeEmulsion(
            spectral: RGB(0.29, 0.56, 0.15),
            tone: ToneCurve(contrast: 1.4, black: 0.01, white: 0.985),
            grain: Grain(amplitude: 5.5, size: 0.001)
        )),
        halation: Halation(threshold: 0.55, radius: 0.008, strength: 0.45, color: RGB(1, 1, 1)),
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

        init(emulsion: Emulsion, halation: Halation? = nil, lens: Lens, flash: Flash? = nil,
             printVariation: PrintVariation? = nil, gate: Gate? = nil) {
            self.emulsion = emulsion
            self.halation = halation
            self.lens = lens
            self.flash = flash
            self.printVariation = printVariation
            self.gate = gate
        }
    }

    enum Emulsion: Equatable {
        case color(ColorEmulsion)
        case monochrome(MonochromeEmulsion)

        var grain: Grain {
            switch self {
            case let .color(emulsion): emulsion.grain
            case let .monochrome(emulsion): emulsion.grain
            }
        }
    }

    /// A color film and its print: color balance, color, tone and grain, applied to display tones.
    struct ColorEmulsion: Equatable {
        /// Moves the color balance warmer (positive) or cooler, as a gain on red and the opposite on blue in linear
        /// light; 0.05 is a clearly warm balance.
        var warmth: Double
        /// Moves the balance toward magenta (positive) or green, as a gain off green in linear light.
        var tint: Double = 0
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

    /// An S-shaped print curve over display tones from black to white that keeps display mid-gray where it is.
    struct ToneCurve: Equatable {
        /// The curve's slope at mid-gray: 1 keeps the capture's contrast and higher values deepen shadows and brighten
        /// highlights.
        var contrast: Double
        /// A power applied to the tone before the curve: above 1 darkens the middle tones and below 1 lightens them.
        var midtones: Double = 1
        /// The display tones of the print's deepest black and brightest white.
        var black: Double = 0
        var white: Double = 1

        func callAsFunction(_ tone: Double) -> Double {
            let x = pow(min(max(tone, 0), 1), midtones)
            guard x > 0, x < 1 else { return black + (white - black) * x }
            let rising = pow(x, contrast)
            return black + (white - black) * rising / (rising + pow(1 - x, contrast))
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
