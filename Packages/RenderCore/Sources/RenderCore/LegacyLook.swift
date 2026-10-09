import CoreImage
import FilmDomain
import Foundation

/// Treatment versions 1 and 2, the provisional shared look every Camera developed with before each Camera had its own
/// (PRD 2.1 slice 4). Frozen: a capture assigned either version renders exactly as it did when it was assigned, so a
/// Film loaded before the change keeps the look it started with (ADR 0013, RK-11). `LegacyLookTests` holds these
/// renders to the ones the version 2 build made. Version 1 has no black-and-white treatment; its Films were all loaded
/// before Film Stock existed and render as version 2's color.
enum LegacyLook {
    /// A color treatment, applied over the capture's color.
    struct Color {
        let contrast: Double
        let saturation: Double
        /// Grain composited over the picture, 0 to 255.
        let grainAlpha: UInt8
    }

    /// A black-and-white treatment: one silver layer exposed by the capture's light, printed through a characteristic
    /// curve with silver grain. It never starts from the color look, so nothing of that look's color balance, contrast
    /// or grain carries into it.
    struct Monochrome {
        /// How strongly the film records red, green and blue light, in linear light; they sum to 1. A panchromatic
        /// film is more sensitive to blue than the eye is.
        let spectral: (red: Double, green: Double, blue: Double)
        /// The print's tone curve over display tones, from black to white: a deeper toe, a steeper middle and a
        /// brighter shoulder than the identity give high contrast.
        let curve: [CGPoint]
        /// Grain strength around mid-gray, 0 to 127. It is blended so it shows most in the middle tones and leaves
        /// pure black and white clean, as silver grain does.
        let grainAmplitude: UInt8
        /// The size of a grain clump, in pixels of the developed picture.
        let grainSize: Double
    }

    enum Treatment {
        case color(Color)
        case monochrome(Monochrome)
    }

    /// The treatment a capture develops with: one per Camera, and one per Film Stock on the Cameras that offer one.
    static func treatment(camera: CameraID, filmStock: FilmStock?) -> Treatment {
        switch (camera, filmStock) {
        case (.disposable1990s, _): .color(Color(contrast: 1.12, saturation: 0.88, grainAlpha: 22))
        case (.instant1970s, _): .color(Color(contrast: 0.88, saturation: 0.78, grainAlpha: 16))
        case (.mediumFormat6x6, .blackAndWhite):
            .monochrome(Monochrome(spectral: (0.30, 0.55, 0.15),
                                   curve: curve(toe: (0.25, 0.10), shoulder: (0.75, 0.91)),
                                   grainAmplitude: 46, grainSize: 2))
        case (.mediumFormat6x6, _): .color(Color(contrast: 1.04, saturation: 0.95, grainAlpha: 10))
        case (.super8HomeMovie, _): .color(Color(contrast: 1.15, saturation: 0.82, grainAlpha: 30))
        case (.cinema16mm, .blackAndWhite):
            .monochrome(Monochrome(spectral: (0.29, 0.56, 0.15),
                                   curve: curve(toe: (0.25, 0.12), shoulder: (0.75, 0.89)),
                                   grainAmplitude: 40, grainSize: 1.5))
        case (.cinema16mm, _): .color(Color(contrast: 1.08, saturation: 0.92, grainAlpha: 15))
        }
    }

    private static func curve(toe: (Double, Double), shoulder: (Double, Double)) -> [CGPoint] {
        [CGPoint(x: 0, y: 0), CGPoint(x: toe.0, y: toe.1), CGPoint(x: 0.5, y: 0.5),
         CGPoint(x: shoulder.0, y: shoulder.1), CGPoint(x: 1, y: 1)]
    }

    static func apply(to source: CIImage, camera: CameraID, filmStock: FilmStock?, seed: UInt64, frame: Int = 0) throws -> CIImage {
        var image: CIImage
        switch treatment(camera: camera, filmStock: filmStock) {
        case let .color(look): image = color(source, look, seed: seed, frame: frame)
        case let .monochrome(look): image = monochrome(source, look, seed: seed, frame: frame)
        }
        if camera == .super8HomeMovie {
            let ev = Double((seed &+ UInt64(frame) &* 17) % 13) / 100 - 0.06
            image = image.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: ev])
        }
        return image.applyingFilter("CIVignette", parameters: [kCIInputIntensityKey: 0.22, kCIInputRadiusKey: 1.5])
            .cropped(to: source.extent)
    }

    private static func color(_ source: CIImage, _ look: Color, seed: UInt64, frame: Int) -> CIImage {
        let image = source.applyingFilter("CIColorControls", parameters: [
            kCIInputContrastKey: look.contrast, kCIInputSaturationKey: look.saturation
        ]).applyingFilter("CITemperatureAndTint", parameters: [
            "inputNeutral": CIVector(x: 6500, y: 0), "inputTargetNeutral": CIVector(x: 6100, y: 4)
        ])
        let grain = noise(seed: seed, frame: frame, colorSpace: CGColorSpaceCreateDeviceRGB()) { value in
            let level = UInt8(UInt64(value) * UInt64(look.grainAlpha) / 255)
            return (level, look.grainAlpha)
        }.applyingFilter("CIAffineTile").cropped(to: source.extent)
        return grain.composited(over: image)
    }

    static func monochrome(_ source: CIImage, _ look: Monochrome, seed: UInt64, frame: Int) -> CIImage {
        // Every channel carries the same exposure from here on, so the picture stays neutral gray to the last pixel.
        let layer = CIVector(x: look.spectral.red, y: look.spectral.green, z: look.spectral.blue, w: 0)
        var curve: [String: Any] = [:]
        for (index, point) in look.curve.enumerated() { curve["inputPoint\(index)"] = CIVector(cgPoint: point) }
        var image = source.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": layer, "inputGVector": layer, "inputBVector": layer
        ]).applyingFilter("CIToneCurve", parameters: curve).applyingFilter("CILinearToSRGBToneCurve")
        let amplitude = Int(look.grainAmplitude)
        let tile = noise(seed: seed, frame: frame, colorSpace: nil) { value in
            (UInt8(128 + (Int(value) - 128) * amplitude / 128), 255)
        }
        let size = tile.extent.width * look.grainSize
        let grain = tile.samplingLinear().clampedToExtent()
            .transformed(by: CGAffineTransform(scaleX: look.grainSize, y: look.grainSize))
            .cropped(to: CGRect(x: 0, y: 0, width: size, height: size))
            .applyingFilter("CIAffineTile").cropped(to: source.extent)
        image = grain.applyingFilter("CISoftLightBlendMode", parameters: [kCIInputBackgroundImageKey: image])
        return image.applyingFilter("CISRGBToneCurveToLinear")
    }

    /// A 128 x 128 tile of gray noise from the capture's seed and the Movie frame, each pixel's level and alpha made
    /// from one random byte. A nil color space leaves the levels as they are, so level 128 stays 0.5.
    private static func noise(seed: UInt64, frame: Int, colorSpace: CGColorSpace?,
                              _ pixel: (UInt8) -> (level: UInt8, alpha: UInt8)) -> CIImage {
        var random = seed &+ UInt64(frame) &* 0x9e3779b97f4a7c15
        var bytes = [UInt8](repeating: 0, count: 128 * 128 * 4)
        for index in stride(from: 0, to: bytes.count, by: 4) {
            random = random &* 6364136223846793005 &+ 1442695040888963407
            let (level, alpha) = pixel(UInt8((random >> 32) & 255))
            bytes[index] = level; bytes[index + 1] = level; bytes[index + 2] = level; bytes[index + 3] = alpha
        }
        return CIImage(bitmapData: Data(bytes), bytesPerRow: 128 * 4, size: CGSize(width: 128, height: 128),
                       format: .RGBA8, colorSpace: colorSpace)
    }
}
