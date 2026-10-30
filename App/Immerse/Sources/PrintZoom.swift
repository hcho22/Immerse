import ImageIO
import SwiftUI
import UIKit

/// Print Zoom (the captain, 2026-10-29, "1A" and "3A"): looking closer at a developed print as in the iPhone's Photos app,
/// in the photo view and on every Darkroom tool but Adjust. Pinch, or double-tap at a point, to zoom in; double-tap again
/// to see the whole print; drag to look around, with the Photos app's resistance at the edges and its settling. It only
/// changes what is shown, never the print. A scroll view does the zooming, as in the Photos app.
///
/// `image` is the picture shown, whatever its pixels; `printSize`, the print's own size in pixels, lays it out and sets
/// the furthest zoom, so a sharper picture of the same print can replace a screen-sized one without moving anything. A
/// new `printSize` or `whole` shows the whole print again. `swipe`, where given, is called with -1 or 1 for a sideways
/// swipe while the whole print shows, and never while zoomed in, when a drag looks around.
struct PrintZoom: UIViewRepresentable {
    let image: UIImage?
    let printSize: CGSize
    /// Sets an Instant print's white card apart from the screen in light and dark appearance: a margin, a hairline edge
    /// and a soft shadow, which zoom with the print. The thumbnails draw the hairline alone (`PrintCardEdge`).
    var cardEdge = false
    /// A change shows the whole print again.
    var whole: AnyHashable = 0
    /// Whether the print zooms at all: Adjust shows an Instant print, which it only turns, in the same place unzoomed.
    var zooms = true
    var swipe: ((Int) -> Void)?
    /// Told how the zoom stands once it settles, and at once whenever the whole print comes or goes.
    var zoomed: (PrintZoomReading) -> Void = { _ in }

    func makeUIView(context: Context) -> PrintZoomScrollView { PrintZoomScrollView() }

    func updateUIView(_ view: PrintZoomScrollView, context: Context) {
        view.swipe = swipe
        view.zoomed = zoomed
        view.zooms = zooms
        view.show(image, printSize: printSize, cardEdge: cardEdge, whole: whole)
    }
}

/// How a Print Zoom stands, or Adjust's crop box at rest.
struct PrintZoomReading: Equatable {
    /// Whether the view shows less than the whole print.
    var isZoomed = false
    /// How many pixels along the print's longer side the shown size needs to look sharp on this screen.
    var pixelsNeeded = 0
}

final class PrintZoomScrollView: UIScrollView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    var swipe: ((Int) -> Void)? { didSet { updateGestures() } }
    var zoomed: (PrintZoomReading) -> Void = { _ in }
    var zooms = true {
        didSet {
            guard zooms != oldValue else { return }
            doubleTap.isEnabled = zooms
            pinchGestureRecognizer?.isEnabled = zooms
            if !zooms { layOut(keepingZoom: false) }
        }
    }

    /// What zooms: the print and, on an Instant, its margin.
    private let card = UIView()
    private let picture = UIImageView()
    private var printSize = CGSize.zero
    private var cardEdge = false
    private var whole: AnyHashable?
    private var laidOutSize = CGSize.zero
    private var reading = PrintZoomReading()
    /// Holds back reports while the view lays itself out, which passes through zoom 1 on the way to the zoom it keeps.
    private var layingOut = false
    private let pager = UIPanGestureRecognizer()
    private let doubleTap = UITapGestureRecognizer()

    /// The Instant card's margin at the whole print, in points.
    private static let cardMargin: CGFloat = 16
    /// The zoom past which the view counts as zoomed in.
    private static let wholeScale: CGFloat = 1.01

    init() {
        super.init(frame: .zero)
        delegate = self
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        decelerationRate = .fast
        bouncesZoom = true
        minimumZoomScale = 1
        maximumZoomScale = 1
        clipsToBounds = true
        addSubview(card)
        card.addSubview(picture)
        picture.contentMode = .scaleToFill
        picture.layer.shadowOffset = CGSize(width: 0, height: 1)
        picture.layer.shadowRadius = 5
        isAccessibilityElement = false

        pager.maximumNumberOfTouches = 1
        pager.delegate = self
        pager.addTarget(self, action: #selector(paged(_:)))
        addGestureRecognizer(pager)
        doubleTap.numberOfTapsRequired = 2
        doubleTap.addTarget(self, action: #selector(doubleTapped(_:)))
        addGestureRecognizer(doubleTap)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: Self, _: UITraitCollection) in
            view.drawCardEdge()
        }
        updateGestures()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(_ image: UIImage?, printSize: CGSize, cardEdge: Bool, whole: AnyHashable) {
        if picture.image !== image { picture.image = image }
        let layoutChanged = printSize != self.printSize || cardEdge != self.cardEdge
        let reset = whole != self.whole
        self.printSize = printSize
        self.cardEdge = cardEdge
        self.whole = whole
        drawCardEdge()
        if layoutChanged || reset { layOut(keepingZoom: false) }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.size != laidOutSize { layOut(keepingZoom: true) }
    }

    /// Fits the whole print to the view at zoom 1. A new size of view, as the iPhone turns, keeps the zoom and the point
    /// at the middle of the view, within the new limits.
    private func layOut(keepingZoom: Bool) {
        laidOutSize = bounds.size
        guard bounds.width > 0, bounds.height > 0, printSize.width > 0, printSize.height > 0 else { return }
        let margin = cardEdge ? Self.cardMargin : 0
        let room = CGSize(width: max(bounds.width - 2 * margin, 1), height: max(bounds.height - 2 * margin, 1))
        let fit = min(room.width / printSize.width, room.height / printSize.height)
        let fitted = CGSize(width: printSize.width * fit, height: printSize.height * fit)

        let previousScale = zoomScale
        let middle = keepingZoom && card.bounds.width > 0
            ? CGPoint(x: (contentOffset.x + bounds.width / 2) / (card.bounds.width * previousScale),
                      y: (contentOffset.y + bounds.height / 2) / (card.bounds.height * previousScale))
            : CGPoint(x: 0.5, y: 0.5)
        layingOut = true
        zoomScale = 1
        card.frame = CGRect(x: 0, y: 0, width: fitted.width + 2 * margin, height: fitted.height + 2 * margin)
        picture.frame = card.bounds.insetBy(dx: margin, dy: margin)
        picture.layer.shadowPath = cardEdge ? UIBezierPath(rect: picture.bounds).cgPath : nil
        contentSize = card.frame.size
        // At the furthest zoom a pixel of the print covers two of the screen's, and never less than three times the whole.
        let screenScale = window?.screen.scale ?? traitCollection.displayScale
        maximumZoomScale = zooms
            ? max(3, max(printSize.width, printSize.height) / (max(fitted.width, fitted.height) * screenScale) * 2) : 1
        let scale = keepingZoom ? min(max(previousScale, 1), maximumZoomScale) : 1
        zoomScale = scale
        centerCard()
        if scale > 1 {
            let size = card.frame.size
            contentOffset = CGPoint(
                x: min(max(middle.x * size.width - bounds.width / 2, 0), max(size.width - bounds.width, 0)),
                y: min(max(middle.y * size.height - bounds.height / 2, 0), max(size.height - bounds.height, 0)))
        }
        layingOut = false
        report(settled: true)
    }

    /// Keeps a print smaller than the view in its middle.
    private func centerCard() {
        let horizontal = max((bounds.width - contentSize.width) / 2, 0)
        let vertical = max((bounds.height - contentSize.height) / 2, 0)
        contentInset = UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
    }

    private func drawCardEdge() {
        let layer = picture.layer
        if cardEdge {
            layer.borderWidth = 0.5
            layer.borderColor = UIColor.label.withAlphaComponent(0.22).resolvedColor(with: traitCollection).cgColor
            layer.shadowColor = UIColor.label.resolvedColor(with: traitCollection).cgColor
            layer.shadowOpacity = 0.28
        } else {
            layer.borderWidth = 0
            layer.shadowOpacity = 0
        }
    }

    /// The whole print swipes to the next or previous one; zoomed in, a drag looks around instead.
    private func updateGestures() {
        let isZoomed = zoomScale > Self.wholeScale
        panGestureRecognizer.isEnabled = isZoomed
        pager.isEnabled = !isZoomed && swipe != nil
    }

    private func report(settled: Bool) {
        guard !layingOut else { return }
        let isZoomed = zoomScale > Self.wholeScale
        updateGestures()
        let screenScale = window?.screen.scale ?? traitCollection.displayScale
        let longest = max(picture.bounds.width, picture.bounds.height) * zoomScale * screenScale
        let next = PrintZoomReading(isZoomed: isZoomed, pixelsNeeded: Int(longest.rounded(.up)))
        guard next != reading, settled || next.isZoomed != reading.isZoomed else { return }
        reading = next
        // Told after the update that laid the view out, which SwiftUI's state may not change during.
        let zoomed = zoomed
        DispatchQueue.main.async { zoomed(next) }
    }

    @objc private func paged(_ recognizer: UIPanGestureRecognizer) {
        guard recognizer.state == .ended, let swipe else { return }
        let travel = recognizer.translation(in: self)
        guard abs(travel.x) > abs(travel.y), abs(travel.x) >= 48 else { return }
        swipe(travel.x < 0 ? 1 : -1)
    }

    /// Zooms in at the tapped point, as far as the print fills the view and at least twice; zoomed in, shows it whole.
    @objc private func doubleTapped(_ recognizer: UITapGestureRecognizer) {
        guard printSize.width > 0 else { return }
        if zoomScale > Self.wholeScale {
            setZoomScale(1, animated: true)
            return
        }
        let fill = max(bounds.width / card.bounds.width, bounds.height / card.bounds.height)
        let scale = min(max(fill, 2), maximumZoomScale)
        let point = recognizer.location(in: card)
        let size = CGSize(width: bounds.width / scale, height: bounds.height / scale)
        zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height),
             animated: true)
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { card }

    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        // A pinch is never a swipe, even where one finger landed first.
        pager.isEnabled = false
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerCard()
        report(settled: false)
    }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        report(settled: true)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        gestureRecognizer === pager && otherGestureRecognizer === doubleTap
    }
}

extension DisplayPhoto {
    /// A print's size in pixels as it shows, its orientation applied.
    nonisolated static func pixelSize(_ data: Data) -> CGSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
        let turned = ((properties[kCGImagePropertyOrientation] as? Int) ?? 1) > 4
        return turned ? CGSize(width: height, height: width) : CGSize(width: width, height: height)
    }
}

/// A print's picture for Print Zoom and for Adjust's crop box: screen-sized at first, and as sharp as the print once a
/// zoom, or a crop box showing a small part of the print, needs more pixels than that. The sharper picture is decoded off
/// the main actor and let go as the zoom returns to the whole print, which keeps memory low on the oldest supported
/// iPhone.
@MainActor @Observable
final class ZoomedPicture {
    /// The picture to show.
    private(set) var shown: UIImage?
    private(set) var printSize = CGSize.zero
    /// Counts the prints shown, so a sharper picture decoded for an earlier one is never shown, and a view can show each
    /// new print whole.
    private(set) var generation = 0
    @ObservationIgnored private var data: Data?
    @ObservationIgnored private var screen: UIImage?
    @ObservationIgnored private var sharp = false
    @ObservationIgnored private var detailTask: Task<Void, Never>?

    /// Shows a newly made or loaded print: its screen-sized picture, then a sharper one if the zoom needs it. The same
    /// print again, its bytes unchanged, keeps the picture shown, sharp or not.
    func show(_ data: Data, image: UIImage, printSize: CGSize, reading: PrintZoomReading) {
        guard data != self.data else { return }
        detailTask?.cancel()
        detailTask = nil
        generation += 1
        self.data = data
        self.printSize = printSize
        screen = image
        shown = image
        sharp = false
        follow(reading)
    }

    func clear() {
        detailTask?.cancel()
        detailTask = nil
        generation += 1
        data = nil
        screen = nil
        shown = nil
        printSize = .zero
        sharp = false
    }

    /// Decodes the print at its own pixels once the zoom needs more than the screen-sized picture has, or goes back to
    /// that picture at the whole print.
    func follow(_ reading: PrintZoomReading) {
        guard let data, let screen else { return }
        let screenPixels = Int(max(screen.size.width, screen.size.height) * screen.scale)
        let full = Int(max(printSize.width, printSize.height))
        guard reading.isZoomed, reading.pixelsNeeded > screenPixels, full > screenPixels else {
            if !reading.isZoomed {
                detailTask?.cancel()
                detailTask = nil
                if sharp { shown = screen; sharp = false }
            }
            return
        }
        guard !sharp, detailTask == nil else { return }
        let made = generation
        detailTask = Task { [weak self] in
            let detail = await Task.detached(priority: .userInitiated) { DisplayPhoto.image(data, maximumPixels: full) }.value
            guard let self, !Task.isCancelled, self.generation == made, let detail else { return }
            self.shown = detail
            self.sharp = true
            self.detailTask = nil
        }
    }
}
