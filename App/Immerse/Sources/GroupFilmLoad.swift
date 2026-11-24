import FilmDomain
import ImmerseServer
import SwiftUI

/// The Host's Load Film for a Group Film (v2 PRD V2-FR-10 to V2-FR-14): its title, one of the three photo Cameras with
/// its Camera Preview, the 6×6's Film Stock for everyone, its Rolls from the balance, an optional later Start Time, its
/// End Time and Reveal Delay, and the sharing rule. Load Film needs a connection; offline it says so and keeps every
/// choice.
struct GroupFilmLoadView: View {
    @Environment(\.groupFilms) private var groupFilms
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var camera: EventCamera = .disposable
    @State private var filmStock: EventFilmStock = .color
    @State private var rolls = 3
    @State private var startsLater = false
    @State private var startsAt = Date.now.addingTimeInterval(7 * 24 * 3600)
    @State private var endsAt = Date.now.addingTimeInterval(6 * 3600)
    @State private var revealDelayHours = 0
    @State private var confirming = false
    @State private var sampling: CameraPackage?

    private var opens: Date { startsLater ? startsAt : .now }
    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var balance: Int { groupFilms?.balance ?? 0 }
    private var problem: String? {
        if trimmedTitle.isEmpty { return "Give the Film a title." }
        if startsLater && startsAt <= .now { return "The Start Time is in the past." }
        if endsAt <= opens { return "The End Time comes after the event opens." }
        if endsAt.timeIntervalSince(opens) > 7 * 24 * 3600 { return "Shooting lasts at most 7 days from the event's opening." }
        if rolls > balance { return "Your balance holds \(balance) Rolls." }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Load a Group Film").orbitFont(.title).accessibilityAddTraits(.isHeader)
                field("Film Title") {
                    TextField("Ana & Leo", text: $title)
                        .modifier(GroupFieldLook()).accessibilityIdentifier("group-title")
                }
                field("Camera") {
                    VStack(spacing: 10) {
                        ForEach(EventCamera.allCases, id: \.self) { option in cameraRow(option) }
                    }
                }
                if camera == .sixBySix {
                    field("Film Stock for everyone") {
                        Picker("Film Stock", selection: $filmStock) {
                            Text("Color").tag(EventFilmStock.color)
                            Text("Black and white").tag(EventFilmStock.blackAndWhite)
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("group-film-stock")
                    }
                }
                field("Rolls") {
                    Stepper(value: $rolls, in: 1...max(1, min(200, max(balance, 1)))) {
                        Text("\(rolls) \(rolls == 1 ? "Roll" : "Rolls"), one for each guest").orbitFont(.body, weight: .semibold)
                    }
                    .accessibilityIdentifier("group-rolls")
                    Text("Your balance: \(balance) \(balance == 1 ? "Roll" : "Rolls"). Rolls nobody takes come back at the End Time.")
                        .orbitFont(.footnote).foregroundStyle(Orbit.label)
                }
                field("When") {
                    Toggle(isOn: $startsLater) { Text("Open later, at a Start Time").orbitFont(.body, weight: .semibold) }
                        .accessibilityIdentifier("group-starts-later")
                    if startsLater {
                        DatePicker("Start Time", selection: $startsAt, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                            .accessibilityIdentifier("group-start-time")
                        Text("The link and QR code work at once, so you can print them ahead; nobody can join before the Start Time.")
                            .orbitFont(.footnote).foregroundStyle(Orbit.label)
                    }
                    DatePicker("End Time", selection: $endsAt, in: opens...opens.addingTimeInterval(7 * 24 * 3600),
                               displayedComponents: [.date, .hourAndMinute])
                        .accessibilityIdentifier("group-end-time")
                    Stepper(value: $revealDelayHours, in: 0...24) {
                        Text("Reveal: \(GroupFilmsCopy.revealDelay(TimeInterval(revealDelayHours) * 3600))").orbitFont(.body)
                    }
                    .accessibilityIdentifier("group-reveal-delay")
                }
                Text(GroupFilmsCopy.sharingRule(instant: camera == .instant)).orbitFont(.body).foregroundStyle(Orbit.body)
                    .fixedSize(horizontal: false, vertical: true)
                if let problem, !trimmedTitle.isEmpty { OrbitNote(.info, problem, identifier: "group-load-problem") }
                if let notice = groupFilms?.notice { OrbitNote(.error, notice, identifier: "group-notice") }
                Button("Load Film") { confirming = true }
                    .primaryAction()
                    .disabled(problem != nil || groupFilms?.busy == true)
                    .accessibilityIdentifier("group-load")
                if groupFilms?.busy == true { ProgressView().frame(maxWidth: .infinity) }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, Orbit.gutter).padding(.vertical, 16)
        }
        .scrollBounceBehavior(.basedOnSize)
        .task { await groupFilms?.refreshBalance() }
        .onChange(of: startsLater) { _, later in
            // The End Time follows the opening, within its 7 days.
            if later, endsAt <= startsAt { endsAt = startsAt.addingTimeInterval(6 * 3600) }
        }
        .sheet(item: $sampling) { CameraSamplesView(camera: $0) }
        .orbitConfirmation(isPresented: $confirming, symbol: "film", title: "Load \(trimmedTitle)?", message: summary,
                           confirm: "Load Film", identifier: "confirm-group-load") {
            Task { await load() }
        }
    }

    /// Load Film's confirmation (V2-FR-13): every setting, the sharing rule, and that the Camera is fixed for good.
    private var summary: String {
        var lines = ["\(GroupFilmsCopy.camera(camera)), \(camera.exposuresPerRoll) exposures a Roll"]
        if camera == .sixBySix, let stock = GroupFilmsCopy.filmStock(filmStock) { lines.append(stock) }
        lines.append("\(rolls) \(rolls == 1 ? "Roll" : "Rolls")")
        if startsLater { lines.append("Opens \(GroupFilmsCopy.time(startsAt))") }
        lines.append("Shooting ends \(GroupFilmsCopy.time(endsAt))")
        lines.append("Reveals \(GroupFilmsCopy.time(endsAt.addingTimeInterval(TimeInterval(revealDelayHours) * 3600)))")
        lines.append(GroupFilmsCopy.sharingRule(instant: camera == .instant))
        lines.append("The Camera\(camera == .sixBySix ? " and Film Stock" : "") cannot change after Load Film.")
        return lines.joined(separator: "\n")
    }

    private func load() async {
        guard let groupFilms else { return }
        let setup = EventSetup(title: trimmedTitle, camera: camera, filmStock: camera == .sixBySix ? filmStock : nil, rolls: rolls,
                               startsAt: startsLater ? startsAt : nil, endsAt: endsAt,
                               revealDelay: TimeInterval(revealDelayHours) * 3600,
                               treatmentVersion: GroupFilms.package(for: camera).treatmentVersion ?? CameraCatalog.treatmentVersion)
        if await groupFilms.loadFilm(setup) { dismiss() }
    }

    private func cameraRow(_ option: EventCamera) -> some View {
        let package = GroupFilms.package(for: option)
        return HStack(spacing: 12) {
            Button {
                camera = option
            } label: {
                HStack {
                    Image(systemName: camera == option ? "largecircle.fill.circle" : "circle").accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(GroupFilmsCopy.camera(option)).orbitFont(.headline)
                        Text("\(option.exposuresPerRoll) exposures a Roll").orbitFont(.footnote).foregroundStyle(Orbit.label)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(camera == option ? .isSelected : [])
            .accessibilityIdentifier("group-camera-\(option.rawValue)")
            Button("Preview") { sampling = package }
                .buttonStyle(OrbitPillStyle(kind: .outline, minHeight: 44))
                .accessibilityLabel("Camera Preview of the \(GroupFilmsCopy.camera(option))")
        }
        .padding(12)
        .background(Orbit.button, in: RoundedRectangle(cornerRadius: 20))
    }

    private func field(_ label: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            OrbitSectionLabel(label).padding(.leading, 4)
            content()
        }
    }
}
