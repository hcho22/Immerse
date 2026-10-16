import SwiftUI

/// What a subview of the `CaptureColumn` is.
enum CaptureColumnRole: Equatable {
    case header
    /// The viewfinder's box, with its width over its height.
    case viewfinder(aspect: CGFloat)
    case controls
}

private struct CaptureColumnRoleKey: LayoutValueKey {
    static let defaultValue: CaptureColumnRole? = nil
}

extension View {
    func captureColumnRole(_ role: CaptureColumnRole) -> some View { layoutValue(key: CaptureColumnRoleKey.self, value: role) }
}

/// The shooting screen's column: the header, the viewfinder and the controls under it, which together are as tall as the
/// room between the top of the screen and the shutter bar, so the whole viewfinder shows (the captain, 2026-10-16:
/// "viewfinder does not fit the screen"). Each Camera keeps its viewfinder's shape; the box is the largest of that shape
/// that the room leaves after the header and the controls, narrower than the screen where the room is short, and never
/// smaller than `minimumViewfinder`, below which the screen scrolls instead, as at the largest text sizes.
///
/// Where the room is more than the viewfinder at the screen's full width needs, the header gets the rest, up to
/// `maximumHeader`, so that held on its side the Camera's name and its count can each read on one line.
///
/// Nothing here depends on how the iPhone is held, so the viewfinder is the same size in the same place in every hold:
/// the header and the controls reserve their heights for every hold (`TurnedBlock`, `CaptionedSlider`).
struct CaptureColumn: Layout {
    /// The room the column has, from the top of the screen's safe area to the shutter bar.
    var available: CGFloat
    var spacing: CGFloat = 12
    var minimumViewfinder: CGFloat = 220
    var maximumHeader: CGFloat = 300

    private struct Plan {
        var header: LayoutSubview?
        var viewfinder: LayoutSubview?
        var controls: LayoutSubview?
        var width: CGFloat
        var headerHeight: CGFloat
        var viewfinderSize: CGSize
        var controlsHeight: CGFloat
        var gaps: CGFloat
        var height: CGFloat { headerHeight + viewfinderSize.height + controlsHeight + gaps }
    }

    private func plan(_ proposal: ProposedViewSize, _ subviews: Subviews) -> Plan {
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? 390
        let header = subviews.first { $0[CaptureColumnRoleKey.self] == .header }
        let controls = subviews.first { $0[CaptureColumnRoleKey.self] == .controls }
        var viewfinder: LayoutSubview?
        var aspect: CGFloat = 1
        for subview in subviews {
            if case let .viewfinder(shape)? = subview[CaptureColumnRoleKey.self] { viewfinder = subview; aspect = shape }
        }
        let widthOnly = ProposedViewSize(width: width, height: nil)
        let controlsHeight = controls?.sizeThatFits(widthOnly).height ?? 0
        let headerMinimum = header?.sizeThatFits(widthOnly).height ?? 0
        let parts = [headerMinimum > 0, viewfinder != nil, controlsHeight > 0].filter { $0 }.count
        let gaps = spacing * CGFloat(max(0, parts - 1))
        let room = available - controlsHeight - gaps
        var headerHeight = headerMinimum
        var viewfinderSize = CGSize.zero
        if viewfinder != nil {
            let ideal = width / aspect
            var height = ideal
            if room - headerMinimum >= ideal {
                headerHeight = min(max(headerMinimum, room - ideal), max(maximumHeader, headerMinimum))
            } else {
                height = max(minimumViewfinder, room - headerMinimum)
            }
            height = min(height, ideal)
            viewfinderSize = CGSize(width: height * aspect, height: height)
        }
        return Plan(header: header, viewfinder: viewfinder, controls: controls, width: width, headerHeight: headerHeight,
                    viewfinderSize: viewfinderSize, controlsHeight: controlsHeight, gaps: gaps)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let plan = plan(proposal, subviews)
        return CGSize(width: plan.width, height: plan.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let plan = plan(ProposedViewSize(width: bounds.width, height: nil), subviews)
        var y = bounds.minY
        if let header = plan.header, plan.headerHeight > 0 {
            header.place(at: CGPoint(x: bounds.minX, y: y), anchor: .topLeading,
                         proposal: ProposedViewSize(width: plan.width, height: plan.headerHeight))
            y += plan.headerHeight + spacing
        }
        if let viewfinder = plan.viewfinder {
            viewfinder.place(at: CGPoint(x: bounds.midX, y: y), anchor: .top, proposal: ProposedViewSize(plan.viewfinderSize))
            y += plan.viewfinderSize.height + spacing
        }
        if let controls = plan.controls, plan.controlsHeight > 0 {
            controls.place(at: CGPoint(x: bounds.minX, y: y), anchor: .topLeading,
                           proposal: ProposedViewSize(width: plan.width, height: nil))
        }
    }
}
