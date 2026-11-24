import ImmerseServer
import SwiftUI

struct GroupFieldLook: ViewModifier {
    func body(content: Content) -> some View {
        content.orbitFont(.headline).foregroundStyle(.white).tint(.white)
            .padding(.horizontal, 20).frame(minHeight: 56)
            .background(Orbit.button, in: Capsule())
    }
}

/// The Join Confirmation a Join Code's link opens (V2-FR-21): the Film Title, the Host's display name, the Camera and its
/// exposures per Roll, the Film Stock, when shooting ends, when the album reveals and the sharing rule, then only a name
/// and one tap. Nobody is asked to sign in, and opening the link joins nobody. Where the person cannot join now, it says
/// why (V2-FR-18).
struct JoinConfirmationView: View {
    @Environment(\.groupFilms) private var groupFilms
    @Environment(\.dismiss) private var dismiss
    let code: String
    /// Whether the confirmation is the whole screen, as in the mini-app, with nothing behind it to go back to.
    var standsAlone = false
    @State private var preview: JoinPreview?
    @State private var failure: String?
    @State private var name = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let preview {
                        content(preview)
                    } else if let failure {
                        OrbitNote(.error, failure, identifier: "join-problem")
                        Button("Try Again") { Task { await load() } }.primaryAction()
                    } else {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, Orbit.gutter).padding(.vertical, 16)
            }
            .orbitSheetGround(screen: true)
            .navigationTitle("Group Film").toolbarTitleDisplayMode(.inline)
            .toolbar {
                if !standsAlone {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Cancel", systemImage: "xmark") { dismiss() }.buttonStyle(OrbitCircleButtonStyle())
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        guard let groupFilms else { return }
        failure = nil
        do { preview = try await groupFilms.preview(code: code) }
        catch { failure = GroupFilmsCopy.words(for: error) }
    }

    @ViewBuilder private func content(_ preview: JoinPreview) -> some View {
        if let event = preview.event {
            Text(event.title).orbitFont(.title).accessibilityAddTraits(.isHeader).accessibilityIdentifier("join-title")
            Text(event.hostLeft ? "The Host has left Immerse" : "Hosted by \(event.hostName ?? "the Host")")
                .orbitFont(.body).foregroundStyle(Orbit.body)
            VStack(alignment: .leading, spacing: 8) {
                detail("camera", "\(GroupFilmsCopy.camera(event.camera)), \(event.exposuresPerRoll) exposures")
                if let stock = GroupFilmsCopy.filmStock(event.filmStock) { detail("film", stock) }
                if event.phase == .scheduled { detail("clock", "Opens \(GroupFilmsCopy.time(event.opensAt))") }
                detail("stop.circle", "Shooting ends \(GroupFilmsCopy.time(event.endsAt))")
                detail("sparkles", "The album reveals \(GroupFilmsCopy.time(event.revealsAt))")
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Orbit.surface, in: RoundedRectangle(cornerRadius: 24))
            Text(GroupFilmsCopy.sharingRule(instant: event.camera == .instant)).orbitFont(.body).foregroundStyle(Orbit.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        if let status = GroupFilmsCopy.joinStatus(preview) {
            OrbitNote(.info, status, identifier: "join-status")
            if preview.status == .ended, preview.place == .left, let event = preview.event {
                openButton(event.eventId)
            }
        } else if preview.status == .member, let event = preview.event {
            Text("You are in this event.").orbitFont(.body, weight: .semibold)
            if let notice = groupFilms?.notice { OrbitNote(.error, notice, identifier: "join-notice") }
            openButton(event.eventId)
        } else {
            if preview.place == .left {
                Text("Welcome back. You return to your own Roll.").orbitFont(.body).foregroundStyle(Orbit.body)
            } else {
                OrbitSectionLabel("Your name with your pictures").padding(.leading, 4)
                TextField("Name", text: $name)
                    .textContentType(.givenName)
                    .modifier(GroupFieldLook()).accessibilityIdentifier("join-name")
                Text("Shown only in each picture's details and the Host's guest list, never on a picture.")
                    .orbitFont(.footnote).foregroundStyle(Orbit.label)
            }
            if let notice = groupFilms?.notice { OrbitNote(.error, notice, identifier: "join-notice") }
            Button(preview.place == .left ? "Rejoin" : "Take a Roll") {
                Task { if await groupFilms?.join(code: code, guestName: name) == true { dismiss() } }
            }
            .primaryAction()
            .disabled(groupFilms?.busy == true || (preview.place != .left && name.trimmingCharacters(in: .whitespaces).isEmpty))
            .accessibilityIdentifier("join-take-roll")
        }
    }

    private func openButton(_ eventID: String) -> some View {
        Button("Open the event") {
            // A member whose place is not on this iPhone, after a reinstall or once iOS has cleared the mini-app's data,
            // gets it back from the server first.
            Task { if await groupFilms?.openAsMember(code: code, eventID: eventID) == true { dismiss() } }
        }
        .primaryAction()
        .disabled(groupFilms?.busy == true)
        .accessibilityIdentifier("join-open-event")
    }

    private func detail(_ symbol: String, _ text: String) -> some View {
        Label { Text(text).orbitFont(.body) } icon: { Image(systemName: symbol).foregroundStyle(Orbit.label) }
    }
}
