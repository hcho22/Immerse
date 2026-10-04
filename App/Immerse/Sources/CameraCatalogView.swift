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
                                        Text(camera.shortName).font(.system(.title3, design: .serif))
                                        Text(camera.capacityLabel).font(.caption).foregroundStyle(.secondary)
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
        Form {
            if let catalog = model.mediaCatalog, !catalog.assets(for: camera.id, purpose: .cameraSample).isEmpty {
                Section {
                    Button("Camera samples", systemImage: "photo.on.rectangle") { samples = true }
                }
            }
            Section {
                LabeledContent("Capacity", value: camera.capacityLabel)
                Text(camera.revealLabel)
                Text(camera.controlsLabel).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
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
                    TextField("Title", text: $title, axis: .vertical)
                        .accessibilityLabel("Film title").accessibilityIdentifier("film-title")
                }
            }
            #if DEBUG
            if model.testingUnlock.enabled {
                Section {
                    TestingUnlockNotice()
                    Text(LoadCopy.fixed(medium: camera.medium))
                        .font(.footnote).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Section { entitlement }
            }
            #else
            Section { entitlement }
            #endif
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
        .navigationTitle(camera.shortName)
        .sheet(isPresented: $samples) { CameraSamplesView(camera: camera) }
        .task { if title.isEmpty { title = suggestedTitle } }
        .interactiveDismissDisabled(loading)
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
