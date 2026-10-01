import FilmDomain
import SwiftUI

private enum JournalRoute: Hashable {
    case archive
    case film(UUID)
}

struct JournalView: View {
    @Environment(JournalModel.self) private var model
    @State private var setup = false
    @State private var settings = false
    @State private var path: [JournalRoute] = []

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $path) {
            FilmList(archived: false)
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
                    ToolbarItem(placement: .bottomBar) {
                        Button("Start a Film", systemImage: "plus") { setup = true }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("start-film")
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
                Text(film.camera.shortName).font(.caption.monospaced()).foregroundStyle(.secondary)
                Spacer()
                Text(film.loadedAt, format: .dateTime.month(.abbreviated).day()).font(.caption)
            }
            Text(film.title).font(.system(.title2, design: .serif)).lineLimit(3)
            if film.camera.medium == .photo && !model.hiddenFilms.contains(film.id) {
                let shown = Array(film.captures.filter { $0.revealState == .revealed }.prefix(3))
                if !shown.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(shown) { capture in
                            RevealedPhoto(filmID: film.id, sequence: capture.sequenceNumber)
                                .aspectRatio(1, contentMode: .fit).clipped()
                        }
                    }
                }
            }
            ProgressView(value: film.progress).tint(.secondary)
                .accessibilityLabel("Film used").accessibilityValue("\(Int(film.progress * 100)) percent")
            HStack {
                Label(film.remainingLabel, systemImage: film.camera.medium == .photo ? "rectangle.stack" : "film")
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
            }.font(.caption).foregroundStyle(.secondary)
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }
}
