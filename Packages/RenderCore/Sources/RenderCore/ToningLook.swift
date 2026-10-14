import CoreImage
import Foundation

/// The Darkroom's chemical toners, in one place (PRD 2.1 FR-07, DEC-11). They tone the silver gelatin print of a
/// black-and-white Film and nothing else (`PhotoPrintProcess.supportsChemicalToning`).
///
/// A recipe's `ChemicalToning.amount` is where the Darkroom's slider stands, from 0 at its low end to 1 at its top,
/// and the print is toned at that strength. A strength of 1 is the toner as the toning comparison board of
/// 2026-10-13 showed it at 1.00, and 0 leaves the print untoned.
///
/// DEC-11 status: the captain chose both ranges on that board on 2026-10-13, in his words "sepia - untoned to 1.
/// selenium - untoned to 1": each slider starts at the untoned print and tops out at a strength of 1. The board also
/// showed selenium at two, three and four times that, and he kept 1. Change a range only on his word.
enum ToningLook {
    /// How much selenium changes each channel's light at a strength of 1: red and blue up and green down, which is
    /// purple. The change is weighted to the darker tones and is nothing at the paper's white.
    static let seleniumTint = FilmLook.RGB(1.04, 0.94, 1.02)

    /// The print toned as the recipe asks.
    static func apply(_ toning: ChemicalToning, to image: CIImage) -> CIImage {
        toned(image, with: toning.chemistry, strength: toning.amount)
    }

    /// The print toned at a strength.
    static func toned(_ image: CIImage, with chemistry: ChemicalToning.Chemistry, strength: Double) -> CIImage {
        switch chemistry {
        case .sepia:
            // A warm brown through every tone, strongest in the middle tones, with the paper's white turned faintly
            // cream: Core Image's sepia, with its intensity always given and never left to the filter's default.
            return image.applyingFilter("CISepiaTone", parameters: [kCIInputIntensityKey: strength])
        case .selenium:
            // A slight cool purple in the shadows and middle tones that leaves the paper's white alone. A tinted copy
            // of the print is blended in through the inverted print at the strength, so each channel's light x
            // becomes x * (1 + strength * (1 - x) * (tint - 1)): the tint in full at black, none of it at white. It
            // is the earlier build's own filter chain, kept so a recipe it saved prints the same bytes.
            let tinted = image.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: seleniumTint.red, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: seleniumTint.green, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: seleniumTint.blue, w: 0)
            ])
            let shadows = image.applyingFilter("CIColorInvert").applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: strength, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: strength, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: strength, w: 0)
            ])
            return tinted.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: image, kCIInputMaskImageKey: shadows
            ])
        }
    }
}
