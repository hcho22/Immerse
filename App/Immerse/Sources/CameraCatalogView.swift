import EntitlementCore
import FilmDomain
import SwiftUI

struct CameraCatalogView: View {
    @Environment(\.dismiss) private var dismiss
    var loaded: (Film) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach([CameraMedium.photo, .movie], id: \.rawValue) { medium in
                    Section(medium == .photo ? "Photo" : "Movie") {
                        ForEach(CameraCatalog.all.filter { $0.medium == medium }) { camera in
                            NavigationLink {
                                LoadFilmView(camera: camera, loaded: loaded)
                            } label: {
                                HStack(spacing: 16) {
                                    Image(systemName: camera.symbol).font(.system(size: 24)).frame(width: 36)
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 5) {
                                        camera.shortNameText.font(.system(.title3, design: .serif))
                                        camera.capacityText.font(.caption).foregroundStyle(.secondary)
                                    }.padding(.vertical, 8)
                                }
                            }.accessibilityIdentifier("camera-\(camera.id.rawValue)")
                        }
                    }
                }
            }
            .navigationTitle("Choose a Camera")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly)
                }
            }
        }
    }
}

private struct LoadFilmView: View {
    @Environment(JournalModel.self) private var model
    let camera: CameraPackage
    var loaded: (Film) -> Void
    @State private var title = ""
    @State private var orientation = MovieOrientation.portrait
    @State private var loading = false
    @State private var error: String?
    @State private var samples = false

    var body: some View {
        Group {
            #if DEBUG
            if model.testingUnlock.enabled {
                form {
                    TestingUnlockNotice()
                    Text(LoadCopy.fixed(medium: camera.medium))
                        .font(.footnote).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                }
            } else {
                form { entitlement }
            }
            #else
            form { entitlement }
            #endif
        }
        .navigationTitle(camera.shortNameText)
        .sheet(isPresented: $samples) { CameraSamplesView(camera: camera) }
        .task { if title.isEmpty { title = suggestedTitle } }
        .interactiveDismissDisabled(loading)
    }

    /// The Load Film form around its access rows. The testing unlock chooses a whole form, not conditional
    /// rows: inside a conditional, the entitlement line drew a clipped-text audit finding
    /// (Evidence/NativeApp/testing-unlock-debug.md).
    private func form(@ViewBuilder access: () -> some View) -> some View {
        Form {
            if let catalog = model.mediaCatalog, !catalog.assets(for: camera.id, purpose: .cameraSample).isEmpty {
                Section {
                    Button("Camera samples", systemImage: "photo.on.rectangle") { samples = true }
                }
            }
            Section {
                LabeledContent("Capacity") { camera.capacityText }
                Text(camera.revealLabel)
                Text(camera.controlsLabel).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                Text(camera.lookLabel).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                if let note = camera.viewfinderNote {
                    Text(note).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                }
                if camera.medium == .movie {
                    HStack {
                        Image(systemName: "mic.slash").font(.system(size: 20)).accessibilityHidden(true)
                        Text("Silent capture").fixedSize(horizontal: false, vertical: true)
                    }.accessibilityElement(children: .combine)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Movie Orientation").fixedSize(horizontal: false, vertical: true)
                        OrientationChoice(selection: $orientation)
                    }
                }
            }
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Film title").font(.headline).foregroundStyle(Color.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("film-title-heading")
                        .accessibilityAddTraits(.isHeader)
                    FilmTitleField(placeholder: "Title", text: $title)
                        .accessibilityLabel("Film title").accessibilityIdentifier("film-title")
                }
            }
            Section { access() }
            Section { NavigationLink("Subscription") { SubscriptionView() } }
            if let error { Section { Text(error).foregroundStyle(.red) } }
            Section {
                Button {
                    loading = true
                    Task {
                        defer { loading = false }
                        do {
                            let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
                            let film = try await model.load(camera: camera, title: name.isEmpty ? suggestedTitle : name,
                                                            orientation: orientation)
                            loaded(film)
                        } catch {
                            switch error {
                            case JournalError.cameraDenied: self.error = "Camera access is off. No Film was loaded. Allow Camera in iPhone Settings."
                            case JournalError.trialInProgress: self.error = "A Trial Film is already waiting in your Journal. Open it or delete that empty Film first."
                            case JournalError.subscriptionUnavailable: self.error = "This iPhone's Trial is used. Subscriptions are not available in this build. Existing Films remain usable."
                            case JournalError.subscriptionRequired: self.error = "This iPhone's Trial is used. Subscribe or restore a current subscription to load another Film. Existing Films remain usable."
                            default: self.error = FailureCopy.message(for: error)
                            }
                        }
                    }
                } label: {
                    HStack { Text("Load Film"); Spacer(); if loading { ProgressView() } else { Image(systemName: "camera") } }
                }.disabled(loading).accessibilityIdentifier("load-film")
            }
        }
    }

    private var suggestedTitle: String {
        "\(camera.shortName) - Roll #\(String(format: "%02d", model.films.filter { $0.camera.id == camera.id }.count + 1))"
    }

    @ViewBuilder private var entitlement: some View {
        Label(entitlementLabel, systemImage: "ticket").accessibilityIdentifier("load-entitlement")
        Text(LoadCopy.note(access: model.billing.access, trial: model.trialState, medium: camera.medium,
                           subscriptionsAvailable: model.billing.configured))
            .font(.footnote).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("load-note")
    }

    private var entitlementLabel: String {
        if model.billing.access == .active { return "Subscription active" }
        switch model.trialState {
        case .unused: return "One Trial Film on this iPhone"
        case .emptyFilmInProgress: return "Trial Film already loaded"
        case .consumed: return "This iPhone's Trial is used"
        case nil: return model.trialError == nil ? "Checking Trial status" : "Trial status unavailable"
        }
    }
}

/// What loading this Film uses and what stays fixed, matching `TrialCoordinator.load` and the
/// Load Film errors. Builds without subscription products never suggest subscribing.
enum LoadCopy {
    static func note(access: SubscriptionAccess, trial: DeviceTrialState?, medium: CameraMedium,
                     subscriptionsAvailable: Bool) -> String {
        let entitlement: String? = if access == .active {
            "This Film is included in your subscription."
        } else {
            switch trial {
            case .unused: "The first saved capture uses this iPhone's Trial."
            case .emptyFilmInProgress: subscriptionsAvailable
                ? "This iPhone's Trial Film is already loaded. Open or delete it first, or subscribe."
                : "This iPhone's Trial Film is already loaded. Open or delete it first."
            case .consumed: subscriptionsAvailable
                ? "This iPhone's Trial is used. A subscription is required to load another Film."
                : "This iPhone's Trial is used. Subscriptions are not available in this build."
            case nil: nil
            }
        }
        return [entitlement, fixed(medium: medium)].compactMap { $0 }.joined(separator: " ")
    }

    static func fixed(medium: CameraMedium) -> String {
        medium == .movie ? "Your Camera and Movie Orientation cannot change after loading."
            : "Your Camera cannot change after loading."
    }
}

/// Segmented-style choice whose text follows Dynamic Type; `UISegmentedControl` titles stay at one size.
/// Its height follows the text, matching the native control's 32 points at the default size.
private struct OrientationChoice: View {
    @Binding var selection: MovieOrientation

    var body: some View {
        // One layout keeps both options' identity across text sizes. `ViewThatFits` swapped in a
        // separate copy of the buttons when the text grew, which Xcode's Dynamic Type audit reports as
        // text that cannot change size, and it kept the side-by-side copy while "Landscape" broke mid-word.
        SegmentLayout(spacing: 2) { options }
        .padding(2)
        .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Movie Orientation")
    }

    @ViewBuilder private var options: some View {
        option(.portrait, "Portrait")
        option(.landscape, "Landscape")
    }

    private func option(_ value: MovieOrientation, _ title: String) -> some View {
        Button { selection = value } label: {
            Text(title).fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 4).frame(maxWidth: .infinity).padding(.horizontal, 8)
                .background(selection == value ? Self.selectedFill : .clear, in: RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection == value ? .isSelected : [])
    }

    private static let selectedFill = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? .systemGray3 : .systemBackground })
}

/// Places its subviews side by side in equal widths when each fits on its own unwrapped width, and
/// stacks them at full width otherwise.
private struct SegmentLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? idealWidth(subviews)
        if fitsSideBySide(width, subviews) {
            let height = subviews.map { $0.sizeThatFits(ProposedViewSize(width: segment(width, subviews), height: nil)).height }.max() ?? 0
            return CGSize(width: width, height: height)
        }
        let heights = subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }
        return CGSize(width: width, height: heights.reduce(0, +) + spacing * CGFloat(max(subviews.count - 1, 0)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        if fitsSideBySide(bounds.width, subviews) {
            let width = segment(bounds.width, subviews)
            for (index, subview) in subviews.enumerated() {
                let x = bounds.minX + CGFloat(index) * (width + spacing)
                subview.place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(width: width, height: bounds.height))
            }
            return
        }
        var y = bounds.minY
        for subview in subviews {
            let height = subview.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil)).height
            subview.place(at: CGPoint(x: bounds.minX, y: y), proposal: ProposedViewSize(width: bounds.width, height: height))
            y += height + spacing
        }
    }

    private func fitsSideBySide(_ width: CGFloat, _ subviews: Subviews) -> Bool {
        idealWidth(subviews) <= width
    }

    /// The width that shows every subview at its widest unwrapped size in equal segments.
    private func idealWidth(_ subviews: Subviews) -> CGFloat {
        let widest = subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        return widest * CGFloat(subviews.count) + spacing * CGFloat(max(subviews.count - 1, 0))
    }

    private func segment(_ width: CGFloat, _ subviews: Subviews) -> CGFloat {
        (width - spacing * CGFloat(max(subviews.count - 1, 0))) / CGFloat(max(subviews.count, 1))
    }
}

/// Places its one subview at its ideal height over the space its minimum height takes in the layout, centered on
/// it to the pixel as `FilmTitleTextView.InsetTextView` centers its text, so the subview's frame can reach past the
/// space the layout gives it.
private struct OverhangingHeight: Layout {
    var scale: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        subviews[0].sizeThatFits(ProposedViewSize(width: proposal.width, height: 0))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let full = subviews[0].sizeThatFits(ProposedViewSize(width: bounds.width, height: nil)).height
        let above = FilmTitleTextView.InsetTextView.topInset(extra: full - bounds.height, scale: scale)
        subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.minY - above), anchor: .topLeading,
                          proposal: ProposedViewSize(width: bounds.width, height: nil))
    }
}

/// The Film title field: a wrapping text view whose frame, the area that takes a tap and that accessibility
/// reports, is at least 44 points tall at every text size, while its text sits where a SwiftUI field's would.
/// SwiftUI's vertical `TextField` keeps its frame at its text's height whatever frame surrounds it, 19 points at XS,
/// which Xcode's audit reports as too small to tap (Evidence/NativeApp/title-field-hit-area-056.md).
private struct FilmTitleField: View {
    let placeholder: String
    @Binding var text: String

    @Environment(\.displayScale) private var scale

    var body: some View {
        OverhangingHeight(scale: scale) { FilmTitleTextView(placeholder: placeholder, text: $text) }
    }
}

private struct FilmTitleTextView: UIViewRepresentable {
    static let minimumHeight: CGFloat = 44
    let placeholder: String
    @Binding var text: String

    func makeUIView(context: Context) -> InsetTextView {
        let view = InsetTextView()
        view.delegate = context.coordinator
        view.placeholderLabel.text = placeholder
        view.tintColor = UIColor(named: "AccentColor")
        return view
    }

    func updateUIView(_ view: InsetTextView, context: Context) {
        context.coordinator.text = $text
        if view.text != text { view.text = text; view.textDidChange() }
    }

    /// A zero height asks for the text alone; any other proposal gets the text grown to the minimum tap height.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: InsetTextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite else { return nil }
        let natural = uiView.naturalHeight(width: width)
        return CGSize(width: width, height: proposal.height == 0 ? natural : max(Self.minimumHeight, natural))
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }
        func textViewDidChange(_ view: UITextView) {
            text.wrappedValue = view.text
            (view as? InsetTextView)?.textDidChange()
        }
    }

    /// Centers its text in any extra height, so the text stays where the layout put it.
    final class InsetTextView: UITextView {
        let placeholderLabel = UILabel()
        private let sizer = UITextView()
        private var haloRect = CGRect.null

        init() {
            super.init(frame: .zero, textContainer: nil)
            backgroundColor = .clear
            isScrollEnabled = false
            textContainer.lineFragmentPadding = 0
            textContainerInset = .zero
            font = .preferredFont(forTextStyle: .body)
            adjustsFontForContentSizeCategory = true
            textColor = .label
            placeholderLabel.font = font
            placeholderLabel.adjustsFontForContentSizeCategory = true
            placeholderLabel.textColor = .placeholderText
            placeholderLabel.numberOfLines = 0
            placeholderLabel.isAccessibilityElement = false
            addSubview(placeholderLabel)
            sizer.isScrollEnabled = false
            sizer.textContainer.lineFragmentPadding = 0
            sizer.textContainerInset = .zero
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

        /// A text field to accessibility, as SwiftUI's vertical field is: `UITextView` adds one more trait bit than
        /// SwiftUI's field reports (bit 47, measured), which makes accessibility report it as a text view.
        override var accessibilityTraits: UIAccessibilityTraits {
            get { super.accessibilityTraits.subtracting(UIAccessibilityTraits(rawValue: 1 << 47)) }
            set { super.accessibilityTraits = newValue }
        }

        /// The text's own rect, where SwiftUI's field had its whole frame. The frame around it reaches over the
        /// bottom of the heading at the smaller sizes, so the VoiceOver cursor and the focus ring outline this instead.
        private var textRect: CGRect { bounds.inset(by: textContainerInset) }

        override var accessibilityPath: UIBezierPath? {
            get { UIAccessibility.convertToScreenCoordinates(UIBezierPath(rect: textRect), in: self) }
            set { super.accessibilityPath = newValue }
        }

        /// The text's own height at `width`, measured without the insets and rounded up to whole points, as SwiftUI's
        /// vertical `TextField` sizes itself at every text size (two pixels taller than the text view at AX XXL).
        func naturalHeight(width: CGFloat) -> CGFloat {
            sizer.font = font
            sizer.text = text
            return sizer.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height.rounded(.up)
        }

        /// The part of the extra height above the text: half, to the pixel, so every edge stays on the pixel grid
        /// and the frame is exactly the minimum height.
        nonisolated static func topInset(extra: CGFloat, scale: CGFloat) -> CGFloat {
            let scale = max(scale, 1)
            return (max(0, extra) / 2 * scale).rounded(.down) / scale
        }

        func textDidChange() {
            placeholderLabel.isHidden = !text.isEmpty
            setNeedsLayout()
        }

        override func layoutSubviews() {
            let extra = bounds.height - naturalHeight(width: bounds.width)
            let top = Self.topInset(extra: extra, scale: traitCollection.displayScale)
            let insets = UIEdgeInsets(top: top, left: 0, bottom: max(0, extra - top), right: 0)
            if textContainerInset != insets { textContainerInset = insets }
            if haloRect != textRect { haloRect = textRect; focusEffect = UIFocusHaloEffect(rect: textRect) }
            super.layoutSubviews()
            placeholderLabel.isHidden = !text.isEmpty
            let size = placeholderLabel.sizeThatFits(CGSize(width: bounds.width, height: .greatestFiniteMagnitude))
            placeholderLabel.frame = CGRect(x: 0, y: top, width: bounds.width, height: size.height)
        }
    }
}
