import CoreGraphics
import Foundation

/// The shapes Adjust's crop box can keep, as the Photos app offers them (the captain, 2026-10-29, "2A"): the print's own
/// shape, any shape, a square, 4:3 and 3:2. The shape is the Darkroom's choice while it is open and is never stored: a
/// saved crop is only its rectangle, and the Darkroom reads the shape back from it (`CropGeometry.shape(of:printSize:)`).
public enum CropShape: String, CaseIterable, Sendable {
    case original = "Original", freeform = "Freeform", square = "Square", fourByThree = "4:3", threeByTwo = "3:2"

    /// Whether the shape can be sideways or upright: every shape with a ratio, except the square.
    public var turns: Bool { self == .original || self == .fourByThree || self == .threeByTwo }

    /// Width over height in pixels for a print of `printSize`, sideways or upright; nil for Freeform.
    public func ratio(printSize: CGSize, upright: Bool) -> Double? {
        let long: Double, short: Double
        switch self {
        case .freeform: return nil
        case .square: return 1
        case .original:
            long = max(printSize.width, printSize.height)
            short = min(printSize.width, printSize.height)
        case .fourByThree: (long, short) = (4, 3)
        case .threeByTwo: (long, short) = (3, 2)
        }
        return upright ? short / long : long / short
    }
}

/// Adjust's crop as the crop box works on it: a rectangle of the print as it is turned, in that print's pixels with y
/// down, the space `Crop` is a fraction of. The renderer cuts the crop first and then straightens what it cut, keeping
/// the largest centered rectangle of the crop's own shape (`StraighteningGeometry`), so the crop box shows that
/// rectangle: the crop's center and shape, `outputSize` big, turned by the straightening angle against the print.
public enum CropGeometry {
    /// The smallest side a crop can have, in pixels: a tenth of the print's shorter side.
    public static func minimumSide(printSize: CGSize) -> Double {
        min(printSize.width, printSize.height) / 10
    }

    /// The crop's rectangle in the turned print's pixels; the whole print where there is no crop.
    public static func rect(_ crop: Crop?, printSize: CGSize) -> CGRect {
        guard let crop else { return CGRect(origin: .zero, size: printSize) }
        return CGRect(x: crop.x * printSize.width, y: crop.y * printSize.height,
                      width: crop.width * printSize.width, height: crop.height * printSize.height)
    }

    /// The recipe's crop for `rect`: fractions of the print that the renderer's validation accepts as they are, never
    /// past an edge, equal on a `square` print (the 6×6, DEC-11), and nil where the rectangle is the whole print, which
    /// prints as no crop does.
    public static func crop(_ rect: CGRect, printSize: CGSize, square: Bool) -> Crop? {
        let tolerance = 1e-9
        var x = clamp(rect.minX / printSize.width), y = clamp(rect.minY / printSize.height)
        var width = rect.width / printSize.width, height = rect.height / printSize.height
        if x < tolerance { x = 0 }
        if y < tolerance { y = 0 }
        if x + width > 1 - tolerance { width = 1 - x }
        if y + height > 1 - tolerance { height = 1 - y }
        if square { width = min(width, height); height = width }
        while x + width > 1 { width = width.nextDown }
        while y + height > 1 { height = height.nextDown }
        if square { width = min(width, height); height = width }
        guard width > 0, height > 0 else { return nil }
        if x == 0, y == 0, width >= 1 - tolerance, height >= 1 - tolerance { return nil }
        return Crop(x: x, y: y, width: width, height: height)
    }

    /// What straightening leaves of a crop of `size`: the largest rectangle of its shape inside it turned by `degrees`.
    public static func outputSize(of size: CGSize, degrees: Double) -> CGSize {
        let kept = StraighteningGeometry.keptFraction(width: size.width, height: size.height, degrees: degrees)
        return CGSize(width: size.width * kept, height: size.height * kept)
    }

    /// The crop whose straightened print is `output` big about `center`: the crop is that rectangle enlarged by the part
    /// straightening keeps.
    public static func crop(center: CGPoint, output: CGSize, degrees: Double) -> CGRect {
        let kept = StraighteningGeometry.keptFraction(width: output.width, height: output.height, degrees: degrees)
        let size = CGSize(width: output.width / kept, height: output.height / kept)
        return CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
    }

    /// Whether a crop lies on the print, within a millionth of a pixel, and is no smaller than the smallest crop.
    public static func isValid(_ rect: CGRect, printSize: CGSize) -> Bool {
        let slack = 1e-6
        let smallest = minimumSide(printSize: printSize) - slack
        return rect.minX >= -slack && rect.minY >= -slack
            && rect.maxX <= printSize.width + slack && rect.maxY <= printSize.height + slack
            && rect.width >= smallest && rect.height >= smallest
    }

    /// A crop of `ratio` (width over height) about as big as `rect`: the same area, about the same center, made small
    /// enough to fit the print and moved onto it. A choice of shape starts from it, as a turn of the shape does.
    public static func reshaped(_ rect: CGRect, ratio: Double, printSize: CGSize) -> CGRect {
        let area = rect.width * rect.height
        var width = (area * ratio).squareRoot(), height = width / ratio
        let fit = min(1, printSize.width / width, printSize.height / height)
        width = min(width * fit, printSize.width)
        height = min(height * fit, printSize.height)
        let x = min(max(rect.midX - width / 2, 0), printSize.width - width)
        let y = min(max(rect.midY - height / 2, 0), printSize.height - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// The shape a saved crop has, for the Darkroom to show as chosen: the first shape whose ratio it has, within a
    /// millionth, and Freeform otherwise or without a crop. A crop with the print's own shape reads as Original, which a
    /// 3:2 crop of the Disposable's 3:2 print also is.
    public static func shape(of crop: Crop?, printSize: CGSize) -> (shape: CropShape, upright: Bool) {
        let landscape = printSize.width >= printSize.height
        guard let crop else { return (.freeform, !landscape) }
        let rect = rect(crop, printSize: printSize)
        let ratio = rect.width / rect.height
        for shape in CropShape.allCases {
            for upright in [false, true] {
                guard let candidate = shape.ratio(printSize: printSize, upright: upright),
                      abs(ratio / candidate - 1) < 1e-6 else { continue }
                return (shape, shape.turns ? upright : !landscape)
            }
        }
        return (.freeform, ratio < 1)
    }

    private static func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }
}
