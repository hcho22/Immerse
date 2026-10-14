import CoreImage
import FilmDomain
import Foundation
@testable import RenderCore
import XCTest

/// The Darkroom's chemical toners (`ToningLook`): their arithmetic, and that a recipe's amount reaches it through
/// each toner's own range.
final class ToningLookTests: XCTestCase {
    private static let linear = CGColorSpace(name: CGColorSpace.linearSRGB)!
    private let context = CIContext(options: [.workingColorSpace: ToningLookTests.linear, .cacheIntermediates: false])

    /// Selenium's blend through the inverted print is, on every tone and at every strength its range gives, the
    /// arithmetic its comment states: each channel's light x becomes x * (1 + strength * (1 - x) * (tint - 1)).
    func testSeleniumIsTheArithmeticItStates() {
        let tint = ToningLook.seleniumTint
        for strength in [0.25, 0.5, 0.75, 1] {
            for step in 0...20 {
                let x = Double(step) / 20
                let toned = light(ToningLook.toned(Self.gray(x), with: .selenium, strength: strength))
                for (channel, tint) in [tint.red, tint.green, tint.blue].enumerated() {
                    XCTAssertEqual(toned[channel], x * (1 + strength * (1 - x) * (tint - 1)), accuracy: 0.00001,
                                   "strength \(strength), tone \(step)")
                }
            }
        }
    }

    /// Selenium is purple, weighted to the darker tones, and leaves both black and the paper's white where they are.
    func testSeleniumTintsTheDarkerTonesPurpleAndLeavesBlackAndWhiteAlone() {
        for strength in [1.0, ToningLook.selenium.top] {
            let black = light(ToningLook.toned(Self.gray(0), with: .selenium, strength: strength))
            let white = light(ToningLook.toned(Self.gray(1), with: .selenium, strength: strength))
            for channel in 0..<3 {
                XCTAssertEqual(black[channel], 0, accuracy: 0.0001)
                XCTAssertEqual(white[channel], 1, accuracy: 0.0001)
            }
            let shadow = light(ToningLook.toned(Self.gray(0.1), with: .selenium, strength: strength))
            let highlight = light(ToningLook.toned(Self.gray(0.9), with: .selenium, strength: strength))
            XCTAssertGreaterThan(shadow[0], shadow[1], "Red over green in the shadows")
            XCTAssertGreaterThan(shadow[2], shadow[1], "Blue over green in the shadows")
            XCTAssertGreaterThan((shadow[0] - shadow[1]) / 0.1, (highlight[0] - highlight[1]) / 0.9, "More of it in the shadows")
        }
    }

    /// Sepia is a warm brown: red over green over blue through the middle tones, black left black.
    func testSepiaIsAWarmBrown() {
        let strength = ToningLook.sepia.top
        let black = light(ToningLook.toned(Self.gray(0), with: .sepia, strength: strength))
        XCTAssertEqual(black.max()!, 0, accuracy: 0.0001)
        for tone in [0.1, 0.3, 0.5, 0.7] {
            let toned = light(ToningLook.toned(Self.gray(tone), with: .sepia, strength: strength))
            XCTAssertGreaterThan(toned[0], toned[1], "tone \(tone)")
            XCTAssertGreaterThan(toned[1], toned[2], "tone \(tone)")
        }
    }

    /// The captain chose each toner's range on the toning comparison board on 2026-10-13: "sepia - untoned to 1.
    /// selenium - untoned to 1". Both sliders start at the untoned print and top out at the strength the board showed
    /// as 1.00.
    func testEachTonersRangeIsTheOneTheCaptainChose() {
        XCTAssertEqual(ToningLook.sepia, ToningLook.Toner(start: 0, top: 1))
        XCTAssertEqual(ToningLook.selenium, ToningLook.Toner(start: 0, top: 1))
        // At the slider's low end a toned recipe prints the untoned print.
        for chemistry in ChemicalToning.Chemistry.allCases {
            for tone in [0.05, 0.3, 0.8] {
                let untoned = light(ToningLook.apply(ChemicalToning(chemistry: chemistry, amount: 0), to: Self.gray(tone)))
                for channel in 0..<3 { XCTAssertEqual(untoned[channel], tone, accuracy: 0.0005, "\(chemistry) at \(tone)") }
            }
        }
    }

    /// Each toner at the top of its slider, as the board showed it at 1.00: the light of five neutral tones, recorded
    /// from that build's renders. Sepia is Core Image's own filter, so this is what holds it to the look he chose on
    /// every renderer the tests run on, the iOS simulator's among them.
    func testEachTonerAtItsTopIsTheOneTheBoardShowed() {
        let recorded: [ChemicalToning.Chemistry: [(tone: Double, light: [Double])]] = [
            .sepia: [(0.02, [0.0479, 0.0148, 0.0004]), (0.18, [0.2612, 0.1530, 0.0351]), (0.5, [0.5823, 0.4664, 0.2439]),
                     (0.8, [0.8393, 0.7774, 0.6006]), (1, [1.0007, 0.9890, 0.9206])],
            .selenium: [(0.02, [0.02078, 0.01882, 0.02039]), (0.18, [0.18590, 0.17114, 0.18295]), (0.5, [0.51, 0.485, 0.505]),
                        (0.8, [0.8064, 0.7904, 0.8032]), (1, [1, 1, 1])]
        ]
        for (chemistry, tones) in recorded {
            for (tone, expected) in tones {
                let toned = light(ToningLook.apply(ChemicalToning(chemistry: chemistry, amount: 1), to: Self.gray(tone)))
                for channel in 0..<3 {
                    XCTAssertEqual(toned[channel], expected[channel], accuracy: 0.002, "\(chemistry) at \(tone), channel \(channel)")
                }
            }
        }
    }

    /// A recipe's amount is where the slider stands: its low end is the toner's start and its top the toner's top,
    /// evenly between.
    func testARecipesAmountRunsFromTheTonersStartToItsTop() {
        for chemistry in ChemicalToning.Chemistry.allCases {
            let toner = ToningLook.toner(chemistry)
            XCTAssertLessThan(toner.start, toner.top, "\(chemistry)")
            XCTAssertGreaterThanOrEqual(toner.start, 0, "\(chemistry)")
            XCTAssertEqual(ToningLook.strength(ChemicalToning(chemistry: chemistry, amount: 0)), toner.start, accuracy: 1e-12)
            XCTAssertEqual(ToningLook.strength(ChemicalToning(chemistry: chemistry, amount: 1)), toner.top, accuracy: 1e-12)
            XCTAssertEqual(ToningLook.strength(ChemicalToning(chemistry: chemistry, amount: 0.5)), (toner.start + toner.top) / 2,
                           accuracy: 1e-12)
            // The recipe's print is the toner at that strength.
            let gray = Self.gray(0.3)
            let recipe = light(ToningLook.apply(ChemicalToning(chemistry: chemistry, amount: 0.5), to: gray))
            let direct = light(ToningLook.toned(gray, with: chemistry, strength: (toner.start + toner.top) / 2))
            XCTAssertEqual(recipe, direct, "\(chemistry)")
        }
    }

    private static func gray(_ level: Double) -> CIImage {
        CIImage(color: CIColor(red: level, green: level, blue: level, colorSpace: linear)!)
            .cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    /// One pixel's red, green and blue as linear light.
    private func light(_ image: CIImage) -> [Double] {
        var pixel = [Float](repeating: 0, count: 4)
        context.render(image, toBitmap: &pixel, rowBytes: 16, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBAf, colorSpace: Self.linear)
        return pixel.prefix(3).map(Double.init)
    }
}
