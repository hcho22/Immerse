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
    /// wide as it is tall; anything longer turns in a `TurnedBlock`, which makes room for it, or in a `TurnedInPlace`.
    func turnedWithTheHold() -> some View { modifier(TurnedWithTheHold()) }
}

private struct TurnedWithTheHold: ViewModifier {
    @Environment(\.heldTurn) private var turn
    func body(content: Content) -> some View { content.rotationEffect(turn.angle) }
}

/// A short word or icon that turns in place to read upright as the iPhone is held, and takes the same room in every hold:
/// as wide as it reads upright and as tall as it is long. The control it labels, such as a segment of the focus switch
/// or a Zoom Step in the control strip, so keeps its size and place as the iPhone turns, and only the word turns.
struct TurnedInPlace<Content: View>: View {
    @Environment(\.heldTurn) private var turn
    @ViewBuilder var content: Content

    var body: some View {
        TurnedInPlaceLayout { content.fixedSize().rotationEffect(turn.angle) }
    }
}

private struct TurnedInPlaceLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        // The rotation does not change the size the content reports, which is its upright one in every hold.
        let upright = subviews.first?.sizeThatFits(.unspecified) ?? .zero
        return CGSize(width: upright.width, height: max(upright.width, upright.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center, proposal: .unspecified)
    }
}

/// One view, laid out as a block and turned as a block to read upright as the iPhone is held, taking the room it
/// needs once turned. The screen it sits on stays in the portrait layout, so a block that is wider than it is tall in
/// the portrait hold is a column when the iPhone is on its side.
///
/// With the iPhone on its side the block is laid out `length` wide (its width as the person reads it, so the length of
/// its lines), as tall as that makes it, and turned a quarter turn about its centre, so it takes as much of the screen's
/// width as it is tall and `length` of the screen's height. A `length` of nil lays the block out at its natural size
/// instead. A block that is wider than the screen once turned, as at the largest text sizes, scrolls across the screen,
/// which is up and down for the person holding the iPhone on its side, starting from its top. The block is exactly as
/// wide as it is tall once turned, and its parent puts it where it belongs.
struct TurnedBlock<Content: View>: View {
    @Environment(\.heldTurn) private var turn
    var length: CGFloat?
    /// One view: it is turned as a whole.
    @ViewBuilder var content: Content

    @ViewBuilder var body: some View {
        let block = TurnedLayout(turn: turn, length: length) {
            content.rotationEffect(turn.angle)
        }
        if turn.isSideways {
            // A `ViewThatFits`, which swaps the block's view identity where it starts to overflow (the shooting screen's
            // notices have the only other): a turned block this long holds no state, and no layout of one `Layout`
            // alone can scroll.
            // In a stack of its own, so the identity it takes for each side stays inside the block: a parent that lists
            // several blocks, as the notices' `ViewThatFits` does, would otherwise see them all with one identity.
            ZStack {
                ViewThatFits(in: .horizontal) {
                    block
                    ScrollView(.horizontal, showsIndicators: false) { block }
                        .defaultScrollAnchor(turn == .clockwise ? .trailing : .leading)
                }
                // A new view for each side, since the anchor applies only as the scroll view appears: turned straight from
                // one side to the other, the block starts from its top again, which is at the other end.
                .id(turn)
            }
        } else {
            block
        }
    }
}

private struct TurnedLayout: Layout {
    var turn: HeldTurn
    var length: CGFloat?

    /// The block's size when laid out for the iPhone on its side, before it is turned.
    private func sidewaysSize(_ child: LayoutSubview) -> CGSize {
        child.sizeThatFits(length.map { ProposedViewSize(width: $0, height: nil) } ?? .unspecified)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let child = subviews.first else { return .zero }
        guard turn.isSideways else { return child.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil)) }
        let sideways = sidewaysSize(child)
        return CGSize(width: sideways.height, height: sideways.width)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let child = subviews.first else { return }
        guard turn.isSideways else {
            let size = child.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            child.place(at: CGPoint(x: bounds.minX, y: bounds.minY), anchor: .topLeading, proposal: ProposedViewSize(size))
            return
        }
        let size = sidewaysSize(child)
        // Offered no height, so each text takes the height it measured: offered exactly the measured height, rounded to
        // the screen's pixels, a wrapped text lost its last line.
        child.place(at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center,
                    proposal: ProposedViewSize(width: size.width, height: nil))
    }
}
