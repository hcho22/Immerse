import CoreImage
import FilmDomain
import Foundation
import ImageIO

public enum NativeRenderError: Error, Equatable {
    case unreadableSource
    case wrongMedium
    case invalidRecipe
    case renderFailed
    case invalidMovie
    case writerFailed
    case writerTimedOut
    /// An Instant master that is not the card-sized print every developed Instant exposure is.
    case instantMasterWithoutCard
    /// A Film Stock the Camera does not offer (ADR 0014).
    case filmStockNotOffered
}

/// Versioned engineering preset. DEC-04/DEC-11 visual and output approval remains open.
public enum NativePhotoRenderer {
    /// The treatment version Development assigns today. Version 2 adds a black-and-white treatment for the 6×6 Medium
    /// Format and the 16mm Cinema (ADR 0014); every color treatment is version 1's, unchanged.
    public static let treatmentVersion = "film-look-2-provisional"

    /// Every treatment version this build renders. A capture keeps the version it was assigned, so a Film that was
    /// developing when the app was updated still finishes with it (CAM-01, RK-11). Version 1 Films were all loaded
    /// before Film Stock existed and develop in color, which version 2 renders identically.
    public static let renderableTreatmentVersions: Set<String> = ["film-look-1-provisional", treatmentVersion]

    /// The developed master of one capture: the Camera's picture shape and its treatment for the Film's Film Stock.
    /// A nil Film Stock, a Camera without one or a Film loaded before Film Stock existed, develops as color.
    public static func develop(source: URL, camera: CameraPackage, seed: UInt64, filmStock: FilmStock? = nil) throws -> Data {
        guard camera.medium == .photo else { throw NativeRenderError.wrongMedium }
        try FilmLook.require(filmStock, offeredBy: camera)
        guard var image = CIImage(contentsOf: source, options: [.applyOrientationProperty: true]),
              !image.extent.isEmpty else { throw NativeRenderError.unreadableSource }
        image = normalize(image)
        if camera.id == .instant1970s || camera.id == .mediumFormat6x6 {
            let side = min(image.extent.width, image.extent.height)
            image = normalize(image.cropped(to: CGRect(
                x: (image.extent.width - side) / 2, y: (image.extent.height - side) / 2, width: side, height: side
            )))
            let target = CGFloat(camera.id == .instant1970s ? InstantPrintCard.pictureSide : 3072)
            image = image.transformed(by: CGAffineTransform(scaleX: target / side, y: target / side))
        } else {
            if camera.id == .disposable1990s { image = cropToThreeByTwo(image) }
            let scale = min(1, sqrt(12_000_000 / (image.extent.width * image.extent.height)))
            image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }
        image = try FilmLook.apply(to: image, camera: camera.id, filmStock: filmStock, seed: seed)
        // The card is part of the developed master, so every view and export of the print includes it.
        if camera.id == .instant1970s { image = InstantPrintCard.mount(image) }
        return try jpeg(image)
    }

    public static func print(master: Data, recipe: DarkroomRecipe, camera: CameraPackage, process: PhotoPrintProcess = .color) throws -> Data {
        guard camera.medium == .photo else { throw NativeRenderError.wrongMedium }
        try validate(recipe, camera: camera, process: process)
        // Every developed Instant master is the card-sized print; anything else would render, or map a Dodge/Burn
        // point, without its card.
        if camera.id == .instant1970s { try requireCardSized(master) }
        // Reset is byte-exact: never re-encode the original master.
        if recipe == .original { return master }
        guard let decoded = CIImage(data: master, options: [.applyOrientationProperty: true]) else {
            throw NativeRenderError.unreadableSource
        }
        var image = normalize(decoded)
        // Adjustments reach the picture only. The card is unexposed paper, so print exposure, contrast, filtration
        // and Dodge/Burn leave it white, and Dodge/Burn points are fractions of the picture.
        let isInstant = camera.id == .instant1970s
        if isInstant { image = InstantPrintCard.picture(of: image) }
        image = adjust(image, recipe: recipe)
        if isInstant { image = InstantPrintCard.mount(image) }
        return try jpeg(image)
    }

    private static func requireCardSized(_ master: Data) throws {
        guard let source = CGImageSourceCreateWithData(master as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { throw NativeRenderError.unreadableSource }
        let rotated = ((properties[kCGImagePropertyOrientation] as? Int) ?? 1) > 4
        guard (rotated ? (height, width) : (width, height)) == (InstantPrintCard.width, InstantPrintCard.height) else {
            throw NativeRenderError.instantMasterWithoutCard
        }
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
                // Provisional shadow-biased selenium print response, not a stock certification.
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

    public static func validate(_ recipe: DarkroomRecipe, camera: CameraPackage, process: PhotoPrintProcess = .color) throws {
        guard recipe.printExposureStops.isFinite, (-2...2).contains(recipe.printExposureStops),
              recipe.contrastGrade.map({ (0...5).contains($0) }) ?? true else { throw NativeRenderError.invalidRecipe }
        if let color = recipe.colorFiltration {
            guard process == .color,
                  [color.cyan, color.magenta, color.yellow].allSatisfy({ $0.isFinite && (-30...30).contains($0) }) else {
                throw NativeRenderError.invalidRecipe
            }
        }
        if let toning = recipe.chemicalToning {
            guard process.supportsChemicalToning, toning.amount.isFinite, (0...1).contains(toning.amount) else {
                throw NativeRenderError.invalidRecipe
            }
        }
        if let crop = recipe.crop {
            // An Instant print keeps its square picture and white card whole, so it takes no crop at all.
            guard camera.id != .instant1970s else { throw NativeRenderError.invalidRecipe }
            guard [crop.x, crop.y, crop.width, crop.height].allSatisfy(\.isFinite),
                  crop.x >= 0, crop.y >= 0, crop.width > 0, crop.height > 0,
                  crop.x + crop.width <= 1, crop.y + crop.height <= 1,
                  camera.id != .mediumFormat6x6 || abs(crop.width - crop.height) < 0.00001 else {
                throw NativeRenderError.invalidRecipe
            }
        }
        guard recipe.dodgeBurnMasks.allSatisfy({ mask in
            mask.exposureStops.isFinite && abs(mask.exposureStops) <= 1 &&
            mask.points.allSatisfy { $0.x.isFinite && $0.y.isFinite && (0...1).contains($0.x) && (0...1).contains($0.y) }
        }) else { throw NativeRenderError.invalidRecipe }
    }

    /// The Disposable's borderless 3:2 picture: the phone's 4:3 capture cropped about its center, with the long
    /// side kept so a portrait capture becomes 2:3. It matches the viewfinder's fill of its 3:2 frame and adds
    /// no border and no date stamp. The 12 MP master limit applies after the crop.
    static func cropToThreeByTwo(_ image: CIImage) -> CIImage {
        let width = image.extent.width, height = image.extent.height
        let landscape = width >= height
        let long = landscape ? width : height, short = landscape ? height : width
        // A source narrower than 3:2 (the 4:3 capture) keeps its long side; a wider one keeps its short side.
        let keptLong = min(long, (short * 3 / 2).rounded(.down))
        let keptShort = (keptLong * 2 / 3).rounded(.down)
        let size = landscape ? CGSize(width: keptLong, height: keptShort) : CGSize(width: keptShort, height: keptLong)
        return normalize(image.cropped(to: CGRect(
            x: ((width - size.width) / 2).rounded(.down), y: ((height - size.height) / 2).rounded(.down),
            width: size.width, height: size.height
        )))
    }

    static func normalize(_ image: CIImage) -> CIImage {
        image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
    }

    private static func jpeg(_ image: CIImage) throws -> Data {
        let context = CIContext(options: [.cacheIntermediates: false])
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let result = context.jpegRepresentation(of: image, colorSpace: colorSpace, options: [
                kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.94
              ]) else { throw NativeRenderError.renderFailed }
        return result
    }
}

/// Every Developed Treatment and its provisional values, in one place. DEC-04 is open: tone, contrast and grain are
/// engineering placeholders that PRD 2.0 slice 4 tunes against review boards of each Format Reference (CAM-17, QA-16).
enum FilmLook {
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

    /// Rejects a Film Stock the Camera does not offer, so no other Camera reaches a black-and-white treatment.
    static func require(_ filmStock: FilmStock?, offeredBy camera: CameraPackage) throws {
        if let filmStock, !camera.filmStocks.contains(filmStock) { throw NativeRenderError.filmStockNotOffered }
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

/// The white card of a developed 1970s Instant print (PRD 2.1 FR-07, ADR 0013).
///
/// The picture stays exactly 2048 x 2048 pixels and the card is added around it, in the proportions of the Instant's
/// Format Reference, the original 1970s integral print: a 79 mm square picture on a 88 x 107 mm card, with equal
/// narrow top and side borders (4.5 mm) and a deeper bottom border (23.5 mm). The card is clean white, never aged.
public enum InstantPrintCard {
    public static let pictureSide = 2048
    /// Top, left and right border, in pixels (4.5 / 79 of the picture).
    public static let sideBorder = 117
    /// Bottom border, in pixels (23.5 / 79 of the picture).
    public static let bottomBorder = 609
    public static let width = pictureSide + 2 * sideBorder
    public static let height = pictureSide + sideBorder + bottomBorder

    /// The picture's place on the card as fractions of the card, from its top left corner.
    public static let pictureFractions = CGRect(
        x: Double(sideBorder) / Double(width), y: Double(sideBorder) / Double(height),
        width: Double(pictureSide) / Double(width), height: Double(pictureSide) / Double(height)
    )

    /// The picture inside a card-sized image, moved to the origin. Core Image's origin is the bottom left.
    static func picture(of card: CIImage) -> CIImage {
        NativePhotoRenderer.normalize(card.cropped(to: CGRect(
            x: sideBorder, y: bottomBorder, width: pictureSide, height: pictureSide
        )))
    }

    /// A 2048 x 2048 picture on the white card.
    static func mount(_ picture: CIImage) -> CIImage {
        let paper = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
        return NativePhotoRenderer.normalize(picture).transformed(
            by: CGAffineTransform(translationX: CGFloat(sideBorder), y: CGFloat(bottomBorder))
        ).composited(over: paper)
    }
}
