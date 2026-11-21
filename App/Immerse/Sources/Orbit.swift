import CoreText
import SwiftUI
import UIKit

/// Orbit, the app's look (the captain, 2026-11-20: "a - keep cream, approve and build it"): black, white and greys, one
/// typeface, circles throughout, the red shutter or record button as the one bright color and a soft cream for each
/// screen's single main action. Its parts are the round 3 canvas's components sheet (K00); every screen is built from
/// them, so a value changes here once.
enum Orbit {
    /// The ground every screen sits on.
    static let ground = Color(hex: 0x000000)
    /// Fields and the Viewfinder: a step below the ground's surfaces.
    static let sunken = Color(hex: 0x0D0D0D)
    /// Bubbles, notes and sheets.
    static let surface = Color(hex: 0x141414)
    /// A round button at rest.
    static let button = Color(hex: 0x1A1A1A)
    /// A pressed button, and the track under a ring.
    static let pressed = Color(hex: 0x262626)
    /// Hairlines and dashed rings.
    static let hairline = Color(hex: 0x333333)
    /// Text, a selected control and progress.
    static let text = Color.white
    /// Body text, 14.1:1 on the ground.
    static let body = Color(hex: 0xD4D4D4)
    /// Labels and secondary lines, 8.3:1 on the ground.
    static let label = Color(hex: 0xA1A1A1)
    /// The smallest grey text, 6.1:1 on the ground.
    static let smallest = Color(hex: 0x8A8A8A)
    /// The marks of a disabled control, never text.
    static let disabledMark = Color(hex: 0x5C5C5C)
    /// Grey words on a white bubble.
    static let onWhiteSecondary = Color(hex: 0x3D3D3D)
    /// The main action, one per screen.
    static let cream = Color(hex: 0xE6D3B3)
    static let creamPressed = Color(hex: 0xCDBB9C)
    static let creamDisabled = Color(hex: 0x2B2822)
    /// The shutter and record button, and nothing else.
    static let shutter = Color(hex: 0xFF3B30)
    static let shutterPressed = Color(hex: 0xD9322A)

    /// The side gutter.
    static let gutter: CGFloat = 16
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// Manrope, bundled under the SIL Open Font License (`Resources/Fonts/OFL.txt`), in the five weights Orbit uses. The
/// fonts register with the process the first time any Orbit text style is read, which is before any view draws one.
enum OrbitFonts {
    enum Weight: String, CaseIterable {
        case regular = "Manrope-Regular", medium = "Manrope-Medium", semibold = "Manrope-SemiBold", bold = "Manrope-Bold"
        case extraBold = "Manrope-ExtraBold"
    }

    private static let registered: Void = {
        for weight in Weight.allCases {
            guard let url = Bundle.main.url(forResource: weight.rawValue, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()

    static func register() { _ = registered }

    /// A Manrope font for UIKit, scaled with Dynamic Type as `style` is.
    static func uiFont(_ weight: Weight, size: CGFloat, relativeTo style: UIFont.TextStyle) -> UIFont {
        register()
        let base = UIFont(name: weight.rawValue, size: size) ?? .systemFont(ofSize: size)
        return UIFontMetrics(forTextStyle: style).scaledFont(for: base)
    }
}

/// The type scale (K00): one typeface, numbers in its tabular figures. Every size follows Dynamic Type from the system
/// style it stands in for.
enum OrbitType {
    /// 40/44 800: a Camera's name on Load Film.
    case display
    /// 56/56 800: the count in a Film's ring.
    case numeral
    /// 32/36 800: screen titles.
    case title
    /// 24/28 700: the big bubble's title, a sheet's title.
    case heading
    /// 17/22 700: buttons, rows, bubbles.
    case headline
    /// 15/22 500: notes and messages.
    case body
    /// 14/20 600: small pills, bar buttons.
    case callout
    /// 13/18 500: secondary lines and captions.
    case footnote
    /// 11/14 700, upper case, tracked 8 percent: state labels and section headings.
    case label

    var size: CGFloat {
        switch self {
        case .display: 40
        case .numeral: 56
        case .title: 32
        case .heading: 24
        case .headline: 17
        case .body: 15
        case .callout: 14
        case .footnote: 13
        case .label: 11
        }
    }

    var weight: OrbitFonts.Weight {
        switch self {
        case .display, .numeral, .title: .extraBold
        case .heading, .headline, .label: .bold
        case .callout: .semibold
        case .body, .footnote: .medium
        }
    }

    var textStyle: Font.TextStyle {
        switch self {
        case .display, .numeral, .title: .largeTitle
        case .heading: .title2
        case .headline: .headline
        case .body: .body
        case .callout: .callout
        case .footnote: .footnote
        case .label: .caption2
        }
    }

    var uiTextStyle: UIFont.TextStyle {
        switch self {
        case .display, .numeral, .title: .largeTitle
        case .heading: .title2
        case .headline: .headline
        case .body: .body
        case .callout: .callout
        case .footnote: .footnote
        case .label: .caption2
        }
    }

    /// Letter spacing in points at the scale's size.
    var tracking: CGFloat {
        switch self {
        case .display, .title: -0.02 * size
        case .numeral: -0.03 * size
        case .heading: -0.01 * size
        case .label: 0.08 * size
        case .headline, .body, .callout, .footnote: 0
        }
    }

    /// The space a line's height adds above Manrope's own, which is 1.37 times its size.
    var lineSpacing: CGFloat {
        switch self {
        case .body: 1.5
        default: 0
        }
    }
}

extension Font {
    /// An Orbit text style, optionally in another of Manrope's weights.
    static func orbit(_ type: OrbitType, weight: OrbitFonts.Weight? = nil) -> Font {
        OrbitFonts.register()
        return .custom((weight ?? type.weight).rawValue, size: type.size, relativeTo: type.textStyle).monospacedDigit()
    }

    /// Manrope at a size of its own, following Dynamic Type from `style`, for a part the scale has no step for.
    static func orbit(size: CGFloat, weight: OrbitFonts.Weight, relativeTo style: Font.TextStyle) -> Font {
        OrbitFonts.register()
        return .custom(weight.rawValue, size: size, relativeTo: style).monospacedDigit()
    }
}

extension View {
    /// Sets an Orbit text style: its font, letter spacing and line height. A label's capitals are its words' own
    /// (`OrbitSectionLabel`), so VoiceOver reads them as written.
    func orbitFont(_ type: OrbitType, weight: OrbitFonts.Weight? = nil) -> some View {
        font(.orbit(type, weight: weight))
            .tracking(type.tracking)
            .lineSpacing(type.lineSpacing)
    }

    /// The whole app's look: always dark, on the black ground, with white as the tint. The tint is a concrete color, since
    /// inside iOS 26 bottom toolbars `Color.accentColor` resolves to system blue.
    func orbitRoot() -> some View {
        tint(Color("AccentColor")).preferredColorScheme(.dark).background(Orbit.ground.ignoresSafeArea())
    }

    /// The black ground under a screen, edge to edge.
    func orbitGround() -> some View {
        background(Orbit.ground.ignoresSafeArea())
    }
}

/// The app-wide parts UIKit draws: navigation bar titles in Manrope on the black ground, white text cursors.
@MainActor
enum OrbitAppearance {
    static func apply() {
        OrbitFonts.register()
        let bar = UINavigationBarAppearance()
        bar.configureWithTransparentBackground()
        bar.titleTextAttributes = [
            .font: OrbitFonts.uiFont(.bold, size: 17, relativeTo: .headline),
            .foregroundColor: UIColor.white,
        ]
        bar.largeTitleTextAttributes = [
            .font: OrbitFonts.uiFont(.extraBold, size: 32, relativeTo: .largeTitle),
            .foregroundColor: UIColor.white,
            .kern: -0.64,
        ]
        let buttons = UIBarButtonItemAppearance()
        buttons.normal.titleTextAttributes = [.font: OrbitFonts.uiFont(.semibold, size: 15, relativeTo: .body)]
        bar.buttonAppearance = buttons
        UINavigationBar.appearance().standardAppearance = bar
        UINavigationBar.appearance().scrollEdgeAppearance = bar
        UINavigationBar.appearance().compactAppearance = bar
        let toolbar = UIToolbarAppearance()
        toolbar.configureWithTransparentBackground()
        UIToolbar.appearance().standardAppearance = toolbar
        UIToolbar.appearance().scrollEdgeAppearance = toolbar
    }
}

// MARK: - Buttons

/// The cream main action, one per screen (K00): a 60-point pill, its word in the headline style, black on cream.
struct OrbitMainActionStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .orbitFont(.headline)
            .labelStyle(OrbitMainActionLabelStyle())
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(isEnabled ? Color.black : Orbit.smallest)
            .padding(.horizontal, 24).padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(isEnabled ? (configuration.isPressed ? Orbit.creamPressed : Orbit.cream) : Orbit.creamDisabled,
                        in: Capsule())
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct OrbitMainActionLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            configuration.icon.accessibilityHidden(true)
            configuration.title.fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The round cream main action (K00): a circle 104 points across or more, with a 2-point cream ring 6 points out. It
/// grows to hold its words at larger text sizes.
struct OrbitRoundMainActionStyle: ButtonStyle {
    var diameter: CGFloat = 104
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let fill = isEnabled ? (configuration.isPressed ? Orbit.creamPressed : Orbit.cream) : Orbit.creamDisabled
        return configuration.label
            .labelStyle(OrbitStackedLabelStyle())
            .font(.orbit(size: 15, weight: .extraBold, relativeTo: .headline))
            .multilineTextAlignment(.center)
            .foregroundStyle(isEnabled ? Color.black : Orbit.smallest)
            .modifier(InscribedCircle(minimum: diameter, fill: fill, ring: fill, ringGap: 6))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// An icon over its word, as the round main action and the Film Stock choice show them.
struct OrbitStackedLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 2) {
            configuration.icon.accessibilityHidden(true)
            configuration.title
        }
    }
}

/// Makes its content's frame a square at least `minimum` across, and as wide as the content's diagonal needs to sit
/// inside a circle of that size.
struct CircleFit: ViewModifier {
    let minimum: CGFloat

    func body(content: Content) -> some View {
        CircleFitLayout(minimum: minimum) { content }
    }
}

private struct CircleFitLayout: Layout {
    let minimum: CGFloat

    /// The width the content wraps in: the inscribed width of the smallest circle, near its middle.
    private var inner: CGFloat { minimum * 0.84 }

    private func side(_ subviews: Subviews, proposal: ProposedViewSize) -> CGFloat {
        guard let content = subviews.first else { return minimum }
        let size = content.sizeThatFits(ProposedViewSize(width: inner, height: nil))
        let diagonal = (size.width * size.width + size.height * size.height).squareRoot() + 4
        let limit = proposal.width.map { $0.isFinite ? $0 : .infinity } ?? .infinity
        return min(max(minimum, diagonal.rounded(.up)), max(minimum, limit))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let side = side(subviews, proposal: proposal)
        return CGSize(width: side, height: side)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center,
                              proposal: ProposedViewSize(width: max(inner, bounds.width * 0.84 - 8), height: nil))
    }
}

/// A round control whose frame, the area VoiceOver and the layout see, is its content's own, at least 44 points each
/// way, with the circle (and its ring, if any) drawn around it: at least `minimum` across, and as wide as the frame's
/// diagonal, so the frame always lies inside the circle. The circle grows to hold its words at larger text sizes, takes
/// taps all the way to its edge, and reaches past the frame, which the layout around it leaves room for.
struct InscribedCircle: ViewModifier {
    let minimum: CGFloat
    let fill: Color
    var ring: Color?
    var ringGap: CGFloat = 6

    func body(content: Content) -> some View {
        InscribedFrameLayout(minimum: minimum) { content }
            .background {
                GeometryReader { frame in
                    let diameter = max(minimum, (frame.size.width * frame.size.width + frame.size.height * frame.size.height).squareRoot())
                    ZStack {
                        if let ring {
                            Circle().strokeBorder(ring, lineWidth: 2)
                                .frame(width: diameter + ringGap * 2 + 4, height: diameter + ringGap * 2 + 4)
                        }
                        Circle().fill(fill).frame(width: diameter, height: diameter)
                    }
                    .position(x: frame.size.width / 2, y: frame.size.height / 2)
                }
                .accessibilityHidden(true)
            }
            // Taps reach the circle's edge; VoiceOver and the audits see the words' own frame, inside the circle.
            .contentShape(.interaction, Circle().inset(by: -minimum / 4))
            .contentShape(.accessibility, Rectangle())
    }
}

private struct InscribedFrameLayout: Layout {
    let minimum: CGFloat

    private func size(_ subviews: Subviews, proposal: ProposedViewSize) -> CGSize {
        guard let content = subviews.first else { return CGSize(width: 44, height: 44) }
        let limit = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? .infinity
        let measured = content.sizeThatFits(ProposedViewSize(width: min(minimum * 0.84, limit), height: nil))
        return CGSize(width: min(max(44, measured.width + 4), max(44, limit)), height: max(44, measured.height + 4))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        size(subviews, proposal: proposal)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center,
                              proposal: ProposedViewSize(width: bounds.width - 4, height: nil))
    }
}

/// A 44-point pill (K00): grey at rest, white for a destructive confirm, which is never red, or outlined.
struct OrbitPillStyle: ButtonStyle {
    enum Kind { case standard, white, outline }
    var kind = Kind.standard
    var minHeight: CGFloat = 44
    /// Whether the pill takes the whole width it is offered, as a dialog's buttons do.
    var fullWidth = false
    /// Whether the pill is a bar button (Done, Cancel): its words in the callout style, at their own width, which a
    /// toolbar would otherwise squeeze.
    var inBar = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let foreground: Color = !isEnabled ? Orbit.disabledMark : kind == .white ? .black : .white
        return configuration.label
            .font(inBar ? .orbit(.callout, weight: kind == .white ? .bold : .semibold)
                : .orbit(size: minHeight > 44 ? 17 : 15, weight: .bold, relativeTo: minHeight > 44 ? .headline : .body))
            .multilineTextAlignment(.center)
            .foregroundStyle(foreground)
            .padding(.horizontal, 18).padding(.vertical, 6)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: minHeight)
            .fixedSize(horizontal: inBar, vertical: false)
            .background { background(pressed: configuration.isPressed) }
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    @ViewBuilder private func background(pressed: Bool) -> some View {
        if !isEnabled {
            Capsule().fill(Orbit.sunken).overlay(Capsule().strokeBorder(Orbit.pressed, lineWidth: 1))
        } else {
            switch kind {
            case .standard: Capsule().fill(pressed ? Orbit.pressed : Orbit.button)
            case .white: Capsule().fill(pressed ? Orbit.body : Color.white)
            case .outline: Capsule().fill(pressed ? Orbit.button : Color.clear)
                    .overlay(Capsule().strokeBorder(Orbit.hairline, lineWidth: 1))
            }
        }
    }
}

/// A round button (K00): 44 points in a bar, 56 in a menu, 60 on the shooting screen. Grey at rest, white with a black
/// mark when selected or emphasized, outlined with a grey mark when disabled.
struct OrbitCircleButtonStyle: ButtonStyle {
    var diameter: CGFloat = 44
    var selected = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(.iconOnly)
            .foregroundStyle(!isEnabled ? Orbit.disabledMark : selected ? Color.black : Color.white)
            .frame(width: diameter, height: diameter)
            .background { OrbitCircleBackground(selected: selected, pressed: configuration.isPressed, enabled: isEnabled) }
            .contentShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// The fill of a round control in each of its states.
struct OrbitCircleBackground: View {
    var selected = false
    var pressed = false
    var enabled = true

    var body: some View {
        if !enabled {
            Circle().fill(Orbit.sunken).overlay(Circle().strokeBorder(Orbit.pressed, lineWidth: 1))
        } else if selected {
            Circle().fill(pressed ? Orbit.body : Color.white)
        } else {
            Circle().fill(pressed ? Orbit.pressed : Orbit.button)
        }
    }
}

/// A labelled action (K00): a 68-point circle with its word 8 points under it, as the photo view's Darkroom and
/// Discard are.
struct OrbitLabelledActionStyle: ButtonStyle {
    var emphasized = false
    var diameter: CGFloat = 68
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(LabelledActionLabelStyle(diameter: diameter, emphasized: emphasized, pressed: configuration.isPressed,
                                                 enabled: isEnabled))
            .contentShape(Rectangle())
    }
}

private struct LabelledActionLabelStyle: LabelStyle {
    let diameter: CGFloat
    let emphasized: Bool
    let pressed: Bool
    let enabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 8) {
            configuration.icon
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(!enabled ? Orbit.disabledMark : emphasized ? Color.black : Color.white)
                .frame(width: diameter, height: diameter)
                .background { OrbitCircleBackground(selected: emphasized, pressed: pressed, enabled: enabled) }
                .scaleEffect(pressed ? 0.94 : 1)
                .animation(.easeOut(duration: 0.12), value: pressed)
            configuration.title
                .font(.orbit(size: 13, weight: .semibold, relativeTo: .footnote))
                .foregroundStyle(enabled ? Orbit.body : Orbit.smallest)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Notes, rings and labels

/// A note (K00): the surface, a 24-point radius, 14/20 text with a white mark. An error is the same note with a white
/// outline and a warning mark, never red, since red is the shutter's alone.
struct OrbitNote<Content: View>: View {
    enum Kind {
        case info, error
        /// A note with a mark of its own, such as the low-storage warning's drive.
        case custom(String, outlined: Bool)
    }
    let kind: Kind
    @ViewBuilder let content: Content
    @ScaledMetric(relativeTo: .callout) private var markSize: CGFloat = 18

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: min(markSize, 26), weight: .medium))
                .foregroundStyle(.white)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) { content }
                .font(.orbit(size: 14, weight: .medium, relativeTo: .callout))
                .foregroundStyle(outlined ? Color.white : Orbit.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .background(Orbit.surface, in: RoundedRectangle(cornerRadius: 24))
        .overlay { if outlined { RoundedRectangle(cornerRadius: 24).strokeBorder(Color.white, lineWidth: 1) } }
    }

    private var symbol: String {
        switch kind {
        case .info: "info.circle"
        case .error: "exclamationmark.triangle"
        case let .custom(symbol, _): symbol
        }
    }

    private var outlined: Bool {
        switch kind {
        case .info: false
        case .error: true
        case let .custom(_, outlined): outlined
        }
    }
}

extension OrbitNote where Content == Text {
    init(_ kind: Kind, _ text: String) {
        self.init(kind: kind) { Text(text) }
    }
}

/// A ring (K00): a white arc over a grey track from 12 o'clock, with round caps: 3 points around a count, 6 around a
/// bubble, 16 around a Development.
struct OrbitRing: View {
    let progress: Double
    var lineWidth: CGFloat = 6
    var track = Orbit.pressed
    var tint = Color.white

    var body: some View {
        ZStack {
            Circle().inset(by: lineWidth / 2).stroke(track, lineWidth: lineWidth)
            Circle().inset(by: lineWidth / 2)
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .accessibilityHidden(true)
    }
}

/// A dashed ring, as a Developing bubble and the empty Journal draw.
struct OrbitDashedRing: View {
    var lineWidth: CGFloat = 2
    var dash: [CGFloat] = [3, 6]
    var color = Orbit.disabledMark

    var body: some View {
        Circle().inset(by: lineWidth / 2)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, dash: dash))
            .accessibilityHidden(true)
    }
}

/// A state label or section heading (K00's Label): 11/14 bold, upper case, tracked, grey.
struct OrbitSectionLabel: View {
    let text: String
    var color = Orbit.label

    init(_ text: String, color: Color = Orbit.label) {
        self.text = text
        self.color = color
    }

    var body: some View {
        // Shown in capitals, read as written.
        Text(SpokenText.shown(text.uppercased())).orbitFont(.label).foregroundStyle(color)
            .accessibilityLabel(Text(SpokenText.shown(text)))
            .accessibilityAddTraits(.isHeader)
    }
}

/// A chip (B02): a 32-point grey capsule with a short fact in it. Its words wrap at large text sizes and the capsule
/// becomes a rounded box around them.
struct OrbitChip: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(SpokenText.shown(text))
            .font(.orbit(size: 13, weight: .semibold, relativeTo: .footnote))
            .foregroundStyle(Orbit.body)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14).padding(.vertical, 7)
            .frame(minHeight: 32)
            .background(Orbit.button, in: RoundedRectangle(cornerRadius: 16))
    }
}

/// A round option of a choice (B03, B04): a circle with an icon over its word, white with a white ring 5 points out
/// when chosen. It grows to hold its word at larger text sizes.
struct OrbitRoundOptionStyle: ButtonStyle {
    let selected: Bool
    var diameter: CGFloat = 96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(OrbitStackedLabelStyle())
            .font(.orbit(size: 13, weight: .bold, relativeTo: .footnote))
            .multilineTextAlignment(.center)
            .foregroundStyle(selected ? Color.black : Color.white)
            .modifier(InscribedCircle(minimum: diameter,
                                      fill: selected ? (configuration.isPressed ? Orbit.body : .white)
                                          : configuration.isPressed ? Orbit.pressed : Orbit.button,
                                      ring: selected ? .white : nil, ringGap: 5))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// A sheet or dialog's card (C03): the surface with 32-point corners, 24 points inside.
struct OrbitCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 16) { content }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(Orbit.surface, in: RoundedRectangle(cornerRadius: 32))
    }
}

/// A pill row (A04): the surface, as round as it is tall, at least 56 points, its title left and its value right.
struct OrbitRowBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 22).padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(Orbit.surface, in: RoundedRectangle(cornerRadius: 28))
    }
}

extension View {
    func orbitRow() -> some View { modifier(OrbitRowBackground()) }
}
