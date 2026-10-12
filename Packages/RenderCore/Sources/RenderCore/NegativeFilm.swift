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

        /// How the film reaches Core Image, which reads a color cube.
        enum Table: Equatable {
            /// The film's own function, over tones of the scene's light on Rec.709 primaries (`cubeTone`).
            case function
            /// The generator's own table: the film at `side` Apple Log tones a side on Rec.2020 primaries, read
            /// between its tones tetrahedrally, as the captain's spec for the Film Stock reads it. Between its tones
            /// that table is not the function: on saturated colors the two differ by a few hundredths.
            case appleLog(side: Int)
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
        var table = Table.function

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

        /// A film's color cube as Core Image is handed it. Core Image keeps a cube's values in 8 bits, and half of
        /// one of those steps shows in a look's flattest tones, as a slight unevenness in lifted blacks. So the cube
        /// is handed over as two: each value's whole 8-bit steps, and what is left of it as a share of one step.
        /// Core Image reads both in straight lines between their tones, so the two readings add up to the reading
        /// of the values themselves, to 16 bits.
        struct Cube: Equatable {
            let dimension: Int
            /// Each value's whole 8-bit steps, as a cube of red, green, blue and alpha, red varying fastest.
            let steps: Data
            /// What is left of each value, as a share of one 8-bit step.
            let remainders: Data
        }

        /// The film as a color cube, red varying fastest, as display tones.
        ///
        /// For `Table.function` the cube is asked in Apple Log tones of the scene's light on Rec.709 primaries,
        /// stretched so that no light is the cube's first tone and `cubeBrightest` its last (`cubeTone`). On those
        /// primaries a phone picture's most saturated colors lie on the cube's faces, where it reads them exactly; on
        /// Rec.2020 primaries they would fall inside it, across a kink.
        ///
        /// For `Table.appleLog` the cube is asked in Apple Log tones on Rec.2020 primaries, as the generator's table
        /// is. Core Image reads a cube between its tones in straight lines along each axis, not tetrahedrally, so the
        /// cube holds the table's tetrahedral reading at twice the table's tones a side: every tone of the table, and
        /// the reading halfway between each pair.
        func cube() -> Cube {
            let dimension = cubeDimension
            let count = dimension * dimension * dimension
            var steps = [Float](repeating: 1, count: count * 4), remainders = [Float](repeating: 1, count: count * 4)
            let last = Double(dimension - 1)
            let color: (Int, Int, Int) -> RGB
            switch table {
            case .function:
                func light(_ step: Int) -> Double { Self.sceneLight(cubeTone: Double(step) / last) }
                color = { red, green, blue in developed(scene: RGB(light(red), light(green), light(blue))) }
            case let .appleLog(side):
                let table = appleLogTable(side: side)
                color = { red, green, blue in
                    Self.tetrahedral(table, side: side, at: RGB(Double(red) / last, Double(green) / last, Double(blue) / last))
                }
            }
            for blue in 0..<dimension { for green in 0..<dimension { for red in 0..<dimension {
                let output = color(red, green, blue)
                let index = (blue * dimension + green) * dimension + red
                for (channel, value) in [output.red, output.green, output.blue].enumerated() {
                    let held = min(max(value, 0), 1)
                    let whole = min((held * 255).rounded(.down), 254)
                    steps[index * 4 + channel] = Float(whole / 255)
                    remainders[index * 4 + channel] = Float(held * 255 - whole)
                }
            } } }
            return Cube(dimension: dimension, steps: steps.withUnsafeBufferPointer { Data(buffer: $0) },
                        remainders: remainders.withUnsafeBufferPointer { Data(buffer: $0) })
        }

        /// The cube's tones a side: 64 for the function, which covers every light from none to six stops over middle
        /// gray, and twice the table's tones for a table.
        var cubeDimension: Int {
            switch table {
            case .function: 64
            case let .appleLog(side): 2 * side - 1
            }
        }

        /// The generator's table for this film: the picture for every mix of `side` Apple Log tones of red, green
        /// and blue, red varying fastest. These are the numbers the generator writes to its table file.
        func appleLogTable(side: Int) -> [RGB] {
            var table: [RGB] = []
            table.reserveCapacity(side * side * side)
            let last = Double(side - 1)
            for blue in 0..<side { for green in 0..<side { for red in 0..<side {
                table.append(developed(appleLog: RGB(Double(red) / last, Double(green) / last, Double(blue) / last)))
            } } }
            return table
        }

        /// A table read at one tone, each of whose parts runs from 0 to 1, tetrahedrally: the cell around the tone is
        /// cut into six tetrahedra along its diagonal from black to white, and the reading is the straight blend of
        /// the four corners of the one the tone is in.
        static func tetrahedral(_ table: [RGB], side: Int, at tone: RGB) -> RGB {
            func place(_ value: Double) -> (cell: Int, part: Double) {
                let position = min(max(value, 0), 1) * Double(side - 1)
                let cell = min(Int(position), side - 2)
                return (cell, position - Double(cell))
            }
            let red = place(tone.red), green = place(tone.green), blue = place(tone.blue)
            func corner(_ r: Int, _ g: Int, _ b: Int) -> RGB {
                table[((blue.cell + b) * side + green.cell + g) * side + red.cell + r]
            }
            // From black, the largest part is stepped along first, then the next, then the smallest, to white.
            let r = red.part, g = green.part, b = blue.part
            let first: RGB, second: RGB, weights: (Double, Double, Double, Double)
            if r > g {
                if g > b { first = corner(1, 0, 0); second = corner(1, 1, 0); weights = (1 - r, r - g, g - b, b) }
                else if r > b { first = corner(1, 0, 0); second = corner(1, 0, 1); weights = (1 - r, r - b, b - g, g) }
                else { first = corner(0, 0, 1); second = corner(1, 0, 1); weights = (1 - b, b - r, r - g, g) }
            } else {
                if b > g { first = corner(0, 0, 1); second = corner(0, 1, 1); weights = (1 - b, b - g, g - r, r) }
                else if b > r { first = corner(0, 1, 0); second = corner(0, 1, 1); weights = (1 - g, g - b, b - r, r) }
                else { first = corner(0, 1, 0); second = corner(1, 1, 0); weights = (1 - g, g - r, r - b, b) }
            }
            let black = corner(0, 0, 0), white = corner(1, 1, 1)
            return RGB(weights.0 * black.red + weights.1 * first.red + weights.2 * second.red + weights.3 * white.red,
                       weights.0 * black.green + weights.1 * first.green + weights.2 * second.green + weights.3 * white.green,
                       weights.0 * black.blue + weights.1 * first.blue + weights.2 * second.blue + weights.3 * white.blue)
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
            func through(_ rows: [[Double]], _ x: Double, _ y: Double, _ z: Double) -> (Double, Double, Double) {
                (rows[0][0] * x + rows[0][1] * y + rows[0][2] * z, rows[1][0] * x + rows[1][1] * y + rows[1][2] * z,
                 rows[2][0] * x + rows[2][1] * y + rows[2][2] * z)
            }
            let cones = through(Self.conesFromLight, red, green, blue)
            let long = cbrt(cones.0), medium = cbrt(cones.1), short = cbrt(cones.2)
            let lab = through(Self.labFromCones, long, medium, short)
            var lightness = lab.0
            let a = lab.1, b = lab.2
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
            // OKLab back to linear light, through the inverses of the two matrices.
            let roots = through(Self.conesFromLab, lightness, newA, newB)
            let back = through(Self.lightFromCones, pow(roots.0, 3), pow(roots.1, 3), pow(roots.2, 3))
            return RGB(back.0, back.1, back.2)
        }

        // OKLab's two matrices, as published, and their inverses, worked out from them as the generators do; the
        // published inverses are rounded, and would leave the picture a millionth off the generators'.
        private static let conesFromLight: [[Double]] = [
            [0.4122214708, 0.5363325363, 0.0514459929], [0.2119034982, 0.6806995451, 0.1073969566],
            [0.0883024619, 0.2817188376, 0.6299787005]
        ]
        private static let labFromCones: [[Double]] = [
            [0.2104542553, 0.7936177850, -0.0040720468], [1.9779984951, -2.4285922050, 0.4505937099],
            [0.0259040371, 0.7827717662, -0.8086757660]
        ]
        private static let lightFromCones = inverse(conesFromLight)
        private static let conesFromLab = inverse(labFromCones)

        /// The inverse of a matrix of three rows and three columns.
        static func inverse(_ m: [[Double]]) -> [[Double]] {
            let determinant = m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1]) - m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0])
                + m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0])
            func cofactor(_ row: Int, _ column: Int) -> Double {
                let r = [0, 1, 2].filter { $0 != row }, c = [0, 1, 2].filter { $0 != column }
                let minor = m[r[0]][c[0]] * m[r[1]][c[1]] - m[r[0]][c[1]] * m[r[1]][c[0]]
                return (row + column).isMultiple(of: 2) ? minor : -minor
            }
            return (0..<3).map { row in (0..<3).map { cofactor($0, row) / determinant } }
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
