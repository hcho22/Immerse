import Foundation

extension FilmLook {
    /// A color negative and the picture made from it, as the captain's look generators define it (one model for every
    /// color negative Film Stock; `Probes/FilmLookCalibration` holds the generators and the tools that derived their
    /// constants). The scene's light, with middle gray at 0.18, becomes log exposure on a low-contrast negative with a
    /// soft toe and crosstalk between its three layers; the negative is then printed, or scanned, into the picture's
    /// density; seven bands of hue are turned, strengthened and lightened in OKLCh; the brightest and darkest tones
    /// lose some color; and the highlights are eased toward white. The steps, their order and every constant are the
    /// generators', and `NegativeFilmTests` holds this to their numbers.
    struct NegativeFilm: Equatable {
        /// How the negative becomes the picture.
        enum Output: Equatable {
            /// Printed on print film: a steep S-shaped response between clear film and `maximumDensity`.
            case print(maximumDensity: Double)
            /// Scanned: the picture's density falls away with the negative's, gently and without a hard white.
            case scan
        }

        /// One band's changes: its hue turn in degrees, and its color strength and lightness as a change from 1.
        struct Band: Equatable {
            var turn: Double
            var chroma: Double
            var lightness: Double

            init(_ turn: Double, _ chroma: Double, _ lightness: Double) {
                self.turn = turn
                self.chroma = chroma
                self.lightness = lightness
            }
        }

        /// Each layer's contrast: density per unit of log exposure on the straight part of its curve.
        var negativeGamma: RGB
        /// Exposure given to the negative, in stops over the scene's.
        var exposure = 0.0
        /// Gains on the scene's light before exposure. All 1 develops daylight neutral.
        var balance = RGB(1, 1, 1)
        /// The color temperature of light, in kelvin, the film records as neutral when it keeps a fixed balance: a
        /// Movie clip recorded in warmer light develops warm and in cooler light cool, against the light its capture
        /// recorded (`SceneWhiteBalance`). Nil follows the phone's white balance.
        var fixedBalance: Double? = nil
        /// Where the negative's toe sits, in stops from middle gray.
        var toe: Double
        /// How each layer's log exposure mixes the others'. Each row sums to 1, so gray stays gray.
        var crosstalk: [RGB]
        var output: Output
        /// The steepness of each layer's print or scan response.
        var slope: RGB
        /// The density middle gray comes out at.
        var grayDensity: Double
        /// An offset on each layer's negative density.
        var bias = RGB.zero
        /// The picture's black, in display light: the projection's or the scan's.
        var black: RGB
        /// The seven bands' fitted changes and the finishing changes added to them, in the order red, skin and
        /// orange, yellow, green, aqua, blue, purple and magenta.
        var bands: [Band]
        var finish: [Band]
        /// How much color the brightest tones lose, and the darkest.
        var highlightDesaturation: Double
        var shadowDesaturation: Double

        /// Where the bands sit in OKLCh and how wide they are, in degrees.
        static let bandCenters: [Double] = [25, 55, 105, 140, 200, 255, 320]
        static let bandWidths: [Double] = [20, 20, 20, 25, 25, 25, 30]
        /// The display light above which highlights are eased toward white.
        static let softClip = 0.85

        // MARK: - The picture

        /// The scene's light, in linear Rec.709 with middle gray at 0.18, as the picture's display tones (sRGB).
        func developed(scene: RGB) -> RGB {
            let picture = turnedBands(printed(scene))
            func soft(_ light: Double) -> Double {
                let knee = Self.softClip
                return light < knee ? light : knee + (1 - knee) * tanh((light - knee) / (1 - knee))
            }
            return RGB(Self.displayTone(soft(picture.red)), Self.displayTone(soft(picture.green)),
                       Self.displayTone(soft(picture.blue)))
        }

        /// One color of a picture as the phone delivered it, as display tones, through the film. The phone
        /// compressed the scene's highlights for display, so they are opened again first.
        func developed(display color: RGB) -> RGB {
            developed(scene: RGB(Self.sceneLight(displayLight: Self.displayLight(color.red)),
                                 Self.sceneLight(displayLight: Self.displayLight(color.green)),
                                 Self.sceneLight(displayLight: Self.displayLight(color.blue))))
        }

        /// The picture for one Apple Log tone on Rec.2020 primaries, which is the form the scene's light is in when
        /// the film's grain is added and so the form the color cube is asked in.
        func developed(appleLog tone: RGB) -> RGB {
            let red = Self.appleLogDecoded(tone.red), green = Self.appleLogDecoded(tone.green), blue = Self.appleLogDecoded(tone.blue)
            return developed(scene: RGB(1.6605 * red - 0.5876 * green - 0.0728 * blue,
                                        -0.1246 * red + 1.1329 * green - 0.0083 * blue,
                                        -0.0182 * red - 0.1006 * green + 1.1187 * blue))
        }

        /// The film as a color cube, red varying fastest, as display tones. The cube is asked in Apple Log tones of
        /// the scene's light on Rec.709 primaries, stretched so that no light is the cube's first tone and
        /// `cubeBrightest` its last (`cubeTone`). On those primaries a phone picture's most saturated colors lie on
        /// the cube's faces, where it reads them exactly; on Rec.2020 primaries they would fall inside it, across a
        /// kink.
        func cube(dimension: Int) -> Data {
            var values = [Float](repeating: 0, count: dimension * dimension * dimension * 4)
            let last = Double(dimension - 1)
            func light(_ step: Int) -> Double { Self.sceneLight(cubeTone: Double(step) / last) }
            for blue in 0..<dimension { for green in 0..<dimension { for red in 0..<dimension {
                let output = developed(scene: RGB(light(red), light(green), light(blue)))
                let index = ((blue * dimension + green) * dimension + red) * 4
                values[index] = Float(min(max(output.red, 0), 1)); values[index + 1] = Float(min(max(output.green, 0), 1))
                values[index + 2] = Float(min(max(output.blue, 0), 1)); values[index + 3] = 1
            } } }
            return values.withUnsafeBufferPointer { Data(buffer: $0) }
        }

        /// The brightest scene light the cube holds: what an Apple Log tone of 1 stands for, about six stops over
        /// middle gray. A phone picture's white is 2.6.
        static let cubeBrightest = appleLogDecoded(1)

        /// Where a scene light sits along the cube's side, from 0 for no light to 1 for `cubeBrightest`.
        static func cubeTone(sceneLight light: Double) -> Double {
            let floor = appleLogEncoded(0)
            return (appleLogEncoded(min(max(light, 0), cubeBrightest)) - floor) / (1 - floor)
        }

        static func sceneLight(cubeTone tone: Double) -> Double {
            let floor = appleLogEncoded(0)
            return max(appleLogDecoded(floor + min(max(tone, 0), 1) * (1 - floor)), 0)
        }

        /// The scene's light through the negative and its print or scan, as display light.
        private func printed(_ scene: RGB) -> RGB {
            let toeLevel = pow(10, toe * log10(2.0))
            let gain = pow(2, exposure)
            func exposed(_ light: Double, _ balance: Double) -> Double {
                let level = max(light * balance * gain, 1e-7) / 0.18
                return log10(level + toeLevel) - log10(1 + toeLevel)
            }
            let layers = RGB(exposed(scene.red, balance.red), exposed(scene.green, balance.green), exposed(scene.blue, balance.blue))
            func mixed(_ row: RGB) -> Double { row.red * layers.red + row.green * layers.green + row.blue * layers.blue }
            func layer(_ exposure: Double, _ gamma: Double, _ bias: Double, _ slope: Double, _ black: Double) -> Double {
                let negative = gamma * exposure - bias
                let density: Double
                switch output {
                case .scan:
                    density = grayDensity * exp(-slope * negative)
                case let .print(maximumDensity):
                    let center = -log(1 / (grayDensity / maximumDensity) - 1) / slope
                    density = maximumDensity / (1 + exp(slope * (negative - center)))
                }
                return black + (1 - black) * pow(10, -min(density, 6))
            }
            return RGB(layer(mixed(crosstalk[0]), negativeGamma.red, bias.red, slope.red, black.red),
                       layer(mixed(crosstalk[1]), negativeGamma.green, bias.green, slope.green, black.green),
                       layer(mixed(crosstalk[2]), negativeGamma.blue, bias.blue, slope.blue, black.blue))
        }

        /// The bands' changes in OKLCh, then the loss of color in the brightest and darkest tones.
        private func turnedBands(_ light: RGB) -> RGB {
            let red = max(light.red, 0), green = max(light.green, 0), blue = max(light.blue, 0)
            let long = cbrt(0.4122214708 * red + 0.5363325363 * green + 0.0514459929 * blue)
            let medium = cbrt(0.2119034982 * red + 0.6806995451 * green + 0.1073969566 * blue)
            let short = cbrt(0.0883024619 * red + 0.2817188376 * green + 0.6299787005 * blue)
            var lightness = 0.2104542553 * long + 0.7936177850 * medium - 0.0040720468 * short
            let a = 1.9779984951 * long - 2.4285922050 * medium + 0.4505937099 * short
            let b = 0.0259040371 * long + 0.7827717662 * medium - 0.8086757660 * short
            var chroma = hypot(a, b)
            let hue = Self.wrapped(atan2(b, a) * 180 / .pi)
            // A gray tone has no hue to turn: the bands count for nothing at zero chroma and fully from 0.03.
            let gate = min(max(chroma / 0.03, 0), 1)
            var turn = 0.0, strength = 1.0, lighter = 1.0
            for index in 0..<Self.bandCenters.count {
                let distance = Self.wrapped(hue - Self.bandCenters[index] + 180) - 180
                let weight = exp(-0.5 * pow(distance / Self.bandWidths[index], 2)) * gate
                turn += weight * (bands[index].turn + finish[index].turn)
                strength *= 1 + weight * (bands[index].chroma + finish[index].chroma)
                lighter *= 1 + weight * (bands[index].lightness + finish[index].lightness)
            }
            func smooth(_ low: Double, _ high: Double, _ value: Double) -> Double {
                let share = min(max((value - low) / (high - low), 0), 1)
                return share * share * (3 - 2 * share)
            }
            chroma *= strength
            chroma *= 1 - highlightDesaturation * smooth(0.80, 1.00, lightness)
            chroma *= 1 - shadowDesaturation * (1 - smooth(0.00, 0.35, lightness))
            lightness *= lighter
            let angle = (hue + turn) * .pi / 180
            let newA = chroma * cos(angle), newB = chroma * sin(angle)
            // OKLab back to linear light: the inverses of the two matrices above.
            let l = pow(lightness + 0.3963377774 * newA + 0.2158037573 * newB, 3)
            let m = pow(lightness - 0.1055613458 * newA - 0.0638541728 * newB, 3)
            let s = pow(lightness - 0.0894841775 * newA - 1.2914855480 * newB, 3)
            return RGB(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
                       -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
                       -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)
        }

        /// An angle in degrees brought into 0..<360.
        private static func wrapped(_ degrees: Double) -> Double {
            let remainder = degrees.truncatingRemainder(dividingBy: 360)
            return remainder < 0 ? remainder + 360 : remainder
        }

        // MARK: - Scene light and Apple Log

        /// Display light from a display tone (sRGB), and back.
        static func displayLight(_ tone: Double) -> Double {
            let value = min(max(tone, 0), 1)
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }

        static func displayTone(_ light: Double) -> Double {
            let value = min(max(light, 0), 1)
            return value <= 0.0031308 ? value * 12.92 : 1.055 * pow(value, 1 / 2.4) - 0.055
        }

        /// The scene's light for a phone picture's display light. The phone compressed the highlights; this opens
        /// them again: nothing changes up to 0.6, and the picture's white becomes 2.6, about 3.85 stops over middle
        /// gray.
        static func sceneLight(displayLight light: Double) -> Double {
            guard light > 0.6 else { return light }
            let over = min(light - 0.6, 0.45)
            return 0.6 + over / (1 - over / 0.5)
        }

        // The Apple Log curve, as Apple publishes it.
        private static let logR0 = -0.05641088, logRt = 0.01, logC = 47.28711236
        private static let logBeta = 0.00964052, logGamma = 0.08550479, logDelta = 0.69336945

        static func appleLogEncoded(_ light: Double) -> Double {
            if light >= logRt { return logGamma * log2(max(light + logBeta, 1e-12)) + logDelta }
            if light >= logR0 { return logC * (light - logR0) * (light - logR0) }
            return 0
        }

        static func appleLogDecoded(_ tone: Double) -> Double {
            if tone >= logC * (logRt - logR0) * (logRt - logR0) { return pow(2, (tone - logDelta) / logGamma) - logBeta }
            if tone >= 0 { return (max(tone, 0) / logC).squareRoot() + logR0 }
            return logR0
        }
    }
}
