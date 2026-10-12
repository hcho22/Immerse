import CoreGraphics
import CoreImage
import FilmDomain
import Foundation

/// The Developed Treatment one capture is assigned: its treatment version's look for the Camera and Film Stock, made
/// particular to the capture by its seed. Development renders it once and the result is kept, so nothing here is ever
/// rerolled (CONTEXT.md, Developed Treatment).
struct DevelopedTreatment {
    private enum Look {
        case legacy(camera: CameraID, filmStock: FilmStock?)
        case perCamera(FilmLook.Treatment, cube: Data)
    }

    private let look: Look
    private let seed: UInt64
    private let flashFired: Bool
    private let sceneWhiteBalance: SceneWhiteBalance?

    /// - Parameters:
    ///   - flashFired: whether the flash lit the exposure, which only a Camera with a flash look uses.
    ///   - sceneWhiteBalance: the light a Movie clip was recorded in, which only a Film Stock with a fixed color
    ///     balance uses.
    init(version: String, camera: CameraID, filmStock: FilmStock?, seed: UInt64, flashFired: Bool = false,
         sceneWhiteBalance: SceneWhiteBalance? = nil) throws {
        guard let version = TreatmentVersion(rawValue: version) else { throw NativeRenderError.unrenderableTreatment }
        switch version {
        case .one, .two:
            self.init(look: .legacy(camera: camera, filmStock: filmStock), seed: seed, flashFired: flashFired,
                      sceneWhiteBalance: nil)
        case .three:
            self.init(FilmLook.treatment(camera: camera, filmStock: filmStock), seed: seed, flashFired: flashFired,
                      sceneWhiteBalance: sceneWhiteBalance)
        }
    }

    /// A version 3 treatment as it stands, which tests use to look at one effect at a time.
    init(_ treatment: FilmLook.Treatment, seed: UInt64, flashFired: Bool = false, sceneWhiteBalance: SceneWhiteBalance? = nil) {
        let flash = flashFired ? treatment.flash : nil
        self.init(look: .perCamera(treatment, cube: Self.cube(treatment.emulsion, extraContrast: flash?.contrast ?? 0)),
                  seed: seed, flashFired: flashFired, sceneWhiteBalance: sceneWhiteBalance)
    }

    private init(look: Look, seed: UInt64, flashFired: Bool, sceneWhiteBalance: SceneWhiteBalance?) {
        self.look = look
        self.seed = seed
        self.flashFired = flashFired
        self.sceneWhiteBalance = sceneWhiteBalance
    }

    /// The developed picture, or one developed Movie frame, at the source's size. `frame` counts the Movie's frames at
    /// `frameRate` from the start of the clip; a photo is frame 0.
    func apply(to source: CIImage, frame: Int = 0, frameRate: Int = 0) throws -> CIImage {
        switch look {
        case let .legacy(camera, filmStock):
            return try LegacyLook.apply(to: source, camera: camera, filmStock: filmStock, seed: seed, frame: frame)
        case let .perCamera(treatment, cube):
            return render(source, treatment: treatment, cube: cube, frame: frame, frameRate: frameRate)
        }
    }

    // MARK: - Version 3

    private func render(_ source: CIImage, treatment: FilmLook.Treatment, cube: Data, frame: Int, frameRate: Int) -> CIImage {
        let extent = source.extent
        let longEdge = max(extent.width, extent.height)
        var image = source

        // The lens: overall softness, softer corners, and darker corners.
        let lens = treatment.lens
        if lens.softness > 0 {
            image = image.clampedToExtent().applyingGaussianBlur(sigma: lens.softness * longEdge).cropped(to: extent)
        }
        if lens.diffusion > 0 {
            let veil = image.clampedToExtent().applyingGaussianBlur(sigma: 0.012 * longEdge).cropped(to: extent)
            image = veil.applyingFilter("CIDissolveTransition", parameters: [
                kCIInputTargetImageKey: image, kCIInputTimeKey: 1 - lens.diffusion
            ]).cropped(to: extent)
        }
        if lens.edgeSoftness > 0 {
            image = image.clampedToExtent().applyingFilter("CIMaskedVariableBlur", parameters: [
                "inputMask": Self.radialMask(extent, inner: 0.35, centerLevel: 0, edgeLevel: 1),
                kCIInputRadiusKey: lens.edgeSoftness * longEdge
            ]).cropped(to: extent)
        }
        if let halation = treatment.halation { image = Self.halate(image, halation, longEdge: longEdge) }
        if lens.edgeDarkening > 0 {
            image = Self.multiply(image, by: Self.radialMask(extent, inner: 0.3, centerLevel: 1,
                                                             edgeLevel: pow(2, -lens.edgeDarkening)))
        }
        // Direct flash: a hot center that falls away toward the corners.
        if flashFired, let flash = treatment.flash {
            image = Self.multiply(image, by: Self.radialMask(extent, inner: 0, centerLevel: pow(2, flash.falloff / 3),
                                                             edgeLevel: pow(2, -flash.falloff * 2 / 3)))
        }
        // This print's own density and color, assigned once from its seed.
        if let variation = treatment.printVariation {
            let density = variation.density * random(0, salt: 1, signed: true)
            let warmth = variation.warmth * random(0, salt: 2, signed: true)
            let tint = variation.tint * random(0, salt: 3, signed: true)
            image = Self.balance(image, warmth: warmth, tint: tint, gain: pow(2, density))
        }

        // A stock with a fixed balance records the light's own color, which the phone's white balance had taken out.
        if case let .color(emulsion) = treatment.emulsion, let balance = emulsion.fixedBalance, let light = sceneWhiteBalance {
            image = Self.fixBalance(image, film: balance, light: light)
        }

        // The film and its print.
        image = image.applyingFilter("CIColorCubeWithColorSpace", parameters: [
            "inputCubeDimension": Self.cubeDimension, "inputCubeData": cube,
            "inputColorSpace": CGColorSpace(name: CGColorSpace.sRGB)!
        ])
        image = grain(image, treatment.emulsion.grain, longEdge: longEdge, frame: frame)

        // A Movie Camera's gate: dust on the film, the frame's unsteadiness, a hair caught in the gate, and flicker.
        if let gate = treatment.gate {
            if gate.dust > 0 { image = dust(on: image, gate, longEdge: longEdge, frame: frame) }
            image = unsteady(image, gate, frame: frame, frameRate: frameRate)
            if gate.hair > 0, random(0, salt: 40) < gate.hair { image = hair(over: image, frame: frame) }
            if gate.flicker > 0 {
                image = image.applyingFilter("CIExposureAdjust", parameters: [
                    kCIInputEVKey: gate.flicker * random(frame, salt: 30, signed: true)
                ])
            }
        }
        return image.cropped(to: extent)
    }

    /// Grain, blended over display tones so it shows most in the middle tones, with extra grain in the shadows where
    /// the treatment asks for it. Each frame of a Movie has its own.
    private func grain(_ image: CIImage, _ grain: FilmLook.Grain, longEdge: CGFloat, frame: Int) -> CIImage {
        guard grain.amplitude > 0 else { return image }
        let extent = image.extent
        let size = max(1.2, grain.size * longEdge)
        // Each channel its own noise; the gray part repeats the red channel in every channel.
        let chroma = grain.chroma
        let noise = noiseTile(frame: frame)
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 1, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 1 - chroma, y: chroma, z: 0, w: 0),
                "inputBVector": CIVector(x: 1 - chroma, y: 0, z: chroma, w: 0)
            ])
            .applyingFilter("CIAffineTile")
            .cropped(to: CGRect(x: 0, y: 0, width: ceil(extent.width / size) + 2, height: ceil(extent.height / size) + 2))
            .samplingLinear()
            .transformed(by: CGAffineTransform(scaleX: size, y: size))
            .clampedToExtent()
            .applyingGaussianBlur(sigma: size * 0.5)
            .cropped(to: extent)
        // Soft light changes mid-gray by half the blend's distance from 0.5, so twice the wanted spread goes in.
        let midtones = Self.centered(noise, deviation: 2 * grain.amplitude / 255)
        let display = image.applyingFilter("CILinearToSRGBToneCurve")
        var grained = midtones.applyingFilter("CISoftLightBlendMode", parameters: [kCIInputBackgroundImageKey: display])
        if grain.shadows > 0 {
            // Linear light adds twice the blend's distance from 0.5 at every tone; the shadow mask keeps it to the
            // dark tones.
            let shadowGrain = Self.centered(noise, deviation: grain.shadows * grain.amplitude / 255)
                .applyingFilter("CILinearLightBlendMode", parameters: [kCIInputBackgroundImageKey: grained])
            let shadowMask = display.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: -0.2126, y: -0.7152, z: -0.0722, w: 0),
                "inputGVector": CIVector(x: -0.2126, y: -0.7152, z: -0.0722, w: 0),
                "inputBVector": CIVector(x: -0.2126, y: -0.7152, z: -0.0722, w: 0),
                "inputBiasVector": CIVector(x: 1, y: 1, z: 1, w: 0)
            ])
            grained = shadowGrain.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: grained, kCIInputMaskImageKey: Self.multiply(shadowMask, by: shadowMask)
            ])
        }
        return grained.cropped(to: extent).applyingFilter("CISRGBToneCurveToLinear")
    }

    /// Dark specks of dust on the film, a few at most and never large, different on every frame.
    private func dust(on image: CIImage, _ gate: FilmLook.Gate, longEdge: CGFloat, frame: Int) -> CIImage {
        let extent = image.extent
        var specks = CIImage(color: .white).cropped(to: extent)
        for index in 0..<3 where random(frame, salt: 50 + UInt64(index)) < gate.dust / 3 {
            let salt = 60 + UInt64(index) * 4
            let center = CIVector(x: extent.width * random(frame, salt: salt), y: extent.height * random(frame, salt: salt + 1))
            let radius = longEdge * (0.0012 + 0.0025 * random(frame, salt: salt + 2))
            let darkness = 0.45 + 0.35 * random(frame, salt: salt + 3)
            // The gradient is white everywhere beyond the speck, so it leaves the rest of the frame alone.
            let speck = CIFilter(name: "CIRadialGradient", parameters: [
                "inputCenter": center, "inputRadius0": radius * 0.45, "inputRadius1": radius,
                "inputColor0": Self.gray(1 - darkness), "inputColor1": Self.gray(1)
            ])!.outputImage!
            specks = speck.applyingFilter("CIMinimumCompositing", parameters: [kCIInputBackgroundImageKey: specks]).cropped(to: extent)
        }
        return Self.multiply(image, by: specks)
    }

    /// The picture's slow sideways weave and its frame-to-frame jitter, drawn from slightly beyond the frame's edges so
    /// no edge ever shows empty.
    private func unsteady(_ image: CIImage, _ gate: FilmLook.Gate, frame: Int, frameRate: Int) -> CIImage {
        let extent = image.extent
        let time = frameRate > 0 ? Double(frame) / Double(frameRate) : 0
        let phase = 2 * Double.pi * random(0, salt: 20)
        let dx = extent.width * (gate.weave * sin(2 * .pi * time / gate.weavePeriod + phase)
            + gate.jitter * 0.5 * random(frame, salt: 21, signed: true))
        let dy = extent.height * gate.jitter * random(frame, salt: 22, signed: true)
        let scale = 1 + 2 * max(gate.weave + gate.jitter * 0.5, gate.jitter)
        return image.clampedToExtent()
            .transformed(by: CGAffineTransform(translationX: -extent.midX, y: -extent.midY)
                .concatenating(CGAffineTransform(scaleX: scale, y: scale))
                .concatenating(CGAffineTransform(translationX: extent.midX + dx, y: extent.midY + dy)))
            .cropped(to: extent)
    }

    /// A hair caught at the edge of the gate for the whole clip: a thin dark curl reaching in from one edge, trembling
    /// slightly from frame to frame.
    private func hair(over image: CIImage, frame: Int) -> CIImage {
        let extent = image.extent
        let length = extent.height * (0.06 + 0.06 * random(0, salt: 41))
        let box = Int(ceil(length * 1.2))
        let thickness = max(1, extent.height * 0.0016)
        guard let context = CGContext(data: nil, width: box, height: box, bitsPerComponent: 8, bytesPerRow: box * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return image }
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: box, height: box))
        let bend = CGFloat(random(0, salt: 42, signed: true)) * length * 0.5
        let tremble = CGFloat(random(frame, salt: 43, signed: true)) * thickness * 0.6
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: CGFloat(box) * 0.2))
        path.addQuadCurve(to: CGPoint(x: length * 0.9, y: CGFloat(box) * 0.2 + bend * 0.6 + tremble),
                          control: CGPoint(x: length * 0.5, y: CGFloat(box) * 0.2 + bend + tremble))
        context.addPath(path)
        context.setStrokeColor(gray: 0.12, alpha: 1)
        context.setLineWidth(thickness)
        context.setLineCap(.round)
        context.strokePath()
        guard let drawn = context.makeImage() else { return image }
        // Which edge it reaches in from, and where along it.
        let edge = Int(random(0, salt: 44) * 4)
        let along = 0.2 + 0.6 * random(0, salt: 45)
        let side = CGFloat(box)
        let placement: CGAffineTransform = switch edge {
        case 0: CGAffineTransform(translationX: 0, y: extent.height * along - side * 0.2)
        case 1: CGAffineTransform(rotationAngle: .pi).concatenating(
            CGAffineTransform(translationX: extent.width, y: extent.height * along + side * 0.2))
        case 2: CGAffineTransform(rotationAngle: -.pi / 2).concatenating(
            CGAffineTransform(translationX: extent.width * along - side * 0.2, y: extent.height))
        default: CGAffineTransform(rotationAngle: .pi / 2).concatenating(
            CGAffineTransform(translationX: extent.width * along + side * 0.2, y: 0))
        }
        let overlay = CIImage(cgImage: drawn).transformed(by: placement)
            .composited(over: CIImage(color: .white)).cropped(to: extent)
        return Self.multiply(image, by: overlay)
    }

    /// 512 x 512 cells of uniform noise from the capture's seed and the frame, red, green and blue each their own. It is
    /// untagged, so Core Image takes its values as they are.
    private func noiseTile(frame: Int) -> CIImage {
        let side = 512
        var state = seed ^ (UInt64(truncatingIfNeeded: frame) &* 0x9e37_79b9_7f4a_7c15)
        var bytes = [UInt8](repeating: 255, count: side * side * 4)
        for index in stride(from: 0, to: bytes.count, by: 4) {
            state = state &+ 0x9e37_79b9_7f4a_7c15
            var value = (state ^ (state >> 30)) &* 0xbf58_476d_1ce4_e5b9
            value = (value ^ (value >> 27)) &* 0x94d0_49bb_1331_11eb
            value ^= value >> 31
            bytes[index] = UInt8(truncatingIfNeeded: value)
            bytes[index + 1] = UInt8(truncatingIfNeeded: value >> 8)
            bytes[index + 2] = UInt8(truncatingIfNeeded: value >> 16)
        }
        return CIImage(bitmapData: Data(bytes), bytesPerRow: side * 4, size: CGSize(width: side, height: side),
                       format: .RGBA8, colorSpace: nil)
    }

    /// A deterministic value in 0..<1 (or -1..<1 when `signed`) for this capture, a frame and a purpose.
    private func random(_ frame: Int, salt: UInt64, signed: Bool = false) -> Double {
        var value = seed &+ UInt64(truncatingIfNeeded: frame) &* 0x9e37_79b9_7f4a_7c15 &+ salt &* 0xd1b5_4a32_d192_ed03
        value = (value ^ (value >> 30)) &* 0xbf58_476d_1ce4_e5b9
        value = (value ^ (value >> 27)) &* 0x94d0_49bb_1331_11eb
        value ^= value >> 31
        let unit = Double(value >> 11) / Double(UInt64(1) << 53)
        return signed ? unit * 2 - 1 : unit
    }

    // MARK: - Building blocks

    static let cubeDimension = 32

    /// The emulsion as a color cube over display tones: color balance, color strength and the print curve for color,
    /// or the panchromatic silver layer and its curve for black-and-white.
    static func cube(_ emulsion: FilmLook.Emulsion, extraContrast: Double = 0) -> Data {
        let size = cubeDimension
        var values = [Float](repeating: 0, count: size * size * size * 4)
        for blue in 0..<size { for green in 0..<size { for red in 0..<size {
            let input = FilmLook.RGB(Double(red) / Double(size - 1), Double(green) / Double(size - 1),
                                     Double(blue) / Double(size - 1))
            let output = develop(input, emulsion, extraContrast: extraContrast)
            let index = ((blue * size + green) * size + red) * 4
            values[index] = Float(output.red); values[index + 1] = Float(output.green)
            values[index + 2] = Float(output.blue); values[index + 3] = 1
        } } }
        return values.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    /// One display color through the emulsion.
    static func develop(_ color: FilmLook.RGB, _ emulsion: FilmLook.Emulsion, extraContrast: Double = 0) -> FilmLook.RGB {
        let linear = FilmLook.RGB(linearized(color.red), linearized(color.green), linearized(color.blue))
        switch emulsion {
        case let .monochrome(film):
            var tone = film.tone
            tone.contrast += extraContrast
            let exposure = linear.red * film.spectral.red + linear.green * film.spectral.green + linear.blue * film.spectral.blue
            let gray = tone(encoded(exposure))
            return FilmLook.RGB(gray, gray, gray)
        case let .color(film):
            var tone = film.tone
            tone.contrast += extraContrast
            let gains = FilmLook.RGB(1 + film.warmth, 1 - film.tint, 1 - film.warmth)
            let normal = 1 / luminance(gains)
            var balanced = FilmLook.RGB(linear.red * gains.red * normal, linear.green * gains.green * normal,
                                        linear.blue * gains.blue * normal)
            let layers = film.layers
            balanced = FilmLook.RGB(balanced.red + layers.redFromGreen * (balanced.green - balanced.red)
                                        + layers.redFromBlue * (balanced.blue - balanced.red),
                                    balanced.green + layers.greenFromBlue * (balanced.blue - balanced.green),
                                    balanced.blue + layers.blueFromGreen * (balanced.green - balanced.blue))
            let level = luminance(balanced)
            balanced = FilmLook.RGB(max(0, level + film.saturation * (balanced.red - level)),
                                    max(0, level + film.saturation * (balanced.green - level)),
                                    max(0, level + film.saturation * (balanced.blue - level)))
            var printed = FilmLook.RGB(tone(encoded(balanced.red)), tone(encoded(balanced.green)), tone(encoded(balanced.blue)))
            let lightness = luminance(printed)
            let shadow = (1 - lightness) * (1 - lightness), highlight = lightness * lightness
            printed = FilmLook.RGB(
                min(1, max(0, printed.red + film.shadows.red * shadow + film.highlights.red * highlight)),
                min(1, max(0, printed.green + film.shadows.green * shadow + film.highlights.green * highlight)),
                min(1, max(0, printed.blue + film.shadows.blue * shadow + film.highlights.blue * highlight))
            )
            return printed
        }
    }

    /// A glow around the highlights: the light above the threshold, spread and colored, added back in linear light.
    /// It is spread at a quarter of the picture's size, which a wide, soft glow does not need.
    static func halate(_ image: CIImage, _ halation: FilmLook.Halation, longEdge: CGFloat) -> CIImage {
        let extent = image.extent
        let weights = CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0)
        let scale = 1 / (1 - halation.threshold)
        let light = image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": weights, "inputGVector": weights, "inputBVector": weights,
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBiasVector": CIVector(x: -halation.threshold, y: -halation.threshold, z: -halation.threshold, w: 1)
        ]).applyingFilter("CIColorClamp", parameters: [
            "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 1), "inputMaxComponents": CIVector(x: 4, y: 4, z: 4, w: 1)
        ])
        let quarter = CGAffineTransform(scaleX: 0.25, y: 0.25)
        let glow = light.clampedToExtent().transformed(by: quarter)
            .applyingGaussianBlur(sigma: halation.radius * longEdge * 0.25)
            .transformed(by: quarter.inverted()).cropped(to: extent)
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: halation.color.red * halation.strength * scale, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: halation.color.green * halation.strength * scale, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: halation.color.blue * halation.strength * scale, w: 0)
            ])
        // Linear dodge adds the glow and keeps the picture opaque.
        return glow.applyingFilter("CILinearDodgeBlendMode", parameters: [kCIInputBackgroundImageKey: image]).cropped(to: extent)
    }

    /// The light's color as a film balanced for `film` kelvin records it: light warmer than the film's balance turns
    /// warm and cooler light cool. The light's temperature is held to 2000 to 10000 kelvin.
    static func fixBalance(_ image: CIImage, film: Double, light: SceneWhiteBalance) -> CIImage {
        let temperature = min(max(light.temperature, 2000), 10000)
        return image.applyingFilter("CITemperatureAndTint", parameters: [
            "inputNeutral": CIVector(x: film, y: 0),
            "inputTargetNeutral": CIVector(x: temperature, y: light.tint)
        ])
    }

    /// Gains on red, green and blue in linear light: warmth up on red and down on blue, tint down on green, and an
    /// overall gain.
    static func balance(_ image: CIImage, warmth: Double, tint: Double, gain: Double) -> CIImage {
        let gains = FilmLook.RGB(1 + warmth, 1 - tint, 1 - warmth)
        let normal = gain / luminance(gains)
        return image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: gains.red * normal, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: gains.green * normal, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: gains.blue * normal, w: 0)
        ])
    }

    /// A gray mask, `centerLevel` inside `inner` of the half-diagonal and changing evenly to `edgeLevel` at the
    /// corners. Levels are linear light.
    static func radialMask(_ extent: CGRect, inner: Double, centerLevel: Double, edgeLevel: Double) -> CIImage {
        let halfDiagonal = hypot(extent.width, extent.height) / 2
        return CIFilter(name: "CIRadialGradient", parameters: [
            "inputCenter": CIVector(x: extent.midX, y: extent.midY),
            "inputRadius0": halfDiagonal * inner, "inputRadius1": halfDiagonal,
            "inputColor0": gray(centerLevel), "inputColor1": gray(edgeLevel)
        ])!.outputImage!.cropped(to: extent)
    }

    static func multiply(_ image: CIImage, by mask: CIImage) -> CIImage {
        mask.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: image]).cropped(to: image.extent)
    }

    /// Noise centered on 0.5 with the given standard deviation, from uniform noise blurred into clumps.
    static func centered(_ noise: CIImage, deviation: Double) -> CIImage {
        let gain = deviation / clumpedNoiseDeviation
        return noise.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: gain, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: gain, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: gain, w: 0),
            "inputBiasVector": CIVector(x: 0.5 - gain * 0.5, y: 0.5 - gain * 0.5, z: 0.5 - gain * 0.5, w: 0)
        ])
    }

    /// The standard deviation of the grain's clumped noise before scaling, for clumps of 1.2 pixels and more, measured
    /// on an even mid-gray (`FilmLookTests.testGrainAmplitudeIsTheDeviationItAddsToMidGray`).
    static let clumpedNoiseDeviation = 0.071

    static func gray(_ level: Double) -> CIColor {
        CIColor(red: level, green: level, blue: level, colorSpace: CGColorSpace(name: CGColorSpace.linearSRGB)!)!
    }

    static func luminance(_ color: FilmLook.RGB) -> Double {
        0.2126 * color.red + 0.7152 * color.green + 0.0722 * color.blue
    }

    static func linearized(_ tone: Double) -> Double {
        tone <= 0.04045 ? tone / 12.92 : pow((tone + 0.055) / 1.055, 2.4)
    }

    static func encoded(_ light: Double) -> Double {
        let value = min(max(light, 0), 1)
        return value <= 0.0031308 ? value * 12.92 : 1.055 * pow(value, 1 / 2.4) - 0.055
    }
}
