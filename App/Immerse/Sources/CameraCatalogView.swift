import EntitlementCore
import FilmDomain
import SwiftUI

/// Choose a Camera (B01): the five Cameras on a dial, the Photo Cameras on its upper arc and the Movie Cameras on its
/// lower one, with the chosen Camera in its middle and its look beneath, and Choose to go on to Load Film. At the larger
/// text sizes, where the dial cannot hold the Cameras' names, they stand in a column instead.
struct CameraCatalogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var loaded: (Film) -> Void
    @State private var chosen = CameraCatalog.all.first { $0.medium == .photo } ?? CameraCatalog.all[0]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if dynamicTypeSize >= .xxLarge { column } else { CameraDial(chosen: $chosen).padding(.top, 8) }
                    VStack(spacing: 8) {
                        ForEach(chosen.lookLines(filmStock: nil), id: \.self) { line in
                            Text(SpokenText.shown(line)).orbitFont(.body).foregroundStyle(Orbit.body)
                        }
                        Text(chosen.revealLabel).orbitFont(.footnote).foregroundStyle(Orbit.label)
                    }
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 16)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaBar(edge: .bottom, spacing: 8) {
                NavigationLink {
                    LoadFilmView(camera: chosen, loaded: loaded)
                } label: {
                    Text(SpokenText.shown("Choose \(chosen.shortName)"))
                }
                .primaryAction()
                .accessibilityIdentifier("choose-camera")
                .padding(.horizontal, 24).padding(.bottom, 8)
            }
            .orbitSheetGround(screen: true)
            .navigationTitle("Choose a Camera")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }.buttonStyle(OrbitCircleButtonStyle())
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
        .orbitSheet(screen: true)
    }

    /// The Cameras in a column under their Photo and Movie headings, for the larger text sizes.
    private var column: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach([CameraMedium.photo, .movie], id: \.rawValue) { medium in
                OrbitSectionLabel(medium == .photo ? "Photo" : "Movie").padding(.top, 8).padding(.leading, 4)
                ForEach(CameraCatalog.all.filter { $0.medium == medium }) { camera in
                    Button { chosen = camera } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            camera.shortNameText.orbitFont(.headline)
                            camera.capacityText.orbitFont(.footnote)
                                .foregroundStyle(camera == chosen ? Orbit.onWhiteSecondary : Orbit.label)
                        }
                        .foregroundStyle(camera == chosen ? Color.black : Color.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 22).padding(.vertical, 12)
                        .background(camera == chosen ? Color.white : Orbit.button, in: RoundedRectangle(cornerRadius: 28))
                        .contentShape(RoundedRectangle(cornerRadius: 28))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(camera == chosen ? .isSelected : [])
                    .accessibilityIdentifier("camera-\(camera.id.rawValue)")
                }
            }
        }
        .padding(.horizontal, Orbit.gutter)
    }
}

/// The dial (B01): a dashed orbit 300 points across with the Photo Cameras on its upper arc and the Movie Cameras on its
/// lower one, each an 84-point circle, white with a white ring when chosen, and the chosen Camera in its middle.
private struct CameraDial: View {
    @Binding var chosen: CameraPackage
    /// Where each Camera sits on the orbit, in degrees from the top, clockwise.
    private static let angles: [CameraID: Double] = [
        .disposable1990s: -60, .instant1970s: 0, .mediumFormat6x6: 60, .cinema16mm: -135, .super8HomeMovie: 135,
    ]
    private static let radius: CGFloat = 150
    private static let option: CGFloat = 84

    var body: some View {
        let photo = CameraCatalog.all.filter { $0.medium == .photo }
        let movie = CameraCatalog.all.filter { $0.medium == .movie }
        VStack(spacing: 0) {
            OrbitSectionLabel("Photo").frame(height: 14)
            // The orbit's middle sits 200 points down, which leaves room above the chosen Camera's ring at the top and
            // below the Movie Cameras at the bottom.
            ZStack {
                OrbitDashedRing(lineWidth: 1, dash: [2, 6], color: Orbit.hairline)
                    .frame(width: Self.radius * 2, height: Self.radius * 2)
                ForEach(photo) { option($0) }
                summary
                ForEach(movie) { option($0) }
            }
            .offset(y: 22)
            .frame(width: 390, height: 356)
            .padding(.top, 16)
            OrbitSectionLabel("Movie").frame(height: 14)
        }
        .frame(maxWidth: .infinity)
    }

    private func option(_ camera: CameraPackage) -> some View {
        let angle = (Self.angles[camera.id] ?? 0) * .pi / 180
        let selected = camera == chosen
        return Button { chosen = camera } label: {
            VStack(spacing: 1) {
                camera.shortNameText.font(.orbit(size: camera.shortName.count > 8 ? 12 : 14, weight: .bold, relativeTo: .subheadline))
                Text(Self.amount(camera)).font(.orbit(size: 11, weight: .semibold, relativeTo: .caption))
                    .foregroundStyle(selected ? Orbit.onWhiteSecondary : Orbit.label)
            }
            .lineLimit(1)
            .foregroundStyle(selected ? Color.black : Color.white)
            .padding(.horizontal, 6)
            .frame(minWidth: Self.option, minHeight: Self.option)
            .background { OrbitCircleBackground(selected: selected) }
            .background { if selected { Circle().strokeBorder(Color.white, lineWidth: 2).padding(-7) } }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(camera.shortNameText)
        .accessibilityValue(camera.capacitySpokenLabel)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("camera-\(camera.id.rawValue)")
        .offset(x: Self.radius * sin(angle), y: -Self.radius * cos(angle))
    }

    /// "27" or "3:20": the capacity on a dial option.
    private static func amount(_ camera: CameraPackage) -> String {
        switch camera.capacity {
        case let .exposures(count): String(count)
        case let .seconds(seconds): MovieDurationText.clock(seconds)
        }
    }

    /// The chosen Camera in the dial's middle: its picture shape, its name and capacity.
    private var summary: some View {
        VStack(spacing: 6) {
            CameraShapeMark(camera: chosen, scale: 0.5)
            chosen.shortNameText.orbitFont(.heading, weight: .extraBold).foregroundStyle(.white)
            chosen.capacityText.orbitFont(.footnote).foregroundStyle(Orbit.label)
        }
        .frame(width: 180, height: 180)
        .background(Orbit.surface, in: Circle())
        .overlay(Circle().strokeBorder(Orbit.hairline, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

/// A Camera's picture shape in grey (B01, B02): the Instant's white card, the Disposable's upright 3:2, the 6×6's
/// square, and a 4:3 frame for a Movie Camera.
struct CameraShapeMark: View {
    let camera: CameraPackage
    var scale: CGFloat = 1

    var body: some View {
        Group {
            switch camera.id {
            case .instant1970s:
                VStack { Rectangle().fill(Orbit.disabledMark).frame(width: 82 * scale, height: 82 * scale) }
                    .padding(.top, 8 * scale)
                    .frame(width: 98 * scale, height: 119 * scale, alignment: .top)
                    .background(Color(hex: 0xF2F2F2))
            case .disposable1990s: Rectangle().fill(Color(hex: 0x3A3A3A)).frame(width: 66 * scale, height: 99 * scale)
            case .mediumFormat6x6: Rectangle().fill(Color(hex: 0x4A4A4A)).frame(width: 84 * scale, height: 84 * scale)
            case .super8HomeMovie, .cinema16mm:
                Rectangle().fill(Color(hex: 0x3A3A3A)).frame(width: 96 * scale, height: 72 * scale)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct LoadFilmView: View {
    @Environment(JournalModel.self) private var model
    let camera: CameraPackage
    var loaded: (Film) -> Void
    @State private var title = ""
    @State private var orientation = MovieOrientation.portrait
    /// The Film Stock Load Film confirms, shown and loaded only on the Cameras that offer one (ADR 0014).
    @State private var filmStock: FilmStock
    @State private var loading = false
    @State private var error: String?
    @State private var samples = false

    init(camera: CameraPackage, loaded: @escaping (Film) -> Void) {
        self.camera = camera
        self.loaded = loaded
        _filmStock = State(initialValue: camera.defaultFilmStock ?? .color)
    }

    var body: some View {
        GeometryReader { screen in
            ScrollView {
                VStack(spacing: 14) {
                    if let warning = model.storage.warning(for: .capture) { LowStorageNotice(text: warning) }
                    identity
                    choices
                    titleField
                    access
                    if let error { OrbitNote(.error, error) }
                    Spacer(minLength: 12)
                    loadButton
                }
                .padding(.horizontal, Orbit.gutter)
                .padding(.bottom, 12)
                .frame(minHeight: screen.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .orbitSheetGround(screen: true)
        .navigationTitle(SpokenText.title(camera.shortName))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // The bar names the step (B02); the Camera's name is the screen's own heading.
            ToolbarItem(placement: .principal) {
                Text("Load Film").orbitFont(.label).foregroundStyle(Orbit.label).accessibilityHidden(true)
            }
        }
        .sheet(isPresented: $samples) { CameraSamplesView(camera: camera) }
        .task { if title.isEmpty { title = suggestedTitle } }
        .task { await model.storage.refresh() }
        .interactiveDismissDisabled(loading)
    }

    /// The Camera's disc with its capacity, its name, what it does and how it develops (B02, B04).
    @ViewBuilder private var identity: some View {
        let capacity = capacityDisc
        if camera.medium == .movie {
            HStack(spacing: 16) {
                capacity
                VStack(alignment: .leading, spacing: 4) {
                    name
                    looks(alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 4)
            chips
        } else {
            capacity
            name
            chips
            looks(alignment: .center)
        }
        if let catalog = model.mediaCatalog, !catalog.assets(for: camera.id, purpose: .cameraSample).isEmpty {
            Button("Camera samples", systemImage: "photo.on.rectangle") { samples = true }
                .buttonStyle(OrbitPillStyle())
        }
    }

    private var name: some View {
        camera.shortNameText.orbitFont(.display).foregroundStyle(.white)
            .accessibilityAddTraits(.isHeader)
    }

    /// The disc: a Photo Camera's shape with its exposures on a white badge, or a Movie Camera's time.
    @ViewBuilder private var capacityDisc: some View {
        Group {
            if camera.medium == .movie {
                VStack(spacing: 4) {
                    Text(Self.amount(camera)).font(.orbit(size: 26, weight: .extraBold, relativeTo: .title2))
                    Text("OF FILM").font(.orbit(size: 9, weight: .bold, relativeTo: .caption2)).tracking(0.54)
                        .foregroundStyle(Orbit.label)
                }
                .foregroundStyle(.white)
                .frame(width: 104, height: 104)
                .background(Orbit.surface, in: Circle())
                .overlay(Circle().strokeBorder(Orbit.pressed, lineWidth: 1))
            } else {
                CameraShapeMark(camera: camera)
                    .frame(width: 170, height: 170)
                    .background(Orbit.surface, in: Circle())
                    .overlay(Circle().strokeBorder(Orbit.pressed, lineWidth: 1))
                    .overlay(alignment: .bottomTrailing) {
                        VStack(spacing: 2) {
                            Text(Self.amount(camera)).font(.orbit(size: 22, weight: .extraBold, relativeTo: .title3))
                            Text("EXPOSURES").font(.orbit(size: 8, weight: .bold, relativeTo: .caption2)).tracking(0.48)
                        }
                        .foregroundStyle(.black)
                        .frame(width: 66, height: 66)
                        .background(Color.white, in: Circle())
                        .background(Circle().fill(Color.black).padding(-4))
                        .offset(x: 10, y: -4)
                    }
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Capacity, ") + Text(camera.capacitySpokenLabel))
        .accessibilityAddTraits(.isStaticText)
    }

    private static func amount(_ camera: CameraPackage) -> String {
        switch camera.capacity {
        case let .exposures(count): String(count)
        case let .seconds(seconds): MovieDurationText.clock(seconds)
        }
    }

    /// What the Camera does, as chips (B02): when it reveals, then each of its controls. VoiceOver reads the controls as
    /// the one sentence they are.
    private var chips: some View {
        ChipFlow {
            OrbitChip(camera.revealLabel)
            ForEach(Self.chipWords(camera.controlsLabel), id: \.self) { OrbitChip($0).accessibilityHidden(true) }
        }
        .overlay {
            Color.clear
                .accessibilityElement()
                .accessibilityLabel(SpokenText.of(camera.controlsLabel))
                .accessibilityAddTraits(.isStaticText)
        }
    }

    /// The controls line in its parts, each begun with a capital.
    private static func chipWords(_ line: String) -> [String] {
        line.components(separatedBy: "; ").map { $0.prefix(1).uppercased() + $0.dropFirst() }
    }

    private func looks(alignment: TextAlignment) -> some View {
        VStack(alignment: alignment == .center ? .center : .leading, spacing: 4) {
            ForEach(camera.lookLines(filmStock: camera.filmStocks.isEmpty ? nil : filmStock), id: \.self) { line in
                Text(SpokenText.shown(line))
            }
        }
        .orbitFont(.footnote).foregroundStyle(Orbit.label)
        .multilineTextAlignment(alignment)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// The Film Stock and Movie Orientation, as round options (B03, B04), and the Movie's sound line.
    @ViewBuilder private var choices: some View {
        if !camera.filmStocks.isEmpty {
            RoundChoice(title: "Film Stock", options: camera.filmStocks.map {
                (value: $0, title: $0.label, symbol: $0 == .color ? "circle.hexagongrid" : "circle.lefthalf.filled")
            }, selection: $filmStock)
        }
        if camera.medium == .movie {
            RoundChoice(title: "Movie Orientation", options: [
                (value: MovieOrientation.portrait, title: "Portrait", symbol: "rectangle.portrait"),
                (value: .landscape, title: "Landscape", symbol: "rectangle"),
            ], selection: $orientation, diameter: 88)
        }
        if let sound = camera.loadSoundLabel {
            Text(sound).orbitFont(.footnote).foregroundStyle(Orbit.label).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("load-film-sound")
        }
    }

    /// The Film title (B02): its label, and a round field on the sunken ground.
    private var titleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Film title").orbitFont(.label).foregroundStyle(Orbit.label)
                .padding(.leading, 20)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("film-title-heading")
                .accessibilityAddTraits(.isHeader)
            FilmTitleField(placeholder: "Title", text: $title)
                .accessibilityLabel("Film title").accessibilityIdentifier("film-title")
                .padding(.horizontal, 22).padding(.vertical, 6)
                .frame(minHeight: 56)
                .background(Orbit.sunken, in: RoundedRectangle(cornerRadius: 28))
                .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(Orbit.hairline, lineWidth: 1))
        }
        .padding(.top, 4)
    }

    /// What loading uses and what stays fixed, with the way to the Subscription (B02). The testing unlock chooses a whole
    /// block, not conditional rows: inside a conditional, the entitlement line drew a clipped-text audit finding
    /// (Evidence/NativeApp/testing-unlock-debug.md).
    @ViewBuilder private var access: some View {
        #if DEBUG
        if model.testingUnlock.enabled {
            OrbitNote(kind: .custom("hammer", outlined: false)) {
                TestingUnlockNotice()
                Text(LoadCopy.fixed(camera: camera)).foregroundStyle(Orbit.label)
                subscriptionLink
            }
        } else {
            entitlement
        }
        #else
        entitlement
        #endif
    }

    private var entitlement: some View {
        OrbitNote(kind: .custom(model.billing.access == .active ? "checkmark.circle" : "ticket", outlined: false)) {
            Text(entitlementLabel).orbitFont(.body, weight: .bold).foregroundStyle(.white)
                .accessibilityIdentifier("load-entitlement")
            Text(LoadCopy.note(access: model.billing.access, trial: model.trialState, camera: camera,
                               subscriptionsAvailable: model.billing.configured))
                .orbitFont(.footnote).foregroundStyle(Orbit.label)
                .accessibilityIdentifier("load-note")
            subscriptionLink
        }
    }

    private var subscriptionLink: some View {
        NavigationLink { SubscriptionView() } label: {
            Text("Subscription").orbitFont(.footnote, weight: .bold).underline().foregroundStyle(.white)
                .padding(.vertical, 13)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Load Film (B02): the round cream main action, 104 points across with its ring.
    private var loadButton: some View {
        Button {
            loading = true
            Task {
                defer { loading = false }
                do {
                    let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    let film = try await model.load(camera: camera, title: name.isEmpty ? suggestedTitle : name,
                                                    orientation: orientation,
                                                    filmStock: camera.filmStocks.isEmpty ? nil : filmStock)
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
            ZStack {
                Text("Load Film").font(.orbit(size: 17, weight: .extraBold, relativeTo: .headline)).opacity(loading ? 0 : 1)
                if loading { ProgressView().tint(.black) }
            }
        }
        .buttonStyle(OrbitRoundMainActionStyle(diameter: 104))
        .disabled(loading)
        .accessibilityIdentifier("load-film")
        .padding(.bottom, 12)
    }

    private var suggestedTitle: String {
        camera.suggestedTitle(roll: model.films.filter { $0.camera.id == camera.id }.count + 1)
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

/// A choice made once at Load Film, as round options under its heading (B03, B04). VoiceOver reads the heading and each
/// option, the chosen one selected.
private struct RoundChoice<Value: Hashable>: View {
    let title: String
    let options: [(value: Value, title: String, symbol: String)]
    @Binding var selection: Value
    var diameter: CGFloat = 96

    var body: some View {
        VStack(spacing: 12) {
            Text(title).orbitFont(.label).foregroundStyle(Orbit.label).accessibilityLabel(title)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 20) {
                ForEach(options, id: \.value) { option in
                    Button { selection = option.value } label: {
                        Label { Text(option.title) } icon: { Image(systemName: option.symbol).font(.system(size: 24, weight: .light)) }
                    }
                    .buttonStyle(OrbitRoundOptionStyle(selected: selection == option.value, diameter: diameter))
                    .accessibilityAddTraits(selection == option.value ? .isSelected : [])
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(title)
        }
        .padding(.top, 6)
    }
}

/// Chips across the width, centered, wrapping to more lines as needed.
private struct ChipFlow: Layout {
    var spacing: CGFloat = 8

    private func lines(width: CGFloat, subviews: Subviews) -> [[(LayoutSubview, CGSize)]] {
        var lines: [[(LayoutSubview, CGSize)]] = [[]]
        var x: CGFloat = 0
        for subview in subviews {
            var size = subview.sizeThatFits(.unspecified)
            if size.width > width { size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil)) }
            if x > 0, x + size.width > width { lines.append([]); x = 0 }
            lines[lines.count - 1].append((subview, size))
            x += size.width + spacing
        }
        return lines
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? 358
        let lines = lines(width: width, subviews: subviews)
        let height = lines.map { $0.map(\.1.height).max() ?? 0 }.reduce(0, +) + spacing * CGFloat(max(lines.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for line in lines(width: bounds.width, subviews: subviews) {
            let length = line.map(\.1.width).reduce(0, +) + spacing * CGFloat(max(line.count - 1, 0))
            let height = line.map(\.1.height).max() ?? 0
            var x = bounds.midX - length / 2
            for (subview, size) in line {
                subview.place(at: CGPoint(x: x, y: y + height / 2), anchor: .leading, proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += height + spacing
        }
    }
}

/// What loading this Film uses and what stays fixed, matching `TrialCoordinator.load` and the
/// Load Film errors. Builds without subscription products never suggest subscribing.
enum LoadCopy {
    static func note(access: SubscriptionAccess, trial: DeviceTrialState?, camera: CameraPackage,
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
        return [entitlement, fixed(camera: camera)].compactMap { $0 }.joined(separator: " ")
    }

    /// What Load Film fixes for this Film: the Camera, and the Film Stock and Movie Orientation where it has them.
    static func fixed(camera: CameraPackage) -> String {
        switch (camera.filmStocks.isEmpty, camera.medium) {
        case (true, .photo): "Your Camera cannot change after loading."
        case (true, .movie): "Your Camera and Movie Orientation cannot change after loading."
        case (false, .photo): "Your Camera and Film Stock cannot change after loading."
        case (false, .movie): "Your Camera, Film Stock and Movie Orientation cannot change after loading."
        }
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
        view.tintColor = .white
        return view
    }

    func updateUIView(_ view: InsetTextView, context: Context) {
        context.coordinator.text = $text
        // While the field is being edited its own text is the newest title. SwiftUI can pass the title from before the
        // latest edit, and writing that back restored a deleted character behind the cursor
        // (Evidence/NativeApp/title-autocorrection-058.md).
        if !view.isFirstResponder, view.text != text { view.text = text; view.textDidChange() }
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
            font = OrbitFonts.uiFont(.semibold, size: 17, relativeTo: .body)
            adjustsFontForContentSizeCategory = true
            textColor = .white
            placeholderLabel.font = font
            placeholderLabel.adjustsFontForContentSizeCategory = true
            placeholderLabel.textColor = UIColor(white: 0x8A / 255, alpha: 1)
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
