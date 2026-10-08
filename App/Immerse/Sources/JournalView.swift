import FilmDomain
import SwiftUI

private enum JournalRoute: Hashable {
    case archive
    case film(UUID)
}

struct JournalView: View {
    @Environment(JournalModel.self) private var model
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var setup = false
    @State private var settings = false
    @State private var path: [JournalRoute] = []

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $path) {
            FilmList(archived: false)
                .safeAreaBar(edge: .bottom, spacing: 10) { startFilm }
                .ignoresSafeArea(.container, edges: .bottom)
                .navigationTitle("Film Journal")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Settings", systemImage: "gearshape") { settings = true }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink(value: JournalRoute.archive) {
                            Label("Archive", systemImage: "archivebox")
                        }
                    }
                }
                .navigationDestination(for: JournalRoute.self) { route in
                    switch route {
                    case .archive: FilmList(archived: true).navigationTitle("Archive")
                    case .film(let id): FilmDetailView(filmID: id)
                    }
                }
        }
        .sheet(isPresented: $setup) {
            CameraCatalogView { film in setup = false; path.append(.film(film.id)) }
        }
        .sheet(isPresented: $settings) { SettingsView() }
        .alert(item: $model.alert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
    }

    /// Start a Film where the iOS 26 bottom toolbar drew it, 28 points above the screen's bottom edge whatever the
    /// bottom safe-area inset, with the same circle, symbol, Film inset and scroll edge fade; the 10 points above the
    /// circle are the bar's spacing, since padding would start the fade 10 points higher. A `.bottomBar` toolbar
    /// item made UIKit add its toolbar to the hosting controller's view at every launch, which SwiftUI reports as
    /// unsupported (Evidence/NativeApp/ci-flakes-057.md). Like a bar item, the circle keeps one size, the symbol
    /// follows the text size only up to Extra Extra Large, and larger sizes get the large content viewer.
    private var startFilm: some View {
        let diameter: CGFloat = verticalSizeClass == .compact ? 44 : 48
        return Button { setup = true } label: {
            Label("Start a Film", systemImage: "plus")
                .labelStyle(.iconOnly)
                .font(.body.weight(.medium))
                .imageScale(.large)
                .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                .foregroundStyle(Color.primaryActionSymbol)
                .frame(width: diameter, height: diameter)
                .contentShape(.circle)
        }
        .glassEffect(.regular.tint(.primaryAction).interactive(), in: .circle)
        .accessibilityShowsLargeContentViewer()
        .accessibilityIdentifier("start-film")
        .disabled(model.initialRecoveryPending)
        .padding(.bottom, 28)
    }
}

private struct FilmList: View {
    @Environment(JournalModel.self) private var model
    let archived: Bool
    private var films: [Film] { model.films.filter { $0.isArchived == archived } }
    private let states = ["On the roll", "Ready to develop", "Developing", "Pack complete", "Developed"]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                if films.isEmpty {
                    ContentUnavailableView(archived ? "No archived Films" : "Your Journal begins here",
                                           systemImage: archived ? "archivebox" : "camera")
                        .padding(.vertical, 60)
                }
                ForEach(states, id: \.self) { state in
                    let matching = films.filter { $0.journalState == state }
                    if !matching.isEmpty {
                        Text(state).font(.headline).padding(.horizontal)
                        ForEach(matching) { film in
                            NavigationLink(value: JournalRoute.film(film.id)) { JournalFilmRow(filmID: film.id) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }.padding(.vertical)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .refreshable { model.refresh() }
    }
}

private struct JournalFilmRow: View {
    @Environment(JournalModel.self) private var model
    let filmID: UUID

    var body: some View {
        if let film = model.film(filmID) { row(film) }
    }

    private func row(_ film: Film) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                film.camera.shortNameText.font(.caption.monospaced()).foregroundStyle(Color.cardSecondaryText)
                Spacer()
                Text(film.loadedAt, format: .dateTime.month(.abbreviated).day()).font(.caption)
            }
            film.titleText.font(.system(.title2, design: .serif)).lineLimit(3)
            if film.camera.medium == .photo && !model.hiddenFilms.contains(film.id) {
                let shown = Array(film.captures.filter { $0.revealState == .revealed }.prefix(3))
                if !shown.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(shown) { capture in
                            RevealedPhoto(filmID: film.id, sequence: capture.sequenceNumber)
                                .aspectRatio(film.camera.printAspectRatio, contentMode: .fit).clipped()
                        }
                    }
                }
            }
            if model.hasPendingSave(film.id) { ProgressView().accessibilityLabel("Finishing save") }
            else {
                ProgressView(value: film.progress).tint(.secondary)
                    .accessibilityLabel("Film used").accessibilityValue("\(Int(film.progress * 100)) percent")
            }
            HStack {
                Label {
                    model.hasPendingSave(film.id) ? Text("Finishing save") : film.remainingText
                } icon: {
                    Image(systemName: model.hasPendingSave(film.id) ? "clock" : film.camera.medium == .photo ? "rectangle.stack" : "film")
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
            }.font(.caption).foregroundStyle(Color.cardSecondaryText)
        }
        .padding(18)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }
}
