import CoreImage
import FilmDomain
import Foundation
import ImageIO

public enum NativeRenderError: Error, Equatable {
    case unreadableSource
    case wrongMedium
    case invalidRecipe
    case renderFailed
    /// A movie that cannot be developed or assembled. Where AVFoundation could not read a clip, `underlying` is the error
    /// it gave, for diagnosis: the failure text a person sees is the same either way.
    case invalidMovie(underlying: NSError? = nil)
    case writerFailed
    case writerTimedOut
    /// An Instant master that is not the card-sized print every developed Instant exposure is.
    case instantMasterWithoutCard
    /// A treatment version this build cannot render, assigned by a later build.
    case unrenderableTreatment
    /// A film's table cannot be read here: Core Image could not make or run the tetrahedral reader, the only way the
    /// color Film Stocks of the 16mm Cinema and the 6×6 Medium Format develop.
    case tableReaderUnavailable
}

/// The sizes developed photographs are made and saved to Photos at, the captain's of 2026-10-13 (DEC-04). They are
/// JPEG in sRGB. An Instant print is saved exactly as it was developed, at its card's size (`InstantPrintCard`), with
/// no resampling.
public enum DevelopedPhotoSize {
    /// The most pixels a Disposable's borderless 3:2 picture has.
    public static let disposableMaximumPixels = 12_000_000
    /// The side of a 6×6 Medium Format picture, in pixels.
    public static let mediumFormatSide = 3072
}

/// Develops and prints photographs with each Camera's Developed Treatment, in the sizes of `DevelopedPhotoSize` and
/// within the Darkroom's limits, `DarkroomLimits`.
public enum NativePhotoRenderer {
    /// The treatment version Development assigns to a Film loaded today: each Camera's and Film Stock's own look
    /// (`FilmLook`). A Film records its version in the Camera package it locked at Load Film.
    public static let treatmentVersion = CameraCatalog.treatmentVersion

    /// The version a Film whose locked package records none develops with: such a Film was loaded before packages
    /// recorded one, when Development assigned version 2. Version 1, which some of those Films' captures carry,
    /// renders version 2's color exactly.
    public static let lockedBeforeVersionsTreatmentVersion = TreatmentVersion.two.rawValue

    /// Every treatment version this build renders. A capture keeps the version it was assigned, so a Film that was
    /// unfinished or developing when the app was updated still finishes with the look it started with (CAM-01, RK-11).
    public static let renderableTreatmentVersions = Set(TreatmentVersion.allCases.map(\.rawValue))

    /// Whether this renderer can read a film's table, which the color Film Stocks of the 16mm Cinema and the 6×6
    /// Medium Format develop through. Where it cannot, a renderer without Metal, developing one of them throws
    /// `NativeRenderError.tableReaderUnavailable`. A miss is not remembered: each asking makes and proves the reader
    /// again until one has proved itself.
    public static var readsFilmTables: Bool { TableReading.shared.kernel != nil }

    /// The developed master of one capture: the Camera's picture shape and its treatment, in the capture's assigned
    /// treatment version, for the Film's Film Stock. A nil Film Stock, a Camera without one or a Film loaded before
    /// Film Stock existed, develops as color.
    public static func develop(source: URL, camera: CameraPackage, seed: UInt64, filmStock: FilmStock? = nil,
                               treatmentVersion: String = treatmentVersion) throws -> Data {
        guard camera.medium == .photo else { throw NativeRenderError.wrongMedium }
        guard var image = CIImage(contentsOf: source, options: [.applyOrientationProperty: true]),
              !image.extent.isEmpty else { throw NativeRenderError.unreadableSource }
        let treatment = try DevelopedTreatment(version: treatmentVersion, camera: camera.id, filmStock: filmStock, seed: seed,
                                               flashFired: flashFired(image.properties))
        image = normalize(image)
        if camera.id == .instant1970s || camera.id == .mediumFormat6x6 {
            let side = min(image.extent.width, image.extent.height)
            image = normalize(image.cropped(to: CGRect(
                x: (image.extent.width - side) / 2, y: (image.extent.height - side) / 2, width: side, height: side
            )))
            let target = CGFloat(camera.id == .instant1970s ? InstantPrintCard.pictureSide : DevelopedPhotoSize.mediumFormatSide)
            image = image.transformed(by: CGAffineTransform(scaleX: target / side, y: target / side))
        } else {
            if camera.id == .disposable1990s { image = cropToThreeByTwo(image) }
            let width = image.extent.width, height = image.extent.height
            let scale = sqrt(CGFloat(DevelopedPhotoSize.disposableMaximumPixels) / (width * height))
            // A larger capture is brought down to whole pixels, so the picture never passes the limit by the pixel a
            // fractional size rounds out to.
            if scale < 1 {
                image = image.transformed(by: CGAffineTransform(scaleX: (width * scale).rounded(.down) / width,
                                                                y: (height * scale).rounded(.down) / height))
            }
        }
        image = try treatment.apply(to: image)
        // The card is part of the developed master, so every view and export of the print includes it.
        if camera.id == .instant1970s { image = InstantPrintCard.mount(image) }
        return try jpeg(image)
    }

    /// Whether the capture's flash fired, from its Exif Flash value, whose lowest bit records it.
    static func flashFired(_ properties: [String: Any]) -> Bool {
        let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any]
        return ((exif?[kCGImagePropertyExifFlash as String] as? Int) ?? 0) & 1 == 1
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
        // Every Basic Edit reaches the picture only, except Adjust's quarter turns, which turn the whole card. The card is
        // unexposed paper, so print exposure, contrast, filtration, saturation, vignette and saved Dodge/Burn strokes leave
        // it white, and stroke points are fractions of the picture.
        let isInstant = camera.id == .instant1970s
        if isInstant { image = InstantPrintCard.picture(of: image) }
        image = try adjust(image, recipe: recipe, camera: camera)
        if isInstant {
            image = InstantPrintCard.mount(image)
            if let turns = recipe.rotationQuarterTurns, turns != 0 {
                image = rotateQuarterTurns(image, turns: turns)
            }
        }
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

    private static func adjust(_ source: CIImage, recipe: DarkroomRecipe, camera: CameraPackage) throws -> CIImage {
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
        if let saturation = recipe.saturation {
            image = image.applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 1 + Double(saturation) / 100
            ])
        }
        // Strokes add up where they overlap, each working on the print as the last left it, and together they never
        // take any part of it more than the limit from its print exposure. Unbounded, a few overlapping strokes at the
        // limit run past what the renderer can hold and print as rings, not as white or black. Dodges only lighten and
        // burns only darken, so where the dodges together and the burns together stay within the limit nothing can pass
        // it, and the print is made without the bound, exactly as the build before made it: on Apple silicon the bound's
        // filters change the printed bytes even where they hold nothing back.
        let limit = DarkroomLimits.localExposureStops
        let canPassTheLimit = [LocalMask.Kind.dodge, .burn].contains { kind in
            recipe.dodgeBurnMasks.filter { $0.kind == kind }.reduce(0) { $0 + abs($1.exposureStops) } > limit
        }
        let lightest = image.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: limit])
        let darkest = image.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: -limit])
        // A value contrast pushed below zero grows more negative as it is lightened, so order the two bounds by value.
        let ceiling = lightest.applyingFilter("CIMaximumCompositing", parameters: [kCIInputBackgroundImageKey: darkest])
        let floor = lightest.applyingFilter("CIMinimumCompositing", parameters: [kCIInputBackgroundImageKey: darkest])
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
            if canPassTheLimit {
                image = image.applyingFilter("CIMinimumCompositing", parameters: [kCIInputBackgroundImageKey: ceiling])
                    .applyingFilter("CIMaximumCompositing", parameters: [kCIInputBackgroundImageKey: floor])
            }
        }
        // A vignette is exposure at the corners, so a print with one is toned after it, as burned paper is toned; a print
        // without one is toned here, where a recipe saved before the vignette was toned.
        let vignette = recipe.vignetteStops.flatMap { $0 == 0 ? nil : $0 }
        if vignette == nil, let toning = recipe.chemicalToning { image = ToningLook.apply(toning, to: image) }
        // The crop is placed on the print as it is turned, so Horizontal moves it across the turned print as it shows.
        // A recipe saved before quarter turns has none, so its crop prints as it did.
        if camera.id != .instant1970s, let turns = recipe.rotationQuarterTurns, turns != 0 {
            image = rotateQuarterTurns(image, turns: turns)
        }
        if let crop = recipe.crop {
            let size = image.extent.size
            var area = CGRect(
                x: crop.x * size.width, y: (1 - crop.y - crop.height) * size.height,
                width: crop.width * size.width, height: crop.height * size.height
            ).integral
            // Each side is rounded out to whole pixels on its own, which can leave one a pixel longer than the other.
            // The 6×6 stays square: its longer side gives that pixel up at the right or the bottom, so the crop keeps
            // the top left corner it is placed by.
            if camera.id == .mediumFormat6x6 {
                area = area.intersection(image.extent)
                let side = min(area.width, area.height)
                area = CGRect(x: area.minX, y: area.maxY - side, width: side, height: side)
            }
            image = normalize(image.cropped(to: area))
        }
        if camera.id != .instant1970s, let degrees = recipe.straighteningDegrees, degrees != 0 {
            image = try straighten(image, degrees: degrees)
        }
        if let vignette {
            image = applyVignette(vignette, to: image)
            if let toning = recipe.chemicalToning { image = ToningLook.apply(toning, to: image) }
        }
        return image
    }

    private static func rotateQuarterTurns(_ image: CIImage, turns: Int) -> CIImage {
        let quarter = ((turns % DarkroomLimits.rotationQuarterTurnCount) + DarkroomLimits.rotationQuarterTurnCount)
            % DarkroomLimits.rotationQuarterTurnCount
        guard quarter != 0 else { return image }
        let cosine: CGFloat = quarter == 2 ? -1 : 0
        let sine: CGFloat = quarter == 1 ? 1 : (quarter == 3 ? -1 : 0)
        let center = CGPoint(x: image.extent.midX, y: image.extent.midY)
        let transform = CGAffineTransform(
            a: cosine, b: sine, c: -sine, d: cosine,
            tx: center.x - cosine * center.x + sine * center.y,
            ty: center.y - sine * center.x - cosine * center.y
        )
        return normalize(image.transformed(by: transform))
    }

    /// Rotates a print and crops the largest centered rectangle at its existing aspect ratio, keeping every corner
    /// inside the rotated source (`StraighteningGeometry`). The same-ratio rectangle keeps a 6×6 print square. The print
    /// stays in extended linear floating point, as in every other step, so light above white survives to the vignette
    /// and the final encode.
    private static func straighten(_ image: CIImage, degrees: Double) throws -> CIImage {
        let radians = CGFloat(degrees * .pi / 180)
        guard let space = CGColorSpace(name: CGColorSpace.extendedLinearSRGB),
              let source = straighteningContext.createCGImage(image, from: image.extent, format: .RGBAf, colorSpace: space)
        else { throw NativeRenderError.renderFailed }
        let sourceWidth = CGFloat(source.width), sourceHeight = CGFloat(source.height)
        let output = StraighteningGeometry.croppedSize(width: Double(source.width), height: Double(source.height),
                                                       degrees: degrees)
        let outputWidth = output.width, outputHeight = output.height
        let floats = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.floatComponents.rawValue
            | CGBitmapInfo.byteOrder32Little.rawValue
        guard let context = CGContext(data: nil, width: outputWidth, height: outputHeight, bitsPerComponent: 32,
                                      bytesPerRow: outputWidth * 16, space: space, bitmapInfo: floats) else {
            throw NativeRenderError.renderFailed
        }
        context.interpolationQuality = .high
        context.translateBy(x: CGFloat(outputWidth) / 2, y: CGFloat(outputHeight) / 2)
        context.rotate(by: radians)
        context.translateBy(x: -sourceWidth / 2, y: -sourceHeight / 2)
        context.draw(source, in: CGRect(x: 0, y: 0, width: sourceWidth, height: sourceHeight))
        guard let straightened = context.makeImage() else { throw NativeRenderError.renderFailed }
        return CIImage(cgImage: straightened)
    }

    /// Core Image's context for straightening, made once: a context is safe to share.
    nonisolated(unsafe) private static let straighteningContext = CIContext(options: [.cacheIntermediates: false])

    /// Applies a smooth radial exposure change that reaches the requested stop value at each print corner.
    private static func applyVignette(_ stops: Double, to image: CIImage) -> CIImage {
        let extent = image.extent
        let cornerRadius = hypot(extent.width / 2, extent.height / 2)
        let transitionStart = cornerRadius * 0.2
        let mask = CIFilter(name: "CIRadialGradient", parameters: [
            "inputCenter": CIVector(x: extent.midX, y: extent.midY),
            "inputRadius0": transitionStart,
            "inputRadius1": cornerRadius,
            "inputColor0": CIColor.black,
            "inputColor1": CIColor.white
        ])!.outputImage!.cropped(to: extent)
        let adjusted = image.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: -stops])
        return adjusted.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: image,
            kCIInputMaskImageKey: mask
        ]).cropped(to: extent)
    }

    public static func validate(_ recipe: DarkroomRecipe, camera: CameraPackage, process: PhotoPrintProcess = .color) throws {
        guard recipe.printExposureStops.isFinite, DarkroomLimits.printExposureStops.contains(recipe.printExposureStops),
              recipe.contrastGrade.map({ DarkroomLimits.contrastGrades.contains($0) }) ?? true else {
            throw NativeRenderError.invalidRecipe
        }
        if let color = recipe.colorFiltration {
            guard process == .color,
                  [color.cyan, color.magenta, color.yellow].allSatisfy({ $0.isFinite && DarkroomLimits.colorFiltration.contains($0) }) else {
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
        if let turns = recipe.rotationQuarterTurns {
            guard DarkroomLimits.rotationQuarterTurns.contains(turns) else { throw NativeRenderError.invalidRecipe }
        }
        if let degrees = recipe.straighteningDegrees {
            guard camera.id != .instant1970s, degrees.isFinite,
                  DarkroomLimits.straighteningDegrees.contains(degrees),
                  isOnStep(degrees, step: DarkroomLimits.straighteningStep) else {
                throw NativeRenderError.invalidRecipe
            }
        }
        if let saturation = recipe.saturation {
            guard process == .color, DarkroomLimits.saturation.contains(saturation) else {
                throw NativeRenderError.invalidRecipe
            }
        }
        if let vignette = recipe.vignetteStops {
            guard vignette.isFinite, DarkroomLimits.vignetteStops.contains(vignette),
                  isOnStep(vignette, step: DarkroomLimits.vignetteStep) else {
                throw NativeRenderError.invalidRecipe
            }
        }
        guard recipe.dodgeBurnMasks.allSatisfy({ mask in
            mask.exposureStops.isFinite && abs(mask.exposureStops) <= DarkroomLimits.localExposureStops &&
            mask.points.allSatisfy { $0.x.isFinite && $0.y.isFinite && (0...1).contains($0.x) && (0...1).contains($0.y) }
        }) else { throw NativeRenderError.invalidRecipe }
    }

    private static func isOnStep(_ value: Double, step: Double) -> Bool {
        let steps = value / step
        return abs(steps - steps.rounded()) < 0.000001
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

/// The white card of a developed 1970s Instant print (PRD 2.1 FR-07, ADR 0013), 2282 x 2774 pixels, which is also the
/// size the print is saved to Photos at (DEC-04, the captain, 2026-10-13).
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
