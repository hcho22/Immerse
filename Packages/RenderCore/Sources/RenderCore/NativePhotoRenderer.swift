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
}

/// Versioned engineering preset. DEC-04/DEC-11 visual and output approval remains open.
public enum NativePhotoRenderer {
    public static let treatmentVersion = "film-look-1-provisional"

    public static func develop(source: URL, camera: CameraPackage, seed: UInt64, process: PhotoPrintProcess = .color) throws -> Data {
        guard camera.medium == .photo else { throw NativeRenderError.wrongMedium }
        guard var image = CIImage(contentsOf: source, options: [.applyOrientationProperty: true]),
              !image.extent.isEmpty else { throw NativeRenderError.unreadableSource }
        image = normalize(image)
        if camera.id == .instant1970s || camera.id == .mediumFormat6x6 {
            let side = min(image.extent.width, image.extent.height)
            image = normalize(image.cropped(to: CGRect(
                x: (image.extent.width - side) / 2, y: (image.extent.height - side) / 2, width: side, height: side
            )))
            let target: CGFloat = camera.id == .instant1970s ? 2048 : 3072
            image = image.transformed(by: CGAffineTransform(scaleX: target / side, y: target / side))
        } else {
            let scale = min(1, sqrt(12_000_000 / (image.extent.width * image.extent.height)))
            image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }
        image = try FilmLook.apply(to: image, camera: camera.id, seed: seed)
        if process == .silverGelatin {
            image = image.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
        }
        return try jpeg(image)
    }

    public static func print(master: Data, recipe: DarkroomRecipe, camera: CameraPackage, process: PhotoPrintProcess = .color) throws -> Data {
        guard camera.medium == .photo else { throw NativeRenderError.wrongMedium }
        try validate(recipe, camera: camera, process: process)
        // Reset is byte-exact: never re-encode the original master.
        if recipe == .original { return master }
        guard var image = CIImage(data: master, options: [.applyOrientationProperty: true]) else {
            throw NativeRenderError.unreadableSource
        }
        image = normalize(image).applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: recipe.printExposureStops])
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
        return try jpeg(image)
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

enum FilmLook {
    static func apply(to source: CIImage, camera: CameraID, seed: UInt64, frame: Int = 0) throws -> CIImage {
        let contrast: Double
        let saturation: Double
        let grainAlpha: UInt8
        switch camera {
        case .disposable1990s: (contrast, saturation, grainAlpha) = (1.12, 0.88, 22)
        case .instant1970s: (contrast, saturation, grainAlpha) = (0.88, 0.78, 16)
        case .mediumFormat6x6: (contrast, saturation, grainAlpha) = (1.04, 0.95, 10)
        case .super8HomeMovie: (contrast, saturation, grainAlpha) = (1.15, 0.82, 30)
        case .cinema16mm: (contrast, saturation, grainAlpha) = (1.08, 0.92, 15)
        }
        var image = source.applyingFilter("CIColorControls", parameters: [
            kCIInputContrastKey: contrast, kCIInputSaturationKey: saturation
        ]).applyingFilter("CITemperatureAndTint", parameters: [
            "inputNeutral": CIVector(x: 6500, y: 0), "inputTargetNeutral": CIVector(x: 6100, y: 4)
        ])
        var random = seed &+ UInt64(frame) &* 0x9e3779b97f4a7c15
        var bytes = [UInt8](repeating: 0, count: 128 * 128 * 4)
        for index in stride(from: 0, to: bytes.count, by: 4) {
            random = random &* 6364136223846793005 &+ 1442695040888963407
            let value = UInt8(((random >> 32) & 255) * UInt64(grainAlpha) / 255)
            bytes[index] = value; bytes[index + 1] = value; bytes[index + 2] = value; bytes[index + 3] = grainAlpha
        }
        let grain = CIImage(bitmapData: Data(bytes), bytesPerRow: 128 * 4, size: CGSize(width: 128, height: 128),
                            format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
            .applyingFilter("CIAffineTile")
            .cropped(to: source.extent)
        image = grain.composited(over: image)
        if camera == .super8HomeMovie {
            let ev = Double((seed &+ UInt64(frame) &* 17) % 13) / 100 - 0.06
            image = image.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: ev])
        }
        return image.applyingFilter("CIVignette", parameters: [kCIInputIntensityKey: 0.22, kCIInputRadiusKey: 1.5])
            .cropped(to: source.extent)
    }
}
