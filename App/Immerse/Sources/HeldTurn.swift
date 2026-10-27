import NativeAdapters
import SwiftUI

/// How the iPhone is held, for the words and icons of the shooting screen. The screen itself never turns: it keeps the
/// portrait layout whichever way the iPhone is held, and with the iPhone on its side only its words and icons turn,
/// to read upright, as in the iPhone's own Camera app (the captain, 2026-10-16: "Like iPhone Camera"). Upside-down
/// portrait is not handled: the screen reads as it does upright.
enum HeldTurn: Equatable {
    case upright
    /// The home side on the right (`landscapeLeft`): the screen's right edge is the top as the person sees it.
    case clockwise
    /// The home side on the left (`landscapeRight`): the screen's left edge is the top as the person sees it.
    case counterClockwise

    init(_ held: CaptureFrameOrientation) {
        switch held {
        case .landscapeLeft: self = .clockwise
        case .landscapeRight: self = .counterClockwise
        case .portrait, .portraitUpsideDown: self = .upright
        }
    }

    var isSideways: Bool { self != .upright }

    var angle: Angle {
        switch self {
        case .upright: .zero
        case .clockwise: .degrees(90)
        case .counterClockwise: .degrees(-90)
        }
    }

    /// The edge of a box that is its top as the person holds the iPhone.
    var topEdge: Alignment {
        switch self {
        case .upright: .top
        case .clockwise: .trailing
        case .counterClockwise: .leading
        }
    }

    /// The edge of a box that is its bottom as the person holds the iPhone.
    var bottomEdge: Alignment {
        switch self {
        case .upright: .bottom
        case .clockwise: .leading
        case .counterClockwise: .trailing
        }
    }
}

extension EnvironmentValues {
    @Entry var heldTurn = HeldTurn.upright
}

extension View {
    /// Turns this view about its own centre to read upright as the iPhone is held. For an icon or a button that is as
    /// wide as it is tall; anything longer turns in a `TurnedBlock`, which makes room for it.
    func turnedWithTheHold() -> some View { modifier(TurnedWithTheHold()) }
}

private struct TurnedWithTheHold: ViewModifier {
    @Environment(\.heldTurn) private var turn
    func body(content: Content) -> some View { content.rotationEffect(turn.angle) }
}

/// One view, laid out as a block and turned as a block to read upright as the iPhone is held, taking the room it
/// needs once turned. The screen it sits on stays in the portrait layout, so a block that is wider than it is tall in
/// the portrait hold is a column when the iPhone is on its side.
///
/// With the iPhone on its side the block is laid out `length` wide (its width as the person reads it, so the length of
/// its lines), as tall as that makes it, and turned a quarter turn about its centre, so it takes as much of the screen's
/// width as it is tall and `length` of the screen's height. A `length` of nil lays the block out at its natural size
/// instead, as a row of buttons does. A block that is wider than the screen once turned, as at the largest text sizes,
/// scrolls across the screen, which is up and down for the person holding the iPhone on its side, starting from its top.
///
/// With `reservesLength` the block takes the greater of its two heights in every hold, fills the width it is offered and
/// sits against the edge that is its top as the person holds the iPhone. The Camera's one-line header uses it, so the
/// Viewfinder area below stays the same size and in the same place however the iPhone is held. A reserving block that is
/// offered more height than its length is laid out that long, though never longer than `maximumLength`, at its top.
/// Any other block is exactly as wide as it is tall once turned, and its parent puts it where it belongs.
struct TurnedBlock<Content: View>: View {
    @Environment(\.heldTurn) private var turn
    var length: CGFloat?
    var reservesLength = false
    var maximumLength: CGFloat?
    /// One view: it is turned as a whole.
    @ViewBuilder var content: Content
    /// The width the block is offered, the same in every hold for a reserving block. The scroll view that holds a block
    /// wider than the screen once turned offers it no width, so a reserving block measures its portrait form at this one.
    @State private var offeredWidth: CGFloat?

    var body: some View {
        turned.onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { offeredWidth = $0 }
    }

    @ViewBuilder private var turned: some View {
        let block = TurnedLayout(turn: turn, length: length, reservesLength: reservesLength, maximumLength: maximumLength,
                                 offeredWidth: offeredWidth) {
            content.rotationEffect(turn.angle)
        }
        if turn.isSideways {
            // The one `ViewThatFits`, which swaps the block's view identity where it starts to overflow: only the
            // header turns this far, it holds no state, and no layout of one `Layout` alone can scroll.
            ViewThatFits(in: .horizontal) {
                block
                ScrollView(.horizontal, showsIndicators: false) { block }
                    .defaultScrollAnchor(turn == .clockwise ? .trailing : .leading)
            }
            // A new view for each side, since the anchor applies only as the scroll view appears: turned straight from one
            // side to the other, the block starts from its top again, which is at the other end.
            .id(turn)
        } else {
            block
        }
    }
}

private struct TurnedLayout: Layout {
    var turn: HeldTurn
    var length: CGFloat?
    var reservesLength: Bool
    var maximumLength: CGFloat?
    var offeredWidth: CGFloat?

    private func finite(_ value: CGFloat?) -> CGFloat? { value.flatMap { $0.isFinite ? $0 : nil } }

    /// How long the block's lines run when the iPhone is on its side: `length`, or longer for a reserving block that is
    /// offered more height than that, up to `maximumLength`.
    private func lengthUsed(_ proposal: ProposedViewSize) -> CGFloat? {
        guard let length else { return nil }
        guard reservesLength, let offered = finite(proposal.height) else { return length }
        return max(length, min(offered, maximumLength ?? offered))
    }

    /// The block's size when laid out for the iPhone on its side, before it is turned.
    private func sidewaysSize(_ child: LayoutSubview, _ proposal: ProposedViewSize) -> CGSize {
        child.sizeThatFits(lengthUsed(proposal).map { ProposedViewSize(width: $0, height: nil) } ?? .unspecified)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let child = subviews.first else { return .zero }
        // Inside a scroll view a reserving block is offered no width, and its portrait form is as wide as the screen.
        let width = reservesLength ? finite(proposal.width) ?? offeredWidth : proposal.width
        let upright = child.sizeThatFits(ProposedViewSize(width: width, height: nil))
        // Measured in every hold, so the reserved height never depends on how the iPhone is held.
        let sideways = sidewaysSize(child, proposal)
        let height = reservesLength ? max(upright.height, sideways.width) : (turn.isSideways ? sideways.width : upright.height)
        if turn.isSideways {
            return CGSize(width: reservesLength ? finite(proposal.width) ?? sideways.height : sideways.height, height: height)
        }
        return CGSize(width: upright.width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let child = subviews.first else { return }
        guard turn.isSideways else {
            // Against the top: where a reserving block is taller than its upright form, the room is left below it.
            let size = child.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            child.place(at: CGPoint(x: bounds.minX, y: bounds.minY), anchor: .topLeading, proposal: ProposedViewSize(size))
            return
        }
        let size = sidewaysSize(child, proposal)
        let centerX = turn == .clockwise ? bounds.maxX - size.height / 2 : bounds.minX + size.height / 2
        // Against the top too: where a reserving block is taller than its lines, as when they reach `maximumLength`, the
        // room is left below them. Offered no height, so each text takes the height it measured: offered exactly the
        // measured height, rounded to the screen's pixels, a wrapped text lost its last line.
        child.place(at: CGPoint(x: centerX, y: bounds.minY + size.width / 2), anchor: .center,
                    proposal: ProposedViewSize(width: size.width, height: nil))
    }
}
