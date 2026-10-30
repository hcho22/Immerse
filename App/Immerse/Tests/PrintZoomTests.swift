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
    /// whole drag stops being allowed, where two ways round a limit land equally near the finger, and along the print's
    /// top with the finger drifting off it.
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

    /// Steps `handle` along `path` as a drag's events come and holds every event to the rule: the corner within a point of
    /// the allowed position nearest the finger, and never moved more than the finger did and a point. Where the corner
    /// and the finger end.
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
            let point = handle.point(on: moved.placement.box)
            let nearest = nearestAllowed(cropEditor, handle, to: travel, from: start)
            XCTAssertLessThanOrEqual(hypot(point.x - held.x - nearest.width, point.y - held.y - nearest.height), 1,
                                     "The \(handle) corner at \(travel) is where the crop allows it nearest the finger")
            let fingerMoved = hypot(next.x - finger.x, next.y - finger.y)
            XCTAssertLessThanOrEqual(hypot(point.x - corner.x, point.y - corner.y), fingerMoved + 1,
                                     "The \(handle) corner jumps at \(travel)")
            corner = point
            finger = next
        }
        return (corner, finger)
    }

    /// The travel to the allowed corner position nearest the finger, by brute force: the finger itself where the crop
    /// allows it there, otherwise the nearest point of the allowed part of each straight line from where the corner
    /// began, every half degree and then every four hundredth of a degree either side of the nearest line, since the
    /// allowed position nearest the finger can lie in a wedge narrower than half a degree.
    private func nearestAllowed(_ cropEditor: CropEditor, _ handle: CropEditor.Handle, to travel: CGSize,
                                from start: CropEditor.Placement) -> CGSize {
        func allowed(_ travel: CGSize) -> Bool { cropEditor.moved(start, handle: handle, by: travel) != nil }
        if allowed(travel) { return travel }
        let reach = 2 * hypot(travel.width, travel.height)
        func nearest(along angle: CGFloat) -> (distance: CGFloat, travel: CGSize) {
            let direction = CGSize(width: cos(angle), height: sin(angle))
            var low: CGFloat = 0, high = reach
            for _ in 0..<26 {
                let middle = (low + high) / 2
                let part = CGSize(width: direction.width * middle, height: direction.height * middle)
                if allowed(part) { low = middle } else { high = middle }
            }
            let along = min(max(direction.width * travel.width + direction.height * travel.height, 0), low)
            let point = CGSize(width: direction.width * along, height: direction.height * along)
            return (hypot(travel.width - point.width, travel.height - point.height), point)
        }
        let halfDegree = CGFloat.pi / 360
        let lines = (0..<720).map { nearest(along: CGFloat($0) * halfDegree) }
        var best = 0
        for line in lines.indices where lines[line].distance < lines[best].distance { best = line }
        var chosen = lines[best]
        for fine in 0...400 {
            let candidate = nearest(along: (CGFloat(best - 1) + CGFloat(fine) / 200) * halfDegree)
            if candidate.distance < chosen.distance { chosen = candidate }
        }
        return chosen.travel
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
