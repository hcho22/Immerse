import Accelerate
import CoreGraphics
import CoreImage
import FilmDomain
import Foundation

/// Development through a negative emulsion (`FilmLook.NegativeFilm`), which works on the scene's light rather than on
/// display tones. The order is the captain's reference for the 16mm's per-frame passes
/// (`Probes/FilmLookCalibration/16mm/effects_16mm_reference.py`):
///
///     the picture, with a fixed-balance film's light restored
///       -> scene light       (the phone's compressed highlights opened again)
///       -> halation          (before anything blurs)
///       -> soft edges, darkened edges
///       -> overall softness
///       -> Apple Log tones on Rec.2020 primaries
///       -> grain             (in Apple Log units, new on every frame)
///       -> the film          (a color cube, asked in tones of the scene's light back on Rec.709 primaries)
///       -> weave             (drawn from a slightly enlarged picture, so no edge shows)
///
/// Lengths scale with the frame's long edge, the gate's width however the Camera was held, which is the reference's
/// frame width for a landscape frame.
extension DevelopedTreatment {
    func developInSceneLight(_ source: CIImage, film: FilmLook.NegativeFilm, passes: FilmLook.ScenePasses?, cube: Data,
                             frame: Int, frameRate: Int) -> CIImage {
        let extent = source.extent
        let width = Double(max(extent.width, extent.height))
        var image = source

        // A stock with a fixed balance records the light's own color, which the phone's white balance had taken out.
        if let balance = film.fixedBalance, let light = sceneWhiteBalance {
            image = Self.fixBalance(image, film: balance, light: light)
        }
        image = SceneLight.curve(image, SceneLight.opened, upTo: 1)

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
        // The film: back from Apple Log to the scene's light on Rec.709 primaries, then the cube in its own tones.
        image = SceneLight.curve(image.applyingFilter("CIColorClamp"), SceneLight.appleLogDecoded, upTo: 1)
        image = SceneLight.curve(SceneLight.onRec709(image), SceneLight.cubeTone, upTo: FilmLook.NegativeFilm.cubeBrightest)
            .applyingFilter("CIColorCube", parameters: ["inputCubeDimension": Self.negativeCubeDimension, "inputCubeData": cube])

        // The cube gives display tones; the weave resamples those, as the reference does, before Core Image is
        // handed them back as light.
        if let passes, let weave = passes.weave {
            image = woven(image, weave, width: width, referenceWidth: passes.referenceWidth, frame: frame, frameRate: frameRate)
        }
        return image.applyingFilter("CISRGBToneCurveToLinear").cropped(to: extent)
    }

    /// The film's cube covers every light from none to six stops over middle gray, so it has 64 tones a side.
    static let negativeCubeDimension = 64

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
        let offset = CGAffineTransform(translationX: -(random(frame, salt: 71) * side).rounded(.down),
                                       y: -(random(frame, salt: 72) * side).rounded(.down))
        let amount = grain.strength * width / referenceWidth
        let noise = field.samplingNearest().applyingFilter("CIAffineTile").transformed(by: offset).cropped(to: extent)
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
    static let opened = table(count: 4096, upTo: 1, FilmLook.NegativeFilm.sceneLight(displayLight:))

    /// Scene light to Apple Log tones, up to well past the brightest light a glow can add.
    static let appleLogRange = 8.0
    static let appleLog = table(count: 16384, upTo: appleLogRange, FilmLook.NegativeFilm.appleLogEncoded)

    /// Linear Rec.709 to linear Rec.2020, row by row: the inverse of the matrix the film uses to come back.
    static let rec2020: [[Double]] = {
        let m: [[Double]] = [[1.6605, -0.5876, -0.0728], [-0.1246, 1.1329, -0.0083], [-0.0182, -0.1006, 1.1187]]
        let determinant = m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1]) - m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0])
            + m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0])
        func cofactor(_ row: Int, _ column: Int) -> Double {
            let r = [0, 1, 2].filter { $0 != row }, c = [0, 1, 2].filter { $0 != column }
            let minor = m[r[0]][c[0]] * m[r[1]][c[1]] - m[r[0]][c[1]] * m[r[1]][c[0]]
            return (row + column).isMultiple(of: 2) ? minor : -minor
        }
        return (0..<3).map { row in (0..<3).map { cofactor($0, row) / determinant } }
    }()

    /// Apple Log tones back to scene light, and scene light to the film's cube tones (`NegativeFilm.cubeTone`).
    static let appleLogDecoded = table(count: 4096, upTo: 1, FilmLook.NegativeFilm.appleLogDecoded)
    static let cubeTone = table(count: 16384, upTo: FilmLook.NegativeFilm.cubeBrightest, FilmLook.NegativeFilm.cubeTone(sceneLight:))

    /// The picture's scene light from Rec.2020 primaries back on Rec.709's.
    static func onRec709(_ image: CIImage) -> CIImage {
        image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 1.6605, y: -0.5876, z: -0.0728, w: 0),
            "inputGVector": CIVector(x: -0.1246, y: 1.1329, z: -0.0083, w: 0),
            "inputBVector": CIVector(x: -0.0182, y: -0.1006, z: 1.1187, w: 0)
        ])
    }

    /// The picture's scene light on Rec.2020 primaries.
    static func onRec2020(_ image: CIImage) -> CIImage {
        func row(_ index: Int) -> CIVector { CIVector(x: rec2020[index][0], y: rec2020[index][1], z: rec2020[index][2], w: 0) }
        return image.applyingFilter("CIColorMatrix", parameters: ["inputRVector": row(0), "inputGVector": row(1), "inputBVector": row(2)])
    }

    static func curve(_ image: CIImage, _ table: Data, upTo limit: Double) -> CIImage {
        image.applyingFilter("CIColorCurves", parameters: [
            "inputCurvesData": table, "inputCurvesDomain": CIVector(x: 0, y: limit), "inputColorSpace": workingSpace
        ])
    }

    private static func table(count: Int, upTo limit: Double, _ curve: (Double) -> Double) -> Data {
        var values = [Float]()
        values.reserveCapacity(count * 3)
        for index in 0..<count {
            let value = Float(curve(Double(index) / Double(count - 1) * limit))
            values.append(contentsOf: [value, value, value])
        }
        return values.withUnsafeBufferPointer { Data(buffer: $0) }
    }
}

/// The film's grain as tiles of noise, made once for each kind of grain and reused: white noise with a normal
/// spread, softened to the grain's size, joined by a second, coarser octave, with a share of every layer's noise
/// common to all three, and each layer brought to a deviation of 1. A frame takes one tile at an offset of its own.
final class GrainField: @unchecked Sendable {
    static let shared = GrainField()
    static let side = 512
    static let count = 4

    private struct Key: Hashable {
        let size: Int
        let secondOctaveSize: Double
        let secondOctaveWeight: Double
        let shared: Double
        let index: Int
    }

    private let lock = NSLock()
    private var tiles: [Key: CIImage] = [:]

    /// `size` is the grain's blur radius in pixels of the frame.
    func tile(size: Double, grain: FilmLook.ScenePasses.Grain, index: Int) -> CIImage {
        let key = Key(size: Int((size * 1000).rounded()), secondOctaveSize: grain.secondOctaveSize,
                      secondOctaveWeight: grain.secondOctaveWeight, shared: grain.shared, index: min(max(index, 0), Self.count - 1))
        lock.lock()
        defer { lock.unlock() }
        if let tile = tiles[key] { return tile }
        let values = Self.field(size: size, grain: grain, seed: UInt64(key.index) &* 0x9e37_79b9_7f4a_7c15 &+ 0x1234_5678)
        let tile = CIImage(bitmapData: values.withUnsafeBufferPointer { Data(buffer: $0) }, bytesPerRow: Self.side * 16,
                           size: CGSize(width: Self.side, height: Self.side), format: .RGBAf, colorSpace: nil)
        tiles[key] = tile
        return tile
    }

    /// One tile's values, red, green, blue and an alpha of 1 for each cell, row by row. It repeats seamlessly.
    static func field(size: Double, grain: FilmLook.ScenePasses.Grain, seed: UInt64) -> [Float] {
        let cells = side * side
        var state = seed
        func octave(_ radius: Double) -> [[Double]] {
            (0..<3).map { _ in normalized(blurred(whiteNoise(cells, &state), radius: radius)) }
        }
        let fine = octave(size), coarse = octave(size * grain.secondOctaveSize)
        func mixed(_ first: [Double], _ firstShare: Double, _ second: [Double], _ secondShare: Double) -> [Double] {
            var result = [Double](repeating: 0, count: cells)
            var firstShare = firstShare, secondShare = secondShare
            vDSP_vsmsmaD(first, 1, &firstShare, second, 1, &secondShare, &result, 1, vDSP_Length(cells))
            return result
        }
        var layers = (0..<3).map { normalized(mixed(fine[$0], 1, coarse[$0], grain.secondOctaveWeight)) }
        let common = layers[1]
        layers = layers.map { normalized(mixed($0, 1 - grain.shared, common, grain.shared)) }
        var values = [Float](repeating: 1, count: cells * 4)
        for cell in 0..<cells {
            values[cell * 4] = Float(layers[0][cell]); values[cell * 4 + 1] = Float(layers[1][cell])
            values[cell * 4 + 2] = Float(layers[2][cell])
        }
        return values
    }

    private static func whiteNoise(_ count: Int, _ state: inout UInt64) -> [Double] {
        func uniform() -> Double {
            state = state &+ 0x9e37_79b9_7f4a_7c15
            var value = (state ^ (state >> 30)) &* 0xbf58_476d_1ce4_e5b9
            value = (value ^ (value >> 27)) &* 0x94d0_49bb_1331_11eb
            value ^= value >> 31
            return (Double(value >> 11) + 0.5) / Double(UInt64(1) << 53)
        }
        var noise = [Double](repeating: 0, count: count)
        var index = 0
        while index < count {
            // Two normal draws from two uniform ones.
            let radius = (-2 * log(uniform())).squareRoot(), angle = 2 * Double.pi * uniform()
            noise[index] = radius * cos(angle)
            if index + 1 < count { noise[index + 1] = radius * sin(angle) }
            index += 2
        }
        return noise
    }

    /// A Gaussian blur of the tile that wraps around its edges, so the tile still repeats seamlessly.
    private static func blurred(_ values: [Double], radius: Double) -> [Double] {
        guard radius > 0.01 else { return values }
        let reach = max(1, Int((4 * radius).rounded(.up)))
        var kernel = (-reach...reach).map { exp(-0.5 * Double($0 * $0) / (radius * radius)) }
        let total = kernel.reduce(0, +)
        kernel = kernel.map { $0 / total }
        // Each row, with its far end ahead of it and its near end after it, against the kernel.
        func across(_ source: [Double]) -> [Double] {
            var result = [Double](repeating: 0, count: source.count)
            var padded = [Double](repeating: 0, count: side + 2 * reach)
            source.withUnsafeBufferPointer { input in
                result.withUnsafeMutableBufferPointer { output in
                    padded.withUnsafeMutableBufferPointer { row in
                        for index in 0..<side {
                            let start = input.baseAddress! + index * side
                            row.baseAddress!.update(from: start + side - reach, count: reach)
                            (row.baseAddress! + reach).update(from: start, count: side)
                            (row.baseAddress! + reach + side).update(from: start, count: reach)
                            vDSP_convD(row.baseAddress!, 1, kernel, 1, output.baseAddress! + index * side, 1,
                                       vDSP_Length(side), vDSP_Length(kernel.count))
                        }
                    }
                }
            }
            return result
        }
        func turned(_ source: [Double]) -> [Double] {
            var result = [Double](repeating: 0, count: source.count)
            vDSP_mtransD(source, 1, &result, 1, vDSP_Length(side), vDSP_Length(side))
            return result
        }
        return turned(across(turned(across(values))))
    }

    private static func normalized(_ values: [Double]) -> [Double] {
        var result = [Double](repeating: 0, count: values.count)
        var mean = 0.0, deviation = 0.0
        vDSP_normalizeD(values, 1, &result, 1, &mean, &deviation, vDSP_Length(values.count))
        return result
    }
}
