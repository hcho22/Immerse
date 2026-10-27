import SwiftUI

/// What a subview of the `CaptureColumn` is.
enum CaptureColumnRole: Equatable {
    case header
    /// The Camera's picture frame inside the full-width viewfinder area.
    case viewfinder(aspect: CGFloat)
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

/// The shooting screen's fixed top-to-bottom arrangement: one header, then the same full-width 4:3 area on every Camera.
/// The viewfinder size never depends on Camera shape, controls, notices or the room below it; a short screen scrolls instead.
struct CaptureColumn: Layout {
    private struct Plan {
        var header: LayoutSubview?
        var viewfinder: LayoutSubview?
        var width: CGFloat
        var headerHeight: CGFloat
        var viewfinderSize: CGSize
        var height: CGFloat { headerHeight + viewfinderSize.height }
    }

    private func plan(_ proposal: ProposedViewSize, _ subviews: Subviews) -> Plan {
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? 390
        let header = subviews.first { $0[CaptureColumnRoleKey.self] == .header }
        let viewfinder = subviews.first {
            if case .viewfinder? = $0[CaptureColumnRoleKey.self] { return true }
            return false
        }
        let headerHeight = header?.sizeThatFits(ProposedViewSize(width: width, height: nil)).height ?? 0
        let viewfinderSize = viewfinder == nil ? .zero : CGSize(width: width, height: width / CaptureAreaGeometry.aspectRatio)
        return Plan(header: header, viewfinder: viewfinder, width: width, headerHeight: headerHeight,
                    viewfinderSize: viewfinderSize)
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
    }
}
