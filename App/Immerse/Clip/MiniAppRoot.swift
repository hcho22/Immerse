import ImmerseServer
import SwiftUI

/// What the mini-app shows (v2 PRD V2-FR-19, V2-FR-21, V2-FR-71): the Join Confirmation of the link that opened it,
/// then the event's page with its shooting screen, upload counts and, after the reveal, the album; the events this
/// iPhone already holds when no link came with the launch; and the way on to the full app once it is installed.
struct MiniAppRoot: View {
    let miniApp: MiniApp

    var body: some View {
        if miniApp.handedOver {
            MiniAppHandedOver(link: miniApp.lastLink)
        } else if let groupFilms = miniApp.groupFilms {
            MiniAppEvents(groupFilms: groupFilms)
        } else {
            MiniAppMessage(symbol: "qrcode.viewfinder", title: "Immerse",
                           message: "This mini-app could not start on this iPhone. Install Immerse to join.",
                           identifier: "mini-app-unavailable")
        }
    }
}

private struct MiniAppEvents: View {
    @Bindable var groupFilms: GroupFilms
    @State private var path: [String] = []

    var body: some View {
        Group {
            if let request = groupFilms.joinRequest {
                // The whole screen, not a sheet: there is nothing behind it, and the shooting screen follows it at once.
                JoinConfirmationView(code: request.code, standsAlone: true).id(request.code)
            } else {
                NavigationStack(path: $path) {
                    home
                        .navigationDestination(for: String.self) { GroupFilmEventView(eventID: $0) }
                }
            }
        }
        .onChange(of: groupFilms.openEvent, initial: true) { _, eventID in
            guard let eventID else { return }
            groupFilms.openEvent = nil
            path = [eventID]
        }
        .onAppear {
            // Opened with no link, from the App Library or the App Switcher: back to the event this iPhone holds.
            if groupFilms.joinRequest == nil, path.isEmpty, groupFilms.visiblePlaces.count == 1,
               let only = groupFilms.visiblePlaces.first {
                path = [only.eventID]
            }
        }
        .alert(item: $groupFilms.ending) { ending in
            Alert(title: Text(ending.title), message: Text(ending.message), dismissButton: .default(Text("OK")))
        }
    }

    @ViewBuilder private var home: some View {
        let places = groupFilms.visiblePlaces
        if places.isEmpty {
            MiniAppMessage(symbol: "qrcode.viewfinder", title: "Join a Group Film",
                           message: "Scan an event's QR code with the iPhone's Camera, or open its link, to join.",
                           identifier: "mini-app-empty")
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    OrbitSectionLabel("Group Films").padding(.leading, 4)
                    ForEach(places) { place in
                        NavigationLink(value: place.eventID) {
                            HStack {
                                Text(place.summary.title).orbitFont(.headline).foregroundStyle(.white)
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(Orbit.label)
                            }
                            .orbitRow()
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("mini-app-group-film")
                    }
                }
                .padding(.horizontal, Orbit.gutter).padding(.vertical, 16)
            }
            .orbitGround()
            .navigationTitle("Immerse").toolbarTitleDisplayMode(.inline)
        }
    }
}

/// The full app is installed and has this iPhone's Group Films: the guest goes on there, where the same link opens the
/// same event, Roll and pictures.
private struct MiniAppHandedOver: View {
    @Environment(\.openURL) private var openURL
    let link: URL?

    var body: some View {
        VStack(spacing: 20) {
            MiniAppMessage(symbol: "arrow.up.forward.app", title: "Continue in Immerse",
                           message: "Immerse is installed on this iPhone. Your place, your Roll and your pictures are there, with any still waiting to send.",
                           identifier: "mini-app-handed-over")
            if let link {
                Button("Open Immerse") { openURL(link) }
                    .primaryAction()
                    .frame(maxWidth: 260)
                    .accessibilityIdentifier("mini-app-open-immerse")
            }
        }
        .padding(.bottom, 40)
        .orbitGround()
    }
}

private struct MiniAppMessage: View {
    let symbol: String
    let title: String
    let message: String
    let identifier: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol).font(.system(size: 44, weight: .light)).foregroundStyle(.white).accessibilityHidden(true)
            Text(title).orbitFont(.title).multilineTextAlignment(.center).accessibilityAddTraits(.isHeader)
            Text(message).orbitFont(.body).foregroundStyle(Orbit.body).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(identifier)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .orbitGround()
    }
}
