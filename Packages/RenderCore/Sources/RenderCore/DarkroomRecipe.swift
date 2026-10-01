import Foundation

public struct DarkroomRecipe: Codable, Equatable, Sendable {
    public var printExposureStops: Double
    public var contrastGrade: Int?
    public var colorFiltration: ColorFiltration?
    public var crop: Crop?
    public var dodgeBurnMasks: [LocalMask]
    public var chemicalToning: ChemicalToning?

    public init(
        printExposureStops: Double = 0,
        contrastGrade: Int? = nil,
        colorFiltration: ColorFiltration? = nil,
        crop: Crop? = nil,
        dodgeBurnMasks: [LocalMask] = [],
        chemicalToning: ChemicalToning? = nil
    ) {
        self.printExposureStops = printExposureStops
        self.contrastGrade = contrastGrade
        self.colorFiltration = colorFiltration
        self.crop = crop
        self.dodgeBurnMasks = dodgeBurnMasks
        self.chemicalToning = chemicalToning
    }

    public static let original = DarkroomRecipe()

    public mutating func resetToOriginal() {
        self = .original
    }
}

public enum PhotoPrintProcess: String, Codable, Sendable {
    case color
    case silverGelatin

    public var supportsChemicalToning: Bool { self == .silverGelatin }
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
