import RenderCore
import SwiftUI
import UIKit
import XCTest
@testable import Immerse

/// Print Zoom's picture and Adjust's crop box (Evidence/NativeApp/print-zoom-and-crop-box-080.md): the print's sharper
/// picture where a zoom or a crop needs it, kept for the same print and through a turn of the iPhone, and the box's
/// Freeform corners.
@MainActor
final class PrintZoomTests: XCTestCase {
    /// The smallest supported iPhone, an iPhone SE (3rd generation): its screen's longer side in pixels, which a print is
    /// first decoded to, its Darkroom print area in points, and its pixels per point.
    private static let smallestScreenPixels = 1_334
    private static let smallestPrintArea = CGSize(width: 375, height: 221)
    private static let smallestDisplayScale: CGFloat = 2
    private static let printSize = CGSize(width: 3000, height: 2000)

    /// On Freeform a corner whose one edge cannot move, held at the print's edge or at the smallest crop, still moves its
    /// other edge with the finger, as in the Photos app, straightened too, where an edge's travel moves the crop along both
    /// sides of the print; on a shape both edges move together or not at all.
    func testAFreeformCornerHeldOnOneSideStillMovesItsOtherEdge() throws {
        let size = Self.printSize
        // The top edge cropped in, the left edge still on the print's left edge; the top-left corner dragged up, drifting
        // a little left past the print.
        let topCropped = editor(crop: Crop(x: 0, y: 0.3, width: 1, height: 0.7))
        let start = topCropped.resting(CropGeometry.rect(topCropped.crop, printSize: size), in: Self.smallestPrintArea)
        let raised = try XCTUnwrap(topCropped.handled(.topLeft, by: CGSize(width: -3, height: -30), from: start))
        XCTAssertEqual(raised.rect.minX, 0, accuracy: 1e-6, "The left edge stays on the print's")
        XCTAssertEqual(raised.rect.minY, 600 - 30 / start.scale, accuracy: 0.5, "The top edge follows the finger")
        XCTAssertEqual(raised.rect.maxY, size.height, accuracy: 1e-6)

        // As narrow as a crop can be: the corner dragged in and up narrows it no further and still moves its top edge.
        let narrowest = CropGeometry.minimumSide(printSize: size)
        let narrow = editor(crop: Crop(x: 0.4, y: 0.3, width: narrowest / size.width, height: 0.5))
        let narrowStart = narrow.resting(CropGeometry.rect(narrow.crop, printSize: size), in: Self.smallestPrintArea)
        let taller = try XCTUnwrap(narrow.handled(.topLeft, by: CGSize(width: 5, height: -20), from: narrowStart))
        XCTAssertEqual(taller.rect.width, narrowest, accuracy: 1e-3, "The crop narrows no further")
        XCTAssertEqual(taller.rect.minY, 600 - 20 / narrowStart.scale, accuracy: 0.5, "The top edge follows the finger")

        // Straightened 8°, the crop's top on the print's: the top-left corner dragged left and down follows the finger
        // both ways, and once the box is as short as it can be its left edge still does.
        let straightened = editor(crop: Crop(x: 500 / size.width, y: 0, width: 2000 / size.width, height: 0.8), degrees: 8)
        let tilted = straightened.resting(CropGeometry.rect(straightened.crop, printSize: size), in: Self.smallestPrintArea)
        let followed = try XCTUnwrap(straightened.handled(.topLeft, by: CGSize(width: -15, height: 20), from: tilted))
        XCTAssertEqual(followed.placement.box.minX, tilted.box.minX - 15, accuracy: 0.01, "The left edge follows the finger")
        XCTAssertEqual(followed.placement.box.minY, tilted.box.minY + 20, accuracy: 0.01, "The top edge follows the finger")
        let shortest = try XCTUnwrap(straightened.handled(.topLeft, by: CGSize(width: -15, height: 130), from: tilted))
        XCTAssertEqual(shortest.placement.box.minX, tilted.box.minX - 15, accuracy: 0.05, "The left edge still follows")
        XCTAssertEqual(shortest.placement.box.height, 64, accuracy: 0.01, "The box is as short as it can be")

        // A shape grows along its diagonal, which the print's left edge stops.
        let shaped = editor(crop: Crop(x: 0, y: 0.3, width: 1, height: 0.7), ratio: 3000.0 / 1400)
        XCTAssertNil(shaped.handled(.topLeft, by: CGSize(width: -3, height: -30), from: start))
    }

    /// Stepped a point at a time, as a drag's events come, a straightened Freeform corner goes on every event to the
    /// allowed position nearest the finger and follows the finger wherever it can: from an untouched print past where the
    /// whole drag stops being allowed, where two ways round a limit land equally near the finger, along the print's top
    /// with the finger drifting off it, and pushed straight out past a print edge the crop touches, where the positions
    /// the crop allows lie in a wedge narrower than the search's lines' spacing.
    func testAStraightenedFreeformCornerGoesWhereAllowedNearestTheFinger() {
        let size = Self.printSize
        let direction = CGVector(dx: 131.8, dy: -2.6)
        let length = hypot(direction.dx, direction.dy)
        let rightAndUp = (1...150).map {
            CGSize(width: direction.dx / length * CGFloat($0), height: direction.dy / length * CGFloat($0))
        }
        let downThenAcross = (1...38).map { CGSize(width: 0, height: CGFloat($0)) }
            + (1...60).map { CGSize(width: -CGFloat($0), height: 38 + CGFloat($0)) }
        let alongTheTop = (1...80).map { CGSize(width: CGFloat($0), height: -0.1 * CGFloat($0)) }

        let untouched = dragged(editor(crop: nil, degrees: 3), .bottomLeft, along: rightAndUp)
        let untouchedGap = hypot(untouched.corner.x - untouched.finger.x, untouched.corner.y - untouched.finger.y)
        XCTAssertLessThanOrEqual(untouchedGap, 3, "Past the limit the corner stays with the finger")
        _ = dragged(editor(crop: Crop(x: 0, y: 0, width: 1575 / size.width, height: 1133 / size.height), degrees: 3),
                    .bottomRight, along: downThenAcross)
        let alongTop = dragged(editor(crop: Crop(x: 0, y: 0, width: 0.6, height: 0.8), degrees: 3), .topLeft,
                               along: alongTheTop)
        XCTAssertEqual(alongTop.corner.x, alongTop.finger.x, accuracy: 1, "The left edge follows the finger along the top")

        let down = (1...130).map { CGSize(width: 0, height: CGFloat($0)) }
        let right = (1...130).map { CGSize(width: CGFloat($0), height: 0) }
        let sixDegreesDown = CGVector(dx: cos(CGFloat.pi / 30), dy: sin(CGFloat.pi / 30))
        let rightAndDown = (1...130).map {
            CGSize(width: sixDegreesDown.dx * CGFloat($0), height: sixDegreesDown.dy * CGFloat($0))
        }
        _ = dragged(editor(crop: nil, degrees: 3), .bottomRight, along: down)
        _ = dragged(editor(crop: Crop(x: 0.5, y: 0.5, width: 0.5, height: 0.5), degrees: -3), .topRight, along: right)
        _ = dragged(editor(crop: Crop(x: 0.4, y: 0.2, width: 0.6, height: 0.6), degrees: -8), .topRight, along: rightAndDown)
    }

    /// A Freeform corner whose box edge is held both ways, under the smallest box or at the smallest crop against a print
    /// edge, still follows the finger along the one line or narrow wedge the crop allows: the top-right corner of a strip
    /// along the print's top dragged left with the finger drifting up or down, the bottom-right corner of a strip at the
    /// print's right dragged up, the top-left corner of one at its left dragged down, and straightened, the bottom-right
    /// corner of a narrow crop at the print's right dragged up and the top-left corner of the smallest strip along its
    /// top dragged right.
    func testAFreeformCornerFollowsTheFingerAlongAnEdgeHeldBothWays() {
        let strip = 200 / Self.printSize.width
        for drift in [0.01, 0.1, -0.01, -0.1] as [CGFloat] {
            let left = dragged(editor(crop: Crop(x: 0, y: 0, width: 1, height: 0.25)), .topRight,
                               along: (1...100).map { CGSize(width: -CGFloat($0), height: drift * CGFloat($0)) })
            XCTAssertEqual(left.corner.x, left.finger.x, accuracy: 1, "The right edge follows the finger, drifting \(drift)")
        }
        _ = dragged(editor(crop: Crop(x: 1 - strip, y: 0.2, width: strip, height: 0.6)), .bottomRight,
                    along: (1...100).map { CGSize(width: -0.05 * CGFloat($0), height: -CGFloat($0)) })
        _ = dragged(editor(crop: Crop(x: 0, y: 0.2, width: strip, height: 0.6)), .topLeft,
                    along: (1...100).map { CGSize(width: 0.05 * CGFloat($0), height: CGFloat($0)) })
        _ = dragged(editor(crop: Crop(x: 0.915, y: 0.291, width: 0.085, height: 0.709), degrees: -0.32), .bottomRight,
                    along: (1...80).map { CGSize(width: -0.05 * CGFloat($0), height: -CGFloat($0)) })
        let down = CGVector(dx: cos(8.1 * CGFloat.pi / 180), dy: sin(8.1 * CGFloat.pi / 180))
        _ = dragged(editor(crop: Crop(x: 0, y: 0, width: 1, height: 0.1), degrees: 3), .topLeft,
                    along: (1...60).map { CGSize(width: down.dx * CGFloat($0), height: down.dy * CGFloat($0)) })
    }

    /// A corner dragged past the box's other side stops there, the box no smaller than it may be, and never turns the
    /// box inside out onto the other side: on Freeform the top-right corner of a narrow strip at the print's right
    /// dragged far left, and on a square the top-right corner of a crop in the print's middle dragged far down and left.
    func testACornerNeverTurnsTheBoxInsideOut() throws {
        let narrow = editor(crop: Crop(x: 0.9, y: 0.1, width: 0.1, height: 0.8))
        let narrowStart = narrow.resting(CropGeometry.rect(narrow.crop, printSize: Self.printSize),
                                         in: Self.smallestPrintArea)
        let across = try XCTUnwrap(narrow.handled(.topRight, by: CGSize(width: -100, height: 0), from: narrowStart))
        XCTAssertGreaterThan(across.placement.box.size.width, 0, "The box keeps its right edge right of its left")
        XCTAssertEqual(across.placement.box.minX, narrowStart.box.minX, accuracy: 1e-6, "Its left edge stays")
        let square = editor(crop: Crop(x: 0.4, y: 0.35, width: 0.2, height: 0.3), ratio: 1)
        let squareStart = square.resting(CropGeometry.rect(square.crop, printSize: Self.printSize),
                                         in: Self.smallestPrintArea)
        let side = squareStart.box.width
        let past = try XCTUnwrap(square.handled(.topRight, by: CGSize(width: -2 * side, height: 2 * side), from: squareStart))
        XCTAssertGreaterThan(past.placement.box.size.width, 0, "The square keeps its right edge right of its left")
        XCTAssertGreaterThan(past.placement.box.size.height, 0, "The square keeps its top above its bottom")
        XCTAssertEqual(past.placement.box.minX, squareStart.box.minX, accuracy: 1e-6, "Its left edge stays")
        XCTAssertEqual(past.placement.box.maxY, squareStart.box.maxY, accuracy: 1e-6, "Its bottom stays")
    }

    /// Random drags, from a fixed seed, of every corner of strips at the print's edges, some as narrow as a crop can be,
    /// at 0° and small straightening angles, each event held to the grid and to the lines along the box's and the
    /// print's edges, where a held edge leaves the crop allowing positions on a line no grid point need lie on.
    func testFreeformCornersOfStripsAtThePrintsEdgesGoWhereAllowedNearestTheFinger() {
        let narrowest = 200 / Self.printSize.width, narrow = 300 / Self.printSize.width
        let strips = [Crop(x: 0, y: 0, width: 1, height: 0.1), Crop(x: 0, y: 0, width: 1, height: 0.15),
                      Crop(x: 0, y: 0.9, width: 1, height: 0.1), Crop(x: 0, y: 0.85, width: 1, height: 0.15),
                      Crop(x: 0, y: 0.2, width: narrowest, height: 0.6), Crop(x: 0, y: 0.1, width: narrow, height: 0.8),
                      Crop(x: 1 - narrowest, y: 0.2, width: narrowest, height: 0.6),
                      Crop(x: 1 - narrow, y: 0.1, width: narrow, height: 0.8),
                      Crop(x: 0.3, y: 0, width: 0.4, height: 0.1), Crop(x: 0.2, y: 0.9, width: 0.5, height: 0.1)]
        let angles: [Double] = [0, 0.32, -0.32, 1, -1, 3, -3]
        let corners: [CropEditor.Handle] = [.topLeft, .topRight, .bottomRight, .bottomLeft]
        var random = SeededRandom(state: 20_261_031)
        for _ in 0..<30 {
            let crop = strips[Int(random.next() % UInt64(strips.count))]
            let degrees = angles[Int(random.next() % UInt64(angles.count))]
            let corner = corners[Int(random.next() % UInt64(corners.count))]
            let angle = CGFloat(random.next() % 36_000) / 36_000 * 2 * .pi
            _ = dragged(editor(crop: crop, degrees: degrees), corner,
                        along: (1...40).map { CGSize(width: cos(angle) * CGFloat($0), height: sin(angle) * CGFloat($0)) })
        }
    }

    /// A tight crop on the smallest supported iPhone shows the print at more pixels than its screen-sized picture has,
    /// so the crop box draws from the print's sharper picture; at the whole print the screen-sized one is enough and
    /// nothing sharper is decoded.
    func testATightCropOnTheSmallestIPhoneDrawsFromTheSharperPicture() async throws {
        let data = try developedPrint(.systemOrange)
        let scene = try await hostWindowScene()
        for crop in [nil, Crop(x: 0.35, y: 0.35, width: 0.3, height: 0.3)] {
            let screen = try screenPicture(data)
            let picture = ZoomedPicture()
            picture.show(data, image: screen, printSize: Self.printSize, reading: PrintZoomReading())
            let window = UIWindow(windowScene: scene)
            window.rootViewController = UIHostingController(rootView: editor(crop: crop, picture: picture)
                .frame(width: Self.smallestPrintArea.width, height: Self.smallestPrintArea.height)
                .environment(\.displayScale, Self.smallestDisplayScale))
            window.makeKeyAndVisible()
            defer { window.isHidden = true; window.rootViewController = nil }

            if crop == nil {
                try await Task.sleep(for: .milliseconds(500))
                XCTAssertTrue(picture.shown === screen, "The whole print draws from the screen-sized picture")
            } else {
                let sharp = try await sharpPicture(of: picture)
                XCTAssertEqual(pixels(sharp), Int(Self.printSize.width), "The tight crop draws from the print's own pixels")
            }
        }
    }

    /// The same print loaded again, as after another Film's Development, keeps its sharp picture and stays the same
    /// print, so the photo view keeps its zoom; other bytes are another print, shown screen-sized.
    func testTheSamePrintAgainKeepsItsSharpPictureAndAnotherStartsAnew() async throws {
        let data = try developedPrint(.systemOrange)
        let picture = ZoomedPicture()
        picture.show(data, image: try screenPicture(data), printSize: Self.printSize, reading: PrintZoomReading())
        let first = picture.generation
        picture.follow(PrintZoomReading(isZoomed: true, pixelsNeeded: Int(Self.printSize.width)))
        let sharp = try await sharpPicture(of: picture)

        picture.show(data, image: try screenPicture(data), printSize: Self.printSize, reading: PrintZoomReading())
        XCTAssertTrue(picture.shown === sharp, "The same print keeps its sharp picture")
        XCTAssertEqual(picture.generation, first, "The same print stays the print shown")

        let other = try developedPrint(.systemTeal)
        let otherScreen = try screenPicture(other)
        picture.show(other, image: otherScreen, printSize: Self.printSize, reading: PrintZoomReading())
        XCTAssertTrue(picture.shown === otherScreen, "Another print shows its screen-sized picture")
        XCTAssertNotEqual(picture.generation, first, "Another print is a new print shown")
    }

    /// A turn of the iPhone while zoomed in keeps the zoom and never reports the whole print on the way, which would let
    /// the sharp picture go and decode it again.
    func testATurnWhileZoomedInNeverReportsTheWholePrint() async throws {
        let scene = try await hostWindowScene()
        let window = UIWindow(windowScene: scene)
        let host = UIViewController()
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        let view = PrintZoomScrollView()
        view.frame = CGRect(x: 0, y: 0, width: 375, height: 600)
        host.view.addSubview(view)
        let readings = Readings()
        view.zoomed = { readings.all.append($0) }
        view.show(UIImage(), printSize: Self.printSize, cardEdge: false, whole: 0)
        view.zoomScale = 3
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(readings.all.last?.isZoomed, true, "Zoomed in")
        readings.all.removeAll()

        view.frame = CGRect(x: 0, y: 0, width: 600, height: 375)
        view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(view.zoomScale, 3, accuracy: 0.001, "The zoom survives the turn")
        XCTAssertFalse(readings.all.isEmpty, "The turned view reports what it needs")
        XCTAssertTrue(readings.all.allSatisfy(\.isZoomed), "Never the whole print on the way: \(readings.all)")
    }

    // MARK: Helpers

    private final class Readings {
        var all: [PrintZoomReading] = []
    }

    /// Steps `handle` along `path` as a drag's events come and holds every event to the rule: no allowed corner position
    /// of a grid a quarter point apart lies nearer the finger than the corner, nor any allowed point of the lines from
    /// where the corner began along the box's and the print's edges (`edgeLines`), on which a held edge can leave every
    /// allowed position, and the corner never moved more than the finger did and a point. Where the corner and the
    /// finger end. The check is on the distance: along a limit that curves almost as the circle round the finger does,
    /// positions far apart lie almost equally near it, which no grid tells apart, and nearest is a matter of distance.
    private func dragged(_ cropEditor: CropEditor, _ handle: CropEditor.Handle,
                         along path: [CGSize]) -> (corner: CGPoint, finger: CGPoint) {
        let start = cropEditor.resting(CropGeometry.rect(cropEditor.crop, printSize: Self.printSize),
                                       in: Self.smallestPrintArea)
        let held = handle.point(on: start.box)
        var corner = held, finger = held
        for travel in path {
            let next = CGPoint(x: held.x + travel.width, y: held.y + travel.height)
            guard let moved = cropEditor.handled(handle, by: travel, from: start) else {
                XCTFail("The \(handle) corner has nowhere to go at \(travel)")
                return (corner, next)
            }
            XCTAssertGreaterThan(moved.placement.box.size.width, 0, "The \(handle) corner keeps the box the right way out")
            XCTAssertGreaterThan(moved.placement.box.size.height, 0, "The \(handle) corner keeps the box the right way out")
            let point = handle.point(on: moved.placement.box)
            let gap = hypot(point.x - next.x, point.y - next.y)
            if let nearer = nearerOnGrid(cropEditor, handle, than: gap, to: travel, from: start) {
                XCTFail("At \(travel) the \(handle) corner is \(gap) from the finger, where the crop allows \(nearer)")
            }
            let onLines = edgeLines(turnedBy: cropEditor.degrees).compactMap { line -> CGFloat? in
                let along = max(line.width * travel.width + line.height * travel.height, 0)
                let onLine = CGSize(width: line.width * along, height: line.height * along)
                guard cropEditor.moved(start, handle: handle, by: onLine) != nil else { return nil }
                return hypot(travel.width - onLine.width, travel.height - onLine.height)
            }
            if let nearestOnLines = onLines.min() {
                XCTAssertLessThanOrEqual(gap, nearestOnLines + 0.001,
                                         "At \(travel) the \(handle) corner is farther from the finger than an edge line")
            }
            let fingerMoved = hypot(next.x - finger.x, next.y - finger.y)
            XCTAssertLessThanOrEqual(hypot(point.x - corner.x, point.y - corner.y), fingerMoved + 1,
                                     "The \(handle) corner jumps at \(travel)")
            corner = point
            finger = next
        }
        return (corner, finger)
    }

    /// The distance from the finger at `travel` to the nearest allowed corner position of a grid a quarter point apart
    /// round it that lies a hundredth of a point or more nearer than `distance`, or nil where none does. The positions the
    /// crop allows hold every straight line between two of them and where the corner began, which is no nearer the finger
    /// than `distance`, so any nearer one means some in the point just inside `distance` too, the only band of the grid
    /// looked at.
    private func nearerOnGrid(_ cropEditor: CropEditor, _ handle: CropEditor.Handle, than distance: CGFloat,
                              to travel: CGSize, from start: CropEditor.Placement) -> CGFloat? {
        let spacing: CGFloat = 0.25, outer = distance - 0.01, inner = max(outer - 1, 0)
        guard outer > 0 else { return nil }
        var nearest: CGFloat?
        let columns = Int((outer / spacing).rounded(.down))
        for column in -columns...columns {
            let x = CGFloat(column) * spacing
            let farthest = (outer * outer - x * x).squareRoot()
            let closest = abs(x) < inner ? (inner * inner - x * x).squareRoot() : 0
            let rows = stride(from: Int((closest / spacing).rounded(.up)),
                              through: Int((farthest / spacing).rounded(.down)), by: 1)
            for row in rows {
                for y in row == 0 ? [CGFloat(0)] : [CGFloat(row) * spacing, -CGFloat(row) * spacing] {
                    let gap = hypot(x, y)
                    guard gap >= inner, gap < outer, gap < (nearest ?? .infinity) else { continue }
                    let position = CGSize(width: travel.width + x, height: travel.height + y)
                    if cropEditor.moved(start, handle: handle, by: position) != nil { nearest = gap }
                }
            }
        }
        return nearest
    }

    /// The directions from where a corner began along the box's edges, the axes, and along the print's as the box shows
    /// them, the axes turned by `degrees` either way.
    private func edgeLines(turnedBy degrees: Double) -> [CGSize] {
        let radians = CGFloat(degrees) * .pi / 180
        let cosine = cos(radians), sine = sin(radians)
        var lines: [CGSize] = []
        for axis in [CGSize(width: 1, height: 0), CGSize(width: 0, height: 1), CGSize(width: -1, height: 0),
                     CGSize(width: 0, height: -1)] {
            lines.append(axis)
            lines.append(CGSize(width: axis.width * cosine - axis.height * sine,
                                height: axis.width * sine + axis.height * cosine))
            lines.append(CGSize(width: axis.width * cosine + axis.height * sine,
                                height: axis.height * cosine - axis.width * sine))
        }
        return lines
    }

    /// SplitMix64, so the random drags are the same on every run.
    private struct SeededRandom {
        var state: UInt64

        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var mixed = state
            mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
            mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
            return mixed ^ (mixed >> 31)
        }
    }

    private func editor(crop: Crop?, degrees: Double = 0, ratio: Double? = nil,
                        picture: ZoomedPicture = ZoomedPicture()) -> CropEditor {
        CropEditor(print: UncroppedPrint(recipe: .original, picture: picture, pixelSize: Self.printSize), quarterTurns: 0,
                   crop: crop, degrees: degrees, ratio: ratio, square: false, dialing: false) { _ in }
    }

    /// A print of `printSize` in one color with a pattern, as a JPEG.
    private func developedPrint(_ color: UIColor) throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: Self.printSize, format: format).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: Self.printSize))
            UIColor.black.setFill()
            for column in stride(from: 0, to: Self.printSize.width, by: 100) {
                context.fill(CGRect(x: column, y: 0, width: 10, height: Self.printSize.height))
            }
        }
        return try XCTUnwrap(image.jpegData(compressionQuality: 0.8))
    }

    /// The print decoded to the smallest supported iPhone's screen, as the app first shows it.
    private func screenPicture(_ data: Data) throws -> UIImage {
        try XCTUnwrap(DisplayPhoto.image(data, maximumPixels: Self.smallestScreenPixels))
    }

    private func pixels(_ image: UIImage?) -> Int {
        guard let image else { return 0 }
        return Int(max(image.size.width, image.size.height) * image.scale)
    }

    /// The picture shown once it has more pixels than the screen-sized one.
    private func sharpPicture(of picture: ZoomedPicture) async throws -> UIImage {
        for _ in 0..<200 where pixels(picture.shown) <= Self.smallestScreenPixels {
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertGreaterThan(pixels(picture.shown), Self.smallestScreenPixels, "A sharper picture is decoded")
        return try XCTUnwrap(picture.shown)
    }
}
