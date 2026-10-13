import CoreGraphics
import CoreImage
import FilmDomain
import Foundation

/// Development through a negative emulsion (`FilmLook.NegativeFilm`), which works on the scene's light rather than on
/// display tones. The order is the captain's: his reference for the 16mm's per-frame passes
/// (`Probes/FilmLookCalibration/16mm/effects_16mm_reference.py`) and sections 2 and 5 of his spec for the 6×6
/// (`Probes/FilmLookCalibration/6x6`), which name the same steps and leave out the ones a Camera does not have:
///
///     the picture, with a fixed-balance film's light restored
///       -> scene light       (the phone's compressed highlights opened again, on the capture's own primaries)
///       -> halation          (before anything blurs)
///       -> soft edges, darkened edges
///       -> overall softness
///       -> Apple Log tones on Rec.2020 primaries
///       -> grain             (in Apple Log units, new on every frame and every photograph)
///       -> the film          (its table, read tetrahedrally: `TableReading`)
///       -> weave             (drawn from a slightly enlarged picture, so no edge shows)
///
/// Lengths scale with the frame's long edge, the gate's width however the Camera was held, which is the reference's
/// frame width for a landscape frame.
extension DevelopedTreatment {
    func developInSceneLight(_ source: CIImage, film: FilmLook.NegativeFilm, passes: FilmLook.ScenePasses?,
                             frame: Int, frameRate: Int) throws -> CIImage {
        let extent = source.extent
        let width = Double(max(extent.width, extent.height))
        var image = source

        // A stock with a fixed balance records the light's own color, which the phone's white balance had taken out.
        if let balance = film.fixedBalance, let light = sceneWhiteBalance {
            image = Self.fixBalance(image, film: balance, light: light)
        }
        switch passes?.capture ?? .rec709 {
        case .rec709:
            image = SceneLight.curve(image, SceneLight.opened, upTo: 1)
        case .displayP3:
            // A photograph is opened on Display P3's primaries, then carried to Rec.2020, as the spec's input path
            // has it; the passes below work on the same light on Rec.709 primaries, which changes none of them.
            let opened = SceneLight.curve(SceneLight.matrix(image, SceneLight.displayP3FromRec709), SceneLight.opened, upTo: 1)
            image = SceneLight.onRec709(SceneLight.matrix(opened, SceneLight.rec2020FromDisplayP3))
        }

        if let halation = passes?.halation { image = Self.glow(image, halation, width: width) }
        if let edges = passes?.softEdges {
            let soft = image.clampedToExtent().applyingGaussianBlur(sigma: edges.blur * width).cropped(to: extent)
            image = soft.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: image,
                kCIInputMaskImageKey: Self.radialStep(extent, from: edges.start, to: edges.end)
            ])
        }
        if let vignette = passes?.vignette {
            let fall = Self.radialStep(extent, from: vignette.start, to: vignette.end)
                .applyingFilter("CIGammaAdjust", parameters: ["inputPower": vignette.power])
                .applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: -vignette.amount, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: -vignette.amount, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: -vignette.amount, w: 0),
                    "inputBiasVector": CIVector(x: 1, y: 1, z: 1, w: 0)
                ])
            image = Self.multiply(image, by: fall)
        }
        if let softness = passes?.softness, softness > 0 {
            image = image.clampedToExtent().applyingGaussianBlur(sigma: softness * width).cropped(to: extent)
        }

        image = SceneLight.curve(SceneLight.onRec2020(image), SceneLight.appleLog, upTo: SceneLight.appleLogRange)
        if let passes, let grain = passes.grain {
            image = grained(image, grain, width: width, referenceWidth: passes.referenceWidth, frame: frame)
        }
        // The film: its table, asked in the tones the table is in and read between them tetrahedrally.
        image = image.applyingFilter("CIColorClamp")
        if film.table == .function {
            // Back from Apple Log to the scene's light on Rec.709 primaries, then the table's own tones.
            image = SceneLight.curve(image, SceneLight.appleLogDecoded, upTo: 1)
            image = SceneLight.curve(SceneLight.onRec709(image), SceneLight.cubeTone, upTo: FilmLook.NegativeFilm.cubeBrightest)
        }
        let table = NegativeCubes.shared.table(for: film)
        image = try TableReading.read(image, table: table.image, side: table.side)

        // The table gives display tones; the weave resamples those, as the reference does, before Core Image is
        // handed them back as light.
        if let passes, let weave = passes.weave {
            image = woven(image, weave, width: width, referenceWidth: passes.referenceWidth, frame: frame, frameRate: frameRate)
        }
        return image.applyingFilter("CISRGBToneCurveToLinear").cropped(to: extent)
    }

    // MARK: - Passes

    /// The glow of the scene's light above the threshold, spread near and far, tinted and added back.
    static func glow(_ image: CIImage, _ halation: FilmLook.ScenePasses.Halation, width: Double) -> CIImage {
        let extent = image.extent
        let weights = CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0)
        let over = image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": weights, "inputGVector": weights, "inputBVector": weights,
            "inputBiasVector": CIVector(x: -halation.threshold, y: -halation.threshold, z: -halation.threshold, w: 0)
        ]).applyingFilter("CIColorClamp", parameters: [
            "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0), "inputMaxComponents": CIVector(x: 1000, y: 1000, z: 1000, w: 1)
        ])
        func spread(_ radius: Double, _ tint: FilmLook.RGB, _ share: Double) -> CIImage {
            let gain = halation.strength * share
            return over.clampedToExtent().applyingGaussianBlur(sigma: radius * width).cropped(to: extent)
                .applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: tint.red * gain, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: tint.green * gain, y: 0, z: 0, w: 0),
                    "inputBVector": CIVector(x: tint.blue * gain, y: 0, z: 0, w: 0)
                ])
        }
        return added(spread(halation.far, halation.farTint, 0.6), to: added(spread(halation.near, halation.nearTint, 0.4), to: image))
    }

    /// The film's grain for one frame, added to Apple Log tones. Its strength per pixel is given at the reference
    /// width and scales with the frame's, since a wider frame gives each pixel less of the film.
    func grained(_ image: CIImage, _ grain: FilmLook.ScenePasses.Grain, width: Double, referenceWidth: Double,
                 frame: Int) -> CIImage {
        let extent = image.extent
        let field = GrainField.shared.tile(size: grain.size * width, grain: grain, index: Int(random(frame, salt: 70) * Double(GrainField.count)))
        let side = Double(GrainField.side)
        let offset = CGPoint(x: random(frame, salt: 71) * side, y: random(frame, salt: 72) * side)
        let amount = grain.strength * width / referenceWidth
        let noise = GrainField.tiled(field, movedBy: offset).cropped(to: extent)
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: grain.deviation.red * amount, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: grain.deviation.green * amount, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: grain.deviation.blue * amount, w: 0)
            ])
        return Self.added(noise, to: image)
    }

    /// The gate's weave for one frame: the clip's slow sway, this frame's small jump and turn.
    private func woven(_ image: CIImage, _ weave: FilmLook.ScenePasses.Weave, width: Double, referenceWidth: Double,
                       frame: Int, frameRate: Int) -> CIImage {
        let time = frameRate > 0 ? Double(frame) / Double(frameRate) : 0
        // The sway's phases belong to the clip, so the weave is continuous from frame to frame.
        let across = (0..<weave.frequencies.count).map { 2 * Double.pi * random(0, salt: 80 + UInt64($0)) }
        let down = (0..<weave.frequencies.count).map { 2 * Double.pi * random(0, salt: 84 + UInt64($0)) }
        let sway = FilmLook.ScenePasses.Weave.sway(weave, time: time, width: width, phases: (across, down))
        let jump = weave.jitter * width / referenceWidth
        return Self.woven(image, dx: sway.dx + jump * normal(frame, salt: 88), dy: sway.dy + jump * normal(frame, salt: 90),
                          degrees: weave.rotation * random(frame, salt: 92, signed: true), overscale: weave.overscale)
    }

    /// The picture drawn from a copy enlarged by `overscale` about its center, turned by `degrees` and moved by
    /// (`dx`, `dy`) pixels, `dy` counted down the frame; beyond the picture its edge repeats.
    static func woven(_ image: CIImage, dx: Double, dy: Double, degrees: Double, overscale: Double) -> CIImage {
        let extent = image.extent
        let transform = CGAffineTransform(translationX: -extent.midX + dx, y: -extent.midY - dy)
            .concatenating(CGAffineTransform(rotationAngle: degrees * .pi / 180))
            .concatenating(CGAffineTransform(scaleX: overscale, y: overscale))
            .concatenating(CGAffineTransform(translationX: extent.midX, y: extent.midY))
        return image.samplingLinear().clampedToExtent().transformed(by: transform).cropped(to: extent)
    }

    /// A deterministic draw from the standard normal distribution for this capture, a frame and a purpose.
    private func normal(_ frame: Int, salt: UInt64) -> Double {
        let first = max(random(frame, salt: salt), 1e-12), second = random(frame, salt: salt + 1)
        return (-2 * log(first)).squareRoot() * cos(2 * .pi * second)
    }

    // MARK: - Building blocks

    /// The sum of two opaque images, value for value, with nothing held to a ceiling: scene light runs past 1 and
    /// grain goes below 0.
    static func added(_ light: CIImage, to image: CIImage) -> CIImage {
        light.applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: image])
            .settingAlphaOne(in: image.extent).cropped(to: image.extent)
    }

    /// A gray image that rises smoothly from 0 at `start` to 1 at `end`, as distances from the center where the
    /// corner is 1 and each axis is measured against its own half of the frame.
    static func radialStep(_ extent: CGRect, from start: Double, to end: Double) -> CIImage {
        let halfWidth = (extent.width - 1) / 2, halfHeight = (extent.height - 1) / 2
        let corner = 2.0.squareRoot() * halfWidth
        let squash = CGAffineTransform(translationX: -extent.midX, y: -extent.midY)
            .concatenating(CGAffineTransform(scaleX: 1, y: halfHeight / halfWidth))
            .concatenating(CGAffineTransform(translationX: extent.midX, y: extent.midY))
        let ramp = CIFilter(name: "CIRadialGradient", parameters: [
            "inputCenter": CIVector(x: extent.midX, y: extent.midY),
            "inputRadius0": start * corner, "inputRadius1": end * corner,
            "inputColor0": gray(0), "inputColor1": gray(1)
        ])!.outputImage!.transformed(by: squash).cropped(to: extent)
        // The smooth step 3t^2 - 2t^3 of the gradient's straight ramp.
        let step = CIVector(x: 0, y: 0, z: 3, w: -2)
        return ramp.applyingFilter("CIColorPolynomial", parameters: [
            "inputRedCoefficients": step, "inputGreenCoefficients": step, "inputBlueCoefficients": step,
            "inputAlphaCoefficients": CIVector(x: 0, y: 1, z: 0, w: 0)
        ])
    }
}

extension FilmLook.ScenePasses.Weave {
    /// The slow sway at `time` seconds into a clip, in pixels for a frame `width` wide: on each axis the mean of the
    /// sines at `frequencies`, each with the phase the clip gave it.
    static func sway(_ weave: Self, time: Double, width: Double, phases: (across: [Double], down: [Double])) -> (dx: Double, dy: Double) {
        func mean(_ phases: [Double]) -> Double {
            zip(weave.frequencies, phases).reduce(0) { $0 + sin(2 * .pi * $1.0 * time + $1.1) } / Double(weave.frequencies.count)
        }
        return (mean(phases.across) * weave.across * width, mean(phases.down) * weave.down * width)
    }
}

/// The two curves that carry a picture into the film's terms, as tables for Core Image, and the matrix between them.
enum SceneLight {
    static let workingSpace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!

    /// Display light to scene light: the phone's compressed highlights opened again (`NegativeFilm.sceneLight`).
    static let opened = table(upTo: 1, FilmLook.NegativeFilm.sceneLight(displayLight:))

    /// Scene light to Apple Log tones, up to well past the brightest light a glow can add.
    static let appleLogRange = 8.0
    static let appleLog = table(upTo: appleLogRange, FilmLook.NegativeFilm.appleLogEncoded)

    /// Linear Rec.709 to linear Display P3 and linear Display P3 to linear Rec.2020, row by row, from the three
    /// standards' primaries and their shared white (D65).
    static let displayP3FromRec709: [[Double]] = [
        [0.82246197, 0.17753803, 0], [0.03319420, 0.96680580, 0], [0.01708263, 0.07239744, 0.91051993]
    ]
    static let rec2020FromDisplayP3: [[Double]] = [
        [0.75383303, 0.19859737, 0.04756960], [0.04574385, 0.94177722, 0.01247893], [-0.00121034, 0.01760172, 0.98360862]
    ]

    /// Linear Rec.709 to linear Rec.2020, row by row: the inverse of the matrix the film uses to come back.
    static let rec2020 = FilmLook.NegativeFilm.inverse([[1.6605, -0.5876, -0.0728], [-0.1246, 1.1329, -0.0083], [-0.0182, -0.1006, 1.1187]])

    /// Apple Log tones back to scene light, and scene light to the film's cube tones (`NegativeFilm.cubeTone`).
    static let appleLogDecoded = table(upTo: 1, FilmLook.NegativeFilm.appleLogDecoded)
    static let cubeTone = table(upTo: FilmLook.NegativeFilm.cubeBrightest, FilmLook.NegativeFilm.cubeTone(sceneLight:))

    /// The picture's scene light from Rec.2020 primaries back on Rec.709's.
    static func onRec709(_ image: CIImage) -> CIImage {
        image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 1.6605, y: -0.5876, z: -0.0728, w: 0),
            "inputGVector": CIVector(x: -0.1246, y: 1.1329, z: -0.0083, w: 0),
            "inputBVector": CIVector(x: -0.0182, y: -0.1006, z: 1.1187, w: 0)
        ])
    }

    /// The picture's scene light on Rec.2020 primaries.
    static func onRec2020(_ image: CIImage) -> CIImage { matrix(image, rec2020) }

    /// The picture's light through a matrix given row by row.
    static func matrix(_ image: CIImage, _ rows: [[Double]]) -> CIImage {
        func row(_ index: Int) -> CIVector { CIVector(x: rows[index][0], y: rows[index][1], z: rows[index][2], w: 0) }
        return image.applyingFilter("CIColorMatrix", parameters: ["inputRVector": row(0), "inputGVector": row(1), "inputBVector": row(2)])
    }

    static func curve(_ image: CIImage, _ table: Data, upTo limit: Double) -> CIImage {
        image.applyingFilter("CIColorCurves", parameters: [
            "inputCurvesData": table, "inputCurvesDomain": CIVector(x: 0, y: limit), "inputColorSpace": workingSpace
        ])
    }

    /// The samples in each curve's table. Core Image takes no more than a renderer's widest texture: the iOS
    /// simulator's renders nothing at all for a table of 16,384, where a Mac's renders it. 4,096 is within every
    /// renderer's reach, and leaves each curve within 0.0005 of itself between its samples.
    static let curveSamples = 4096

    private static func table(upTo limit: Double, _ curve: (Double) -> Double) -> Data {
        let count = curveSamples
        var values = [Float]()
        values.reserveCapacity(count * 3)
        for index in 0..<count {
            let value = Float(curve(Double(index) / Double(count - 1) * limit))
            values.append(contentsOf: [value, value, value])
        }
        return values.withUnsafeBufferPointer { Data(buffer: $0) }
    }
}
