import FilmDomain
import Foundation

public struct DarkroomRecipe: Codable, Equatable, Sendable {
    public var printExposureStops: Double
    public var contrastGrade: Int?
    public var colorFiltration: ColorFiltration?
    public var crop: Crop?
    public var rotationQuarterTurns: Int?
    public var straighteningDegrees: Double?
    public var saturation: Int?
    public var vignetteStops: Double?
    public var dodgeBurnMasks: [LocalMask]
    public var chemicalToning: ChemicalToning?

    public init(
        printExposureStops: Double = 0,
        contrastGrade: Int? = nil,
        colorFiltration: ColorFiltration? = nil,
        crop: Crop? = nil,
        rotationQuarterTurns: Int? = nil,
        straighteningDegrees: Double? = nil,
        saturation: Int? = nil,
        vignetteStops: Double? = nil,
        dodgeBurnMasks: [LocalMask] = [],
        chemicalToning: ChemicalToning? = nil
    ) {
        self.printExposureStops = printExposureStops
        self.contrastGrade = contrastGrade
        self.colorFiltration = colorFiltration
        self.crop = crop
        self.rotationQuarterTurns = rotationQuarterTurns
        self.straighteningDegrees = straighteningDegrees
        self.saturation = saturation
        self.vignetteStops = vignetteStops
        self.dodgeBurnMasks = dodgeBurnMasks
        self.chemicalToning = chemicalToning
    }

    public static let original = DarkroomRecipe()

    public mutating func resetToOriginal() {
        self = .original
    }

    /// Turns the print a quarter turn counterclockwise. A crop, placed on the print as it was turned, turns with it, so
    /// it frames the same part of the picture: its top edge becomes its left edge.
    public mutating func rotateLeft() {
        let turns = ((rotationQuarterTurns ?? 0) + 1) % DarkroomLimits.rotationQuarterTurnCount
        rotationQuarterTurns = turns == 0 ? nil : turns
        crop = crop.map { Crop(x: $0.y, y: Self.turned($0.x, extent: $0.width), width: $0.height, height: $0.width) }
    }

    /// Turns the print a quarter turn clockwise, its crop with it: the crop's top edge becomes its right edge.
    public mutating func rotateRight() {
        let turns = ((rotationQuarterTurns ?? 0) + DarkroomLimits.rotationQuarterTurnCount - 1)
            % DarkroomLimits.rotationQuarterTurnCount
        rotationQuarterTurns = turns == 0 ? nil : turns
        crop = crop.map { Crop(x: Self.turned($0.y, extent: $0.height), y: $0.x, width: $0.height, height: $0.width) }
    }

    /// A crop edge after a turn, `1 - edge - extent` rid of its floating-point remainder, so four turns give back the
    /// recipe they began with, and never past `1 - extent`, so the turned crop stays inside the print.
    private static func turned(_ edge: Double, extent: Double) -> Double {
        min(((1 - edge - extent) * 1e12).rounded() / 1e12, 1 - extent)
    }
}

/// The print a straightening leaves (FR-31 item 3): the largest rectangle of the print's own shape, centered, whose
/// corners all stay inside the print turned by the straightening angle, less a two pixel sampling margin at each side.
/// The renderer crops to it, and the Darkroom shows the same crop-in on its preview while the slider moves.
public enum StraighteningGeometry {
    /// How much of the print's width the largest same-shape rectangle keeps at `degrees`: 1 at 0°.
    public static func keptFraction(width: Double, height: Double, degrees: Double) -> Double {
        let radians = degrees * .pi / 180
        let ratio = width / height
        let cosine = abs(cos(radians)), sine = abs(sin(radians))
        return min(1 / (cosine + sine / ratio), (height / width) / (sine + cosine / ratio))
    }

    /// The straightened print's size in whole pixels, in the print's own shape.
    public static func croppedSize(width: Double, height: Double, degrees: Double) -> (width: Int, height: Int) {
        let largest = width * keptFraction(width: width, height: height, degrees: degrees)
        let outputWidth = max(1, Int((largest - 4).rounded(.down)))
        return (outputWidth, max(1, Int((Double(outputWidth) / (width / height)).rounded(.down))))
    }
}

/// The Darkroom's limits, the captain's of 2026-10-13 (DEC-11): the one place the validator, the renderer and the
/// Darkroom's controls read them from. A recipe outside them is invalid and is never clamped into them.
public enum DarkroomLimits {
    /// Print exposure, in stops.
    public static let printExposureStops = -3.0...3.0
    /// The step the print exposure and Dodge/Burn strength controls move in, in stops.
    public static let exposureStep = 0.1
    public static let contrastGrades = 0...5
    /// Cyan, magenta and yellow filtration, set in whole units.
    public static let colorFiltration = -30.0...30.0
    /// User crop rotation, counterclockwise quarter turns from the developed print's original orientation.
    public static let rotationQuarterTurns = 0...3
    /// Number of quarter turns available to a print.
    public static let rotationQuarterTurnCount = rotationQuarterTurns.upperBound + 1
    /// Straightening rotation in degrees, in tenths. Instant prints turn only as a whole card.
    public static let straighteningDegrees = -45.0...45.0
    public static let straighteningStep = 0.1
    /// Color saturation as a percentage from the developed print's neutral value.
    public static let saturation = -50...50
    public static let saturationStep = 1
    /// Vignette exposure adjustment at the corners, in stops, in tenths.
    public static let vignetteStops = -2.0...2.0
    public static let vignetteStep = 0.1
    /// The most Dodge/Burn lightens or darkens any part of a print, in stops: the limit of one stroke's
    /// `LocalMask.exposureStops`, and of every stroke together where they overlap.
    public static let localExposureStops = 3.0
    /// The strength the Darkroom gives a stroke until the user chooses another, in stops.
    public static let defaultStrokeStops = 0.4
}

/// How a Photo Film's prints are made, which decides the Darkroom's medium-specific controls (PRD 2.1 FR-07): color
/// prints take filtration, silver gelatin prints from a black-and-white Film take chemical toning, and both take
/// contrast grades.
public enum PhotoPrintProcess: String, Codable, Sendable {
    case color
    case silverGelatin

    /// The process a Film's Film Stock makes: silver gelatin for black-and-white, color for everything else,
    /// including a Film without a Film Stock.
    public init(filmStock: FilmStock?) {
        self = filmStock == .blackAndWhite ? .silverGelatin : .color
    }

    public var supportsChemicalToning: Bool { self == .silverGelatin }
}

extension Film {
    /// The print process this Film's Film Stock fixed at Load Film. Development and the Darkroom both follow it, so
    /// nothing else can switch a Film between color and black-and-white.
    public var printProcess: PhotoPrintProcess { PhotoPrintProcess(filmStock: filmStock) }
}

public struct ChemicalToning: Codable, Equatable, Sendable {
    public enum Chemistry: String, Codable, CaseIterable, Sendable {
        case sepia, selenium
    }
    public var chemistry: Chemistry
    public var amount: Double

    public init(chemistry: Chemistry, amount: Double) {
        self.chemistry = chemistry
        self.amount = amount
    }
}

public struct ColorFiltration: Codable, Equatable, Sendable {
    public var cyan: Double
    public var magenta: Double
    public var yellow: Double

    public init(cyan: Double = 0, magenta: Double = 0, yellow: Double = 0) {
        self.cyan = cyan
        self.magenta = magenta
        self.yellow = yellow
    }
}

public struct Crop: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct LocalMask: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case dodge
        case burn
    }

    public var kind: Kind
    public var points: [MaskPoint]
    public var exposureStops: Double

    public init(kind: Kind, points: [MaskPoint], exposureStops: Double) {
        self.kind = kind
        self.points = points
        self.exposureStops = exposureStops
    }
}

public struct MaskPoint: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}
