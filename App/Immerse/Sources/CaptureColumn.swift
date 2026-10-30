import SwiftUI

/// What a subview of the `CaptureColumn` is.
enum CaptureColumnRole: Equatable {
    case header
    /// The Camera's picture frame inside the full-width viewfinder area.
    case viewfinder(aspect: CGFloat)
    /// The control strip, under the viewfinder area where the screen has room for it and over its bottom edge where not.
    case strip
}

private struct CaptureColumnRoleKey: LayoutValueKey {
    static let defaultValue: CaptureColumnRole? = nil
}

extension View {
    func captureColumnRole(_ role: CaptureColumnRole) -> some View { layoutValue(key: CaptureColumnRoleKey.self, value: role) }
}

/// Geometry shared by every Camera: the viewfinder area is the iPhone Camera app's full-width, portrait 4:3 photo frame.
/// Each Camera's own picture stays centered inside that area, with no live image drawn in the bars around it.
enum CaptureAreaGeometry {
    static let aspectRatio: CGFloat = 3.0 / 4.0

    static func cameraFrame(aspectRatio: CGFloat, in area: CGSize) -> CGRect {
        guard area.width > 0, area.height > 0, aspectRatio > 0 else { return .zero }
        let size: CGSize
        if area.width / area.height > aspectRatio {
            size = CGSize(width: area.height * aspectRatio, height: area.height)
        } else {
            size = CGSize(width: area.width, height: area.width / aspectRatio)
        }
        return CGRect(x: (area.width - size.width) / 2, y: (area.height - size.height) / 2,
                      width: size.width, height: size.height)
    }
}

/// The shooting screen's fixed top-to-bottom arrangement: one header, then the same full-width 4:3 area on every Camera,
/// then the control strip where the Camera has one (the captain, 2026-10-29, "4A"). The viewfinder size never depends on
/// Camera shape, controls, notices or the room below it; a short screen scrolls instead.
///
/// The strip sits under the area, where the iPhone Camera app has its PHOTO / VIDEO row, centred in the `room` the
/// screen leaves between the area and the shutter bar wherever that holds it. Where that room holds at least half the
/// strip, as with the 6×6's two lines at the largest text sizes, the strip sits as low as the room allows, partly over the
/// area. Where it holds less, as on the iPhone SE (3rd generation), which leaves 3 points under the area, the strip sits
/// over the area's bottom edge, its bottom on the area's, as the iPhone Camera app's controls do there, rather than show
/// a sliver of its dark grounds below the picture. Either way the area keeps its size and place.
struct CaptureColumn: Layout {
    /// The height the screen gives the column above the shutter bar. Without one the strip is always under the area.
    var room: CGFloat?

    private struct Plan {
        var header: LayoutSubview?
        var viewfinder: LayoutSubview?
        var strip: LayoutSubview?
        var width: CGFloat
        var headerHeight: CGFloat
        var viewfinderSize: CGSize
        var stripHeight: CGFloat
        var stripTop: CGFloat
        var height: CGFloat { max(headerHeight + viewfinderSize.height, strip == nil ? 0 : stripTop + stripHeight) }
    }

    /// Where the strip's top goes: centred between the area's bottom and the bottom of the `room` where that holds the
    /// strip, as low as the room allows where it holds at least half of it, and otherwise over the area with its bottom
    /// on the area's.
    static func stripTop(viewfinderBottom: CGFloat, stripHeight: CGFloat, room: CGFloat?) -> CGFloat {
        guard let room, room.isFinite else { return viewfinderBottom }
        let under = room - viewfinderBottom
        if under >= stripHeight { return viewfinderBottom + (under - stripHeight) / 2 }
        return under >= stripHeight / 2 ? room - stripHeight : viewfinderBottom - stripHeight
    }

    private func plan(_ proposal: ProposedViewSize, _ subviews: Subviews) -> Plan {
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? 390
        func subview(_ role: CaptureColumnRole) -> LayoutSubview? { subviews.first { $0[CaptureColumnRoleKey.self] == role } }
        let header = subview(.header)
        let viewfinder = subviews.first {
            if case .viewfinder? = $0[CaptureColumnRoleKey.self] { return true }
            return false
        }
        let strip = subview(.strip)
        let headerHeight = header?.sizeThatFits(ProposedViewSize(width: width, height: nil)).height ?? 0
        let viewfinderSize = viewfinder == nil ? .zero : CGSize(width: width, height: width / CaptureAreaGeometry.aspectRatio)
        let stripHeight = strip?.sizeThatFits(ProposedViewSize(width: width, height: nil)).height ?? 0
        let stripTop = Self.stripTop(viewfinderBottom: headerHeight + viewfinderSize.height, stripHeight: stripHeight,
                                     room: room)
        return Plan(header: header, viewfinder: viewfinder, strip: strip, width: width, headerHeight: headerHeight,
                    viewfinderSize: viewfinderSize, stripHeight: stripHeight, stripTop: stripTop)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let plan = plan(proposal, subviews)
        return CGSize(width: plan.width, height: plan.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let plan = plan(ProposedViewSize(width: bounds.width, height: nil), subviews)
        plan.header?.place(at: CGPoint(x: bounds.minX, y: bounds.minY), anchor: .topLeading,
                           proposal: ProposedViewSize(width: plan.width, height: plan.headerHeight))
        plan.viewfinder?.place(at: CGPoint(x: bounds.minX, y: bounds.minY + plan.headerHeight), anchor: .topLeading,
                               proposal: ProposedViewSize(plan.viewfinderSize))
        plan.strip?.place(at: CGPoint(x: bounds.minX, y: bounds.minY + plan.stripTop), anchor: .topLeading,
                          proposal: ProposedViewSize(width: plan.width, height: plan.stripHeight))
    }
}

/// Which line of the control strip a control belongs on.
enum ControlStripLine: Equatable {
    /// The Zoom Steps.
    case steps
    /// The focus switch and the 6×6's Focus and Exposure buttons.
    case settings
}

private struct ControlStripLineKey: LayoutValueKey {
    static let defaultValue = ControlStripLine.settings
}

extension View {
    func controlStripLine(_ line: ControlStripLine) -> some View { layoutValue(key: ControlStripLineKey.self, value: line) }
}

/// The control strip's arrangement: the steps' line above the settings' line, as the iPhone Camera app has its zoom
/// buttons above its PHOTO / VIDEO row, each line centred across the screen and the two 10 points apart (the captain,
/// 2026-10-29: "please allow extra spacing between zoom buttons and auto/manual buttons"). Where both fit on one line
/// they share it, steps first and 12 points from the settings, unless `keepsStepsLine`: the 6×6 keeps both lines whether
/// its steps show or not, so its strip, which a slider fills when one opens, is the same height on either camera and with
/// a slider open or not.
///
/// Each control takes the same room in every hold, its words and icons turning inside it, so the strip is the same in
/// every hold.
struct ControlStripLayout: Layout {
    var keepsStepsLine = false
    /// Between the controls of one kind, as the 6×6's switch and its buttons.
    var spacing: CGFloat = 8
    /// Between the steps and the settings where they share a line.
    var groupSpacing: CGFloat = 12
    var lineSpacing: CGFloat = 10

    /// A control and the room before it on its line.
    private typealias Item = (subview: LayoutSubview, size: CGSize, before: CGFloat)

    private struct Plan {
        var lines: [[Item]]
        var lineHeights: [CGFloat]
        var width: CGFloat
        var height: CGFloat { lineHeights.reduce(0, +) + lineSpacing * CGFloat(max(lineHeights.count - 1, 0)) }
        var lineSpacing: CGFloat
    }

    private static func length(_ line: [Item]) -> CGFloat { line.map { $0.size.width + $0.before }.reduce(0, +) }

    private func plan(_ proposal: ProposedViewSize, _ subviews: Subviews) -> Plan {
        let steps = subviews.filter { $0[ControlStripLineKey.self] == .steps }
        let settings = subviews.filter { $0[ControlStripLineKey.self] == .settings }
        // Each line's first control has no room before it.
        func line(_ group: [LayoutSubview], first: CGFloat = 0) -> [Item] {
            group.enumerated().map { index, subview in
                (subview: subview, size: subview.sizeThatFits(.unspecified), before: index == 0 ? first : spacing)
            }
        }
        let offered = proposal.width.flatMap { $0.isFinite ? $0 : nil }
        let together = line(steps) + line(settings, first: steps.isEmpty ? 0 : groupSpacing)
        var lines: [[Item]]
        if !keepsStepsLine, offered.map({ Self.length(together) <= $0 }) ?? true {
            lines = [together]
        } else {
            lines = [line(steps), line(settings)]
        }
        lines = lines.filter { !$0.isEmpty }
        let width = offered ?? lines.map(Self.length).max() ?? 0
        return Plan(lines: lines, lineHeights: lines.map { $0.map(\.size.height).max() ?? 0 }, width: width,
                    lineSpacing: lineSpacing)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let plan = plan(proposal, subviews)
        return CGSize(width: plan.width, height: plan.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let plan = plan(ProposedViewSize(width: bounds.width, height: nil), subviews)
        var y = bounds.minY
        for (line, height) in zip(plan.lines, plan.lineHeights) {
            var x = bounds.midX - Self.length(line) / 2
            for item in line {
                x += item.before
                item.subview.place(at: CGPoint(x: x, y: y + height / 2), anchor: .leading, proposal: ProposedViewSize(item.size))
                x += item.size.width
            }
            y += height + plan.lineSpacing
        }
    }
}
