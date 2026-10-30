import RenderCore
import SwiftUI

/// Adjust's crop box, as the Photos app crops (the captain, 2026-10-29, "2A" and "8A"). The box shows what the print will
/// be, with the rest of the print dimmed around it. Its corner and edge handles resize it over a still print; a pinch or a
/// drag on the print moves and scales the print under a still box; a rule-of-thirds grid shows while either moves; and
/// after a handle is let go the box re-centers and grows to fill the print area again, the print with it. The print always
/// covers the box: past an edge or a size limit it resists and then settles back.
///
/// The renderer crops the turned print and then straightens what it cut, keeping the largest centered rectangle of its
/// shape (`CropGeometry`), so the box is that rectangle: the print under it turns by the straightening angle about the
/// box's center and grows as the angle grows. Nothing here renders: the print shown is the one without crop,
/// straightening, vignette or quarter turns (`UncroppedPrint`), placed by the recipe's crop and turned by its angle, and
/// drawn from its sharper picture where the box at rest shows it at more pixels than the screen-sized one has.
struct CropEditor: View {
    let print: UncroppedPrint
    let quarterTurns: Int
    let crop: Crop?
    let degrees: Double
    /// Width over height the box keeps, in the print's pixels; nil for Freeform.
    let ratio: Double?
    /// The 6×6, whose crop stays square (DEC-11).
    let square: Bool
    /// Shows the grid while the straighten dial moves.
    let dialing: Bool
    /// A new crop, once a gesture or an accessibility action ends.
    let commit: (Crop?) -> Void

    /// Where the box and the print are while a gesture moves them; nil at rest, where they follow the crop.
    @State private var live: Placement?
    @State private var liveRect: CGRect?
    /// Where the box was as a gesture began.
    @State private var gestureStart: Placement?
    /// Whether a handle or the print is held. A gesture that is cancelled never ends, and the box settles as this goes
    /// false.
    @GestureState private var moving = false
    @Environment(\.displayScale) private var displayScale

    /// Room left around the box for its handles.
    private static let margin: CGFloat = 24
    /// The smallest box a handle drag leaves, in points.
    private static let smallestBox: CGFloat = 64
    /// How far past a limit a gesture goes for each point the finger moves past it.
    private static let resistance: CGFloat = 0.3
    /// How many straight lines from where a Freeform corner began the allowed position nearest the finger is looked for
    /// along, before it is refined between two of them.
    private static let nearestLines = 64

    /// The box on the screen, how many points a pixel of the print covers, and the pixel of the turned print at the box's
    /// center.
    struct Placement: Equatable {
        var box: CGRect
        var scale: CGFloat
        var center: CGPoint
    }

    private var printSize: CGSize {
        quarterTurns % 2 == 0 ? print.pixelSize : CGSize(width: print.pixelSize.height, height: print.pixelSize.width)
    }

    private var rect: CGRect { liveRect ?? CropGeometry.rect(crop, printSize: printSize) }

    var body: some View {
        GeometryReader { geometry in
            let placement = live ?? resting(rect, in: geometry.size)
            ZStack(alignment: .topLeading) {
                Color.clear.contentShape(Rectangle()).gesture(pictureGesture(in: geometry.size))
                picture(placement)
                dimming(placement, in: geometry.size)
                frame(placement)
                handles(placement, in: geometry.size)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .onChange(of: reading(in: geometry.size, displayScale: displayScale), initial: true) { _, reading in
                print.picture.follow(reading)
            }
        }
        .onChange(of: moving) { _, moving in if !moving, gestureStart != nil { endGesture() } }
        .onDisappear { print.picture.follow(PrintZoomReading()) }
        .accessibilityElement(children: .contain)
    }

    /// What the box at rest needs of the print's picture: the whole print's longer side at the box's scale, in this
    /// screen's pixels, and whether the box shows less than the whole print.
    private func reading(in size: CGSize, displayScale: CGFloat) -> PrintZoomReading {
        let scale = resting(CropGeometry.rect(crop, printSize: printSize), in: size).scale
        let needed = max(print.pixelSize.width, print.pixelSize.height) * scale * displayScale
        return PrintZoomReading(isZoomed: crop != nil || degrees != 0, pixelsNeeded: Int(needed.rounded(.up)))
    }

    // MARK: Drawing

    /// The print placed so that its pixel `placement.center` is at the box's center, turned by its quarter turns and the
    /// straightening angle.
    @ViewBuilder private func picture(_ placement: Placement) -> some View {
        if let image = print.picture.shown {
            Image(uiImage: image).resizable()
                .frame(width: print.pixelSize.width * placement.scale, height: print.pixelSize.height * placement.scale)
                .rotationEffect(.degrees(-90 * Double(quarterTurns) - degrees))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .position(screen(CGPoint(x: printSize.width / 2, y: printSize.height / 2), placement))
        }
    }

    /// The print around the box, darkened.
    private func dimming(_ placement: Placement, in size: CGSize) -> some View {
        let corners = [CGPoint.zero, CGPoint(x: printSize.width, y: 0), CGPoint(x: printSize.width, y: printSize.height),
                       CGPoint(x: 0, y: printSize.height)].map { screen($0, placement) }
        return Path { path in
            path.addLines(corners)
            path.closeSubpath()
            path.addRect(placement.box)
        }
        .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func frame(_ placement: Placement) -> some View {
        let box = placement.box
        let active = live != nil || dialing
        return ZStack(alignment: .topLeading) {
            if active {
                Path { path in
                    for third in [1.0 / 3, 2.0 / 3] {
                        path.move(to: CGPoint(x: box.minX + box.width * third, y: box.minY))
                        path.addLine(to: CGPoint(x: box.minX + box.width * third, y: box.maxY))
                        path.move(to: CGPoint(x: box.minX, y: box.minY + box.height * third))
                        path.addLine(to: CGPoint(x: box.maxX, y: box.minY + box.height * third))
                    }
                }.stroke(Color.white.opacity(0.75), lineWidth: 0.5)
            }
            Path { $0.addRect(box) }.stroke(Color.white, lineWidth: 1)
            Path { path in
                let length: CGFloat = min(22, box.width / 3, box.height / 3)
                for (corner, x, y) in [(CGPoint(x: box.minX, y: box.minY), 1.0, 1.0), (CGPoint(x: box.maxX, y: box.minY), -1, 1),
                                       (CGPoint(x: box.maxX, y: box.maxY), -1, -1), (CGPoint(x: box.minX, y: box.maxY), 1, -1)] {
                    let inset = CGPoint(x: corner.x - x * 1.5, y: corner.y - y * 1.5)
                    path.move(to: CGPoint(x: inset.x + x * length, y: inset.y))
                    path.addLine(to: inset)
                    path.addLine(to: CGPoint(x: inset.x, y: inset.y + y * length))
                }
            }.stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .square))
        }
        .shadow(color: .black.opacity(0.45), radius: 1.5)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .overlay {
            // What VoiceOver reads for the box, over the box itself.
            Rectangle().fill(.clear)
                .frame(width: box.width, height: box.height)
                .allowsHitTesting(false)
                .accessibilityElement()
                .accessibilityLabel("Crop")
                .accessibilityValue(cropDescription)
                .accessibilityIdentifier("darkroom-crop-box")
                .position(x: box.midX, y: box.midY)
        }
    }

    /// The crop as VoiceOver reads it: how much of the print's width and height it keeps.
    private var cropDescription: String {
        let kept = rect
        let width = Int((kept.width / printSize.width * 100).rounded())
        let height = Int((kept.height / printSize.height * 100).rounded())
        return "\(width) percent of the width, \(height) percent of the height"
    }

    // MARK: Handles

    enum Handle: String, CaseIterable {
        case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left

        /// Which way the handle moves the box's horizontal and vertical edges: -1 the leading or top edge, 1 the trailing
        /// or bottom edge, 0 neither.
        var edges: (x: CGFloat, y: CGFloat) {
            switch self {
            case .topLeft: (-1, -1)
            case .top: (0, -1)
            case .topRight: (1, -1)
            case .right: (1, 0)
            case .bottomRight: (1, 1)
            case .bottom: (0, 1)
            case .bottomLeft: (-1, 1)
            case .left: (-1, 0)
            }
        }

        var isCorner: Bool { edges.x != 0 && edges.y != 0 }

        /// Where the handle sits on `box`: a corner, or the middle of an edge.
        func point(on box: CGRect) -> CGPoint {
            CGPoint(x: edges.x == 0 ? box.midX : (edges.x < 0 ? box.minX : box.maxX),
                    y: edges.y == 0 ? box.midY : (edges.y < 0 ? box.minY : box.maxY))
        }

        /// The edges VoiceOver can move, one at a time.
        var spoken: String? {
            switch self {
            case .left: "Crop left edge"
            case .right: "Crop right edge"
            case .top: "Crop top edge"
            case .bottom: "Crop bottom edge"
            default: nil
            }
        }
    }

    @ViewBuilder private func handles(_ placement: Placement, in size: CGSize) -> some View {
        let box = placement.box
        let reach: CGFloat = 44
        ForEach(Handle.allCases, id: \.self) { handle in
            let edges = handle.edges
            let point = handle.point(on: box)
            let width = edges.x == 0 ? max(box.width - reach, 1) : reach
            let height = edges.y == 0 ? max(box.height - reach, 1) : reach
            Color.clear
                .frame(width: width, height: height)
                .contentShape(Rectangle())
                .accessibilityHidden(handle.spoken == nil)
                .modifier(SpokenEdge(handle: handle, value: edgeValue(handle)) { step(handle, by: $0, in: size) })
                .position(point)
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .updating($moving) { _, moving, _ in moving = true }
                    .onChanged { drag(handle, by: $0.translation, in: size) }
                    .onEnded { _ in endGesture() })
        }
    }

    /// The edge's place across the print, in percent, as VoiceOver reads it.
    private func edgeValue(_ handle: Handle) -> String {
        let kept = rect
        let percent: CGFloat = switch handle {
        case .left: kept.minX / printSize.width
        case .right: kept.maxX / printSize.width
        case .top: kept.minY / printSize.height
        default: kept.maxY / printSize.height
        }
        return "\(Int((percent * 100).rounded())) percent"
    }

    /// Moves an edge by a hundredth of the print's width or height, for VoiceOver.
    private func step(_ handle: Handle, by direction: CGFloat, in size: CGSize) {
        let start = resting(rect, in: size)
        let along = handle.edges.x != 0 ? printSize.width : printSize.height
        let points = direction * along / 100 * start.scale
        let travel = handle.edges.x != 0 ? CGSize(width: points, height: 0) : CGSize(width: 0, height: points)
        gestureStart = start
        drag(handle, by: travel, in: size)
        endGesture(animated: false)
    }

    /// The box with `handle` moved by `travel` over a still print, as far as the crop stays on the print and keeps its
    /// shape.
    private func drag(_ handle: Handle, by travel: CGSize, in size: CGSize) {
        if gestureStart == nil { gestureStart = resting(rect, in: size) }
        guard let start = gestureStart, let next = handled(handle, by: travel, from: start) else { return }
        live = next.placement
        liveRect = next.rect
    }

    /// The placement and crop for a box at `start` with `handle` moved by `travel`, or as near it as the crop allows, from
    /// the gesture's start alone. On a shape, on the 6×6 and on an edge the handle goes as far along the travel as the
    /// crop allows. A Freeform corner goes to the finger where the crop allows it there, and otherwise to the allowed
    /// position nearest the finger (`nearestAllowed`), so an edge held at the print's edge or at the smallest crop, even
    /// one held both ways, leaves the other following the finger, and on a straightened print the corner slides along a
    /// limit with it, as in the Photos app. Nil where none of the travel is allowed.
    func handled(_ handle: Handle, by travel: CGSize, from start: Placement) -> (placement: Placement, rect: CGRect)? {
        guard handle.isCorner, !square, ratio == nil else { return farthest(handle, along: travel, from: start).moved }
        return moved(start, handle: handle, by: travel)
            ?? moved(start, handle: handle, by: nearestAllowed(handle, to: travel, from: start))
    }

    /// The farthest part of `travel` the crop allows `handle` from `start`, found by halving, and the box there.
    private func farthest(_ handle: Handle, along travel: CGSize,
                          from start: Placement) -> (share: CGFloat, moved: (placement: Placement, rect: CGRect)?) {
        if let whole = moved(start, handle: handle, by: travel) { return (1, whole) }
        var low: CGFloat = 0, high: CGFloat = 1
        var found: (placement: Placement, rect: CGRect)?
        for _ in 0..<24 {
            let middle = (low + high) / 2
            let part = CGSize(width: travel.width * middle, height: travel.height * middle)
            if let fit = moved(start, handle: handle, by: part) {
                found = fit
                low = middle
            } else { high = middle }
        }
        return (low, found)
    }

    /// The travel to the corner position the crop allows that is nearest the finger at `travel`. On a straightened print
    /// the crop's longer side grows with the square of the box's longer side over its shorter one, so the positions the
    /// crop allows are not a polygon to project the finger onto, and they are searched along straight lines from where
    /// the corner began instead. On each of `nearestLines` lines, evenly turned from the right and exactly along the
    /// axes on the four that are, the point nearest the finger on the part the crop allows, kept only where `moved`
    /// accepts it; the nearest of those, the first line's on an exact tie, then refined between the lines either side of
    /// it by golden section. Where the crop touches a print edge the positions it allows can lie, seen from where the
    /// corner began, in a wedge narrower than the lines' spacing, so wherever two neighbouring lines disagree on whether
    /// the crop allows their point nearest the finger, the edge between them is found by halving, and the nearest point
    /// of the line just inside it is a candidate too. Where an edge of the box is held both ways, at the smallest box or
    /// the smallest crop against a print edge, the positions the crop allows are a line or a wedge whose sides run along
    /// the box's edges or the print's as the box shows them, turned by the straightening angle, so the lines along those
    /// are candidates too. A refined, edge or turned point replaces the nearest only when strictly nearer, so the result
    /// depends on nothing but the travel, and the same finger always gives the same corner.
    private func nearestAllowed(_ handle: Handle, to travel: CGSize, from start: Placement) -> CGSize {
        // Where the corner began is allowed, so the nearest allowed position is no farther from the finger than that.
        let reach = 2 * hypot(travel.width, travel.height)
        func nearest(toward direction: CGSize) -> (distance: CGFloat, travel: CGSize, reaches: Bool) {
            let line = farthest(handle, along: CGSize(width: direction.width * reach, height: direction.height * reach),
                                from: start)
            let allowed = line.moved == nil ? 0 : line.share * reach
            let nearestOnLine = max(direction.width * travel.width + direction.height * travel.height, 0)
            let along = min(nearestOnLine, allowed)
            let point = CGSize(width: direction.width * along, height: direction.height * along)
            let distance = moved(start, handle: handle, by: point) == nil
                ? .infinity : hypot(travel.width - point.width, travel.height - point.height)
            return (distance, point, allowed >= nearestOnLine)
        }
        func nearest(along angle: CGFloat) -> (distance: CGFloat, travel: CGSize, reaches: Bool) {
            nearest(toward: CGSize(width: cos(angle), height: sin(angle)))
        }
        let step = 2 * CGFloat.pi / CGFloat(Self.nearestLines)
        let axes = [CGSize(width: 1, height: 0), CGSize(width: 0, height: 1), CGSize(width: -1, height: 0),
                    CGSize(width: 0, height: -1)]
        let quarter = Self.nearestLines / 4
        let lines = (0..<Self.nearestLines).map {
            $0 % quarter == 0 ? nearest(toward: axes[$0 / quarter]) : nearest(along: CGFloat($0) * step)
        }
        var best = 0
        for line in lines.indices where lines[line].distance < lines[best].distance { best = line }
        let golden = (CGFloat(5).squareRoot() - 1) / 2
        var low = CGFloat(best - 1) * step, high = CGFloat(best + 1) * step
        var a = high - golden * (high - low), b = low + golden * (high - low)
        var atA = nearest(along: a), atB = nearest(along: b)
        for _ in 0..<30 {
            if atA.distance <= atB.distance {
                (high, b, atB) = (b, a, atA)
                a = high - golden * (high - low)
                atA = nearest(along: a)
            } else {
                (low, a, atA) = (a, b, atB)
                b = low + golden * (high - low)
                atB = nearest(along: b)
            }
        }
        var chosen = lines[best]
        for refined in [atA, atB] where refined.distance < chosen.distance { chosen = refined }
        for line in lines.indices where lines[line].reaches != lines[(line + 1) % lines.count].reaches {
            var inside = CGFloat(line) * step, outside = CGFloat(line + 1) * step
            if !lines[line].reaches { (inside, outside) = (outside, inside) }
            for _ in 0..<30 {
                let middle = (inside + outside) / 2
                if nearest(along: middle).reaches { inside = middle } else { outside = middle }
            }
            let edge = nearest(along: inside)
            if edge.distance < chosen.distance { chosen = edge }
        }
        let radians = CGFloat(degrees) * .pi / 180
        let cosine = cos(radians), sine = sin(radians)
        for axis in axes {
            let clockwise = CGSize(width: axis.width * cosine - axis.height * sine,
                                   height: axis.width * sine + axis.height * cosine)
            let counterclockwise = CGSize(width: axis.width * cosine + axis.height * sine,
                                          height: axis.height * cosine - axis.width * sine)
            for turned in [clockwise, counterclockwise] {
                let along = nearest(toward: turned)
                if along.distance < chosen.distance { chosen = along }
            }
        }
        return chosen.travel
    }

    /// The placement and crop for a box with `handle` moved by `travel`, or nil where that crop would leave the print or
    /// be too small, or where the handle would pass the box's other side and turn it inside out.
    func moved(_ start: Placement, handle: Handle, by travel: CGSize) -> (placement: Placement, rect: CGRect)? {
        let old = start.box
        var box = old
        let edges = handle.edges
        let locked = square ? 1 : ratio
        if let locked {
            if handle.isCorner {
                // Along the box's diagonal from the opposite corner, which stays.
                let anchor = CGPoint(x: edges.x < 0 ? old.maxX : old.minX, y: edges.y < 0 ? old.maxY : old.minY)
                let diagonal = CGVector(dx: edges.x * old.width, dy: edges.y * old.height)
                let length = (diagonal.dx * diagonal.dx + diagonal.dy * diagonal.dy).squareRoot()
                let along = ((diagonal.dx * (diagonal.dx + travel.width) + diagonal.dy * (diagonal.dy + travel.height)) / length)
                let width = along / length * old.width
                box = CGRect(x: edges.x < 0 ? anchor.x - width : anchor.x, y: edges.y < 0 ? anchor.y - width / locked : anchor.y,
                             width: width, height: width / locked)
            } else if edges.x != 0 {
                let width = old.width + edges.x * travel.width
                box = CGRect(x: edges.x < 0 ? old.maxX - width : old.minX, y: old.midY - width / locked / 2,
                             width: width, height: width / locked)
            } else {
                let height = old.height + edges.y * travel.height
                box = CGRect(x: old.midX - height * locked / 2, y: edges.y < 0 ? old.maxY - height : old.minY,
                             width: height * locked, height: height)
            }
        } else {
            if edges.x < 0 { box.origin.x += travel.width; box.size.width -= travel.width }
            if edges.x > 0 { box.size.width += travel.width }
            if edges.y < 0 { box.origin.y += travel.height; box.size.height -= travel.height }
            if edges.y > 0 { box.size.height += travel.height }
        }
        guard box.size.width >= min(Self.smallestBox, old.width), box.size.height >= min(Self.smallestBox, old.height) else {
            return nil
        }
        // The print stays still: the pixel at the box's center moves with the box.
        let shift = unscreen(CGVector(dx: box.midX - old.midX, dy: box.midY - old.midY), start.scale)
        let center = CGPoint(x: start.center.x + shift.dx, y: start.center.y + shift.dy)
        let output = CGSize(width: box.width / start.scale, height: box.height / start.scale)
        let crop = CropGeometry.crop(center: center, output: output, degrees: degrees)
        guard CropGeometry.isValid(crop, printSize: printSize) else { return nil }
        return (Placement(box: box, scale: start.scale, center: center), crop)
    }

    // MARK: Moving the print

    private func pictureGesture(in size: CGSize) -> some Gesture {
        SimultaneousGesture(MagnifyGesture(minimumScaleDelta: 0.01), DragGesture(minimumDistance: 2))
            .updating($moving) { _, moving, _ in moving = true }
            .onChanged { value in
                if gestureStart == nil { gestureStart = resting(rect, in: size) }
                guard let start = gestureStart else { return }
                let magnification = value.first?.magnification ?? 1
                let anchor = value.first?.startLocation ?? value.second?.startLocation ?? CGPoint(x: start.box.midX, y: start.box.midY)
                let travel = value.second?.translation ?? .zero
                place(start, magnification: magnification, anchor: anchor, travel: travel)
            }
            .onEnded { _ in endGesture() }
    }

    /// The print scaled by `magnification` about `anchor` and moved by `travel` under the still box, resisting past the
    /// largest and smallest crop and past the print's edges.
    private func place(_ start: Placement, magnification: CGFloat, anchor: CGPoint, travel: CGSize) {
        let box = start.box
        let output = CGSize(width: box.width / start.scale, height: box.height / start.scale)
        let kept = output.width / CropGeometry.crop(center: .zero, output: output, degrees: degrees).width
        // The scale at which the crop is the whole print's width or height, and at which it is the smallest crop.
        let smallest = CropGeometry.minimumSide(printSize: printSize)
        let lowest = max(box.width / (kept * printSize.width), box.height / (kept * printSize.height))
        let highest = max(lowest, min(box.width / (kept * smallest), box.height / (kept * smallest)))
        let wanted = start.scale * magnification
        let scale = wanted < lowest ? lowest * pow(wanted / lowest, Self.resistance)
            : wanted > highest ? highest * pow(wanted / highest, Self.resistance) : wanted
        // The pixel under the pinch's start follows the fingers.
        let held = unscreen(CGVector(dx: anchor.x - box.midX, dy: anchor.y - box.midY), start.scale)
        let pixel = CGPoint(x: start.center.x + held.dx, y: start.center.y + held.dy)
        let now = unscreen(CGVector(dx: anchor.x + travel.width - box.midX, dy: anchor.y + travel.height - box.midY), scale)
        let wantedCenter = CGPoint(x: pixel.x - now.dx, y: pixel.y - now.dy)
        let settledScale = min(max(scale, lowest), highest)
        let half = CGSize(width: box.width / settledScale / kept / 2, height: box.height / settledScale / kept / 2)
        let settled = CGPoint(x: min(max(wantedCenter.x, half.width), printSize.width - half.width),
                              y: min(max(wantedCenter.y, half.height), printSize.height - half.height))
        let center = CGPoint(x: settled.x + (wantedCenter.x - settled.x) * Self.resistance,
                             y: settled.y + (wantedCenter.y - settled.y) * Self.resistance)
        live = Placement(box: box, scale: scale, center: center)
        liveRect = CGRect(x: settled.x - half.width, y: settled.y - half.height, width: half.width * 2, height: half.height * 2)
    }

    /// Hands the crop on and lets the box settle at rest: centered, as large as the print area allows.
    private func endGesture(animated: Bool = true) {
        let ended = liveRect
        gestureStart = nil
        if let ended { commit(CropGeometry.crop(ended, printSize: printSize, square: square)) }
        withAnimation(animated ? .spring(duration: 0.35, bounce: 0) : nil) {
            live = nil
            liveRect = nil
        }
    }

    // MARK: Geometry

    /// The box at rest: what the crop prints, as large as fits the area inside the margin, in its middle.
    func resting(_ rect: CGRect, in size: CGSize) -> Placement {
        let output = CropGeometry.outputSize(of: rect.size, degrees: degrees)
        let room = CGSize(width: max(size.width - 2 * Self.margin, 1), height: max(size.height - 2 * Self.margin, 1))
        let scale = min(room.width / output.width, room.height / output.height)
        let box = CGRect(x: (size.width - output.width * scale) / 2, y: (size.height - output.height * scale) / 2,
                         width: output.width * scale, height: output.height * scale)
        return Placement(box: box, scale: scale, center: CGPoint(x: rect.midX, y: rect.midY))
    }

    /// A pixel of the turned print on the screen.
    private func screen(_ pixel: CGPoint, _ placement: Placement) -> CGPoint {
        let radians = -degrees * .pi / 180
        let dx = (pixel.x - placement.center.x) * placement.scale, dy = (pixel.y - placement.center.y) * placement.scale
        return CGPoint(x: placement.box.midX + dx * cos(radians) - dy * sin(radians),
                       y: placement.box.midY + dx * sin(radians) + dy * cos(radians))
    }

    /// A distance on the screen as a distance across the turned print.
    private func unscreen(_ offset: CGVector, _ scale: CGFloat) -> CGVector {
        let radians = degrees * .pi / 180
        return CGVector(dx: (offset.dx * cos(radians) - offset.dy * sin(radians)) / scale,
                        dy: (offset.dx * sin(radians) + offset.dy * cos(radians)) / scale)
    }
}

/// One of the crop box's four edges for VoiceOver: an adjustable element whose value is where the edge is across the
/// print. The corners are left to touch, since the four edges make any crop.
private struct SpokenEdge: ViewModifier {
    let handle: CropEditor.Handle
    let value: String
    let step: (CGFloat) -> Void

    func body(content: Content) -> some View {
        if let label = handle.spoken {
            content
                .accessibilityElement()
                .accessibilityLabel(label)
                .accessibilityValue(value)
                .accessibilityIdentifier("darkroom-crop-\(handle.rawValue)")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: step(1)
                    case .decrement: step(-1)
                    @unknown default: break
                    }
                }
        } else {
            content
        }
    }
}

/// The print the crop box sits over: the recipe's other edits, without its crop, straightening, vignette or quarter turns,
/// which the crop box shows itself. The vignette is left out because the renderer darkens the corners of the cropped,
/// straightened print, so on the whole print it would show out of place.
struct UncroppedPrint {
    let recipe: DarkroomRecipe
    /// Its picture: screen-sized, and as sharp as the print where the crop box shows it at more pixels than that.
    let picture: ZoomedPicture
    /// The print's size in pixels, before any quarter turn.
    let pixelSize: CGSize

    /// The recipe such a print is made for: `recipe` without its crop, straightening, vignette or quarter turns.
    static func recipe(for recipe: DarkroomRecipe) -> DarkroomRecipe {
        var flat = recipe
        flat.crop = nil
        flat.straighteningDegrees = nil
        flat.vignetteStops = nil
        flat.rotationQuarterTurns = nil
        return flat
    }

    /// The print, only while it was made for `recipe`'s other edits: after Reset or another edit it is an earlier print,
    /// and the crop box waits for the one made for the edits as they are.
    func matches(_ recipe: DarkroomRecipe) -> Bool {
        self.recipe == Self.recipe(for: recipe)
    }
}

/// Photos' straighten dial in place of a slider (the captain, 2026-10-29, "2A"): a ruler of degrees that slides under a
/// fixed mark, from -45° to +45° in tenths (FR-31). Dragging the ruler left turns the print by more degrees. VoiceOver
/// moves it a degree at a time.
struct StraightenDial: View {
    @Binding var degrees: Double
    /// Told when a drag begins and when it ends or is cancelled.
    let editing: (Bool) -> Void
    @State private var dragStart: Double?
    /// Whether the ruler is held. A drag that is cancelled never ends, and it is let go as this goes false.
    @GestureState private var turning = false

    /// The ruler's spacing.
    private static let pointsPerDegree: CGFloat = 5

    var body: some View {
        VStack(spacing: 2) {
            // The angle stops growing at the largest ordinary text size, as Adjust's other controls do, so the dial is in
            // view under the shapes when Adjust opens at every size; the Large Content Viewer shows it larger.
            Text(Self.shown(degrees)).font(.caption).monospacedDigit()
                .foregroundStyle(degrees == 0 ? Color.secondary : Color.accentColor)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            Canvas { context, size in
                let middle = size.width / 2
                for tick in Int(DarkroomLimits.straighteningDegrees.lowerBound)...Int(DarkroomLimits.straighteningDegrees.upperBound) {
                    let x = middle + (CGFloat(tick) - degrees) * Self.pointsPerDegree
                    guard x > -1, x < size.width + 1 else { continue }
                    let length: CGFloat = tick % 15 == 0 ? 18 : tick % 5 == 0 ? 12 : 7
                    let top = (size.height - length) / 2
                    context.fill(Path(CGRect(x: x - 0.5, y: top, width: 1, height: length)),
                                 with: .color(tick == 0 ? .primary : .secondary))
                }
                context.fill(Path(roundedRect: CGRect(x: middle - 1, y: 0, width: 2, height: size.height), cornerRadius: 1),
                             with: .color(.accentColor))
            }
            .frame(height: 30)
            .mask {
                LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.15),
                                       .init(color: .black, location: 0.85), .init(color: .clear, location: 1)],
                               startPoint: .leading, endPoint: .trailing)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .updating($turning) { _, turning, _ in turning = true }
                .onChanged { value in
                    if dragStart == nil { dragStart = degrees; editing(true) }
                    degrees = Self.tenths((dragStart ?? 0) - value.translation.width / Self.pointsPerDegree)
                }
                .onEnded { _ in letGo() })
            .onChange(of: turning) { _, turning in if !turning, dragStart != nil { letGo() } }
        }
        .frame(minHeight: 44)
        .sensoryFeedback(.selection, trigger: degrees == 0) { _, atZero in atZero }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Straighten")
        .accessibilityValue("\(String(format: "%.1f", degrees)) degrees")
        .accessibilityIdentifier("darkroom-straighten-dial")
        .accessibilityShowsLargeContentViewer()
        .accessibilityAdjustableAction { direction in
            // To the next whole degree each way.
            switch direction {
            case .increment: degrees = Self.tenths(degrees.rounded(.down) + 1)
            case .decrement: degrees = Self.tenths(degrees.rounded(.up) - 1)
            @unknown default: return
            }
            editing(false)
        }
    }

    /// Ends a drag of the ruler, ended or cancelled.
    private func letGo() {
        dragStart = nil
        editing(false)
    }

    /// The angle on the dial's step and inside its range, never "-0.0".
    static func tenths(_ value: Double) -> Double {
        StopsText.tenths(value, in: DarkroomLimits.straighteningDegrees)
    }

    static func shown(_ degrees: Double) -> String {
        "\(String(format: "%.1f", degrees))°"
    }
}
