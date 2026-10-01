import FilmPersistence
import MediaCatalog
import SwiftUI

struct SoundtrackView: View {
    @Environment(JournalModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let filmID: UUID
    @State private var current: MovieAudioSelection?
    @State private var selected: String?
    @State private var loaded = false
    @State private var working = false
    @State private var error: String?

    private var locked: Bool {
        current != nil && model.mediaCatalog?.manifest.soundtrackReselection != .allowed
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Current soundtrack") {
                    Text(current?.asset?.title ?? "Silent")
                    if let credit = current?.asset?.rights.attribution, !credit.isEmpty { Text(credit).font(.caption) }
                }
                if !locked, let film = model.film(filmID), let catalog = model.mediaCatalog {
                    Section {
                        choice("Silent", id: nil)
                        ForEach(catalog.assets(for: film.camera.id, purpose: .instrumental)) { asset in
                            choice(asset.title, id: asset.id)
                            if !asset.rights.attribution.isEmpty { Text(asset.rights.attribution).font(.caption) }
                        }
                    }
                    Button("Apply soundtrack", systemImage: "checkmark") {
                        working = true
                        Task {
                            defer { working = false }
                            do { try await model.selectSoundtrack(filmID, assetID: selected); dismiss() }
                            catch { self.error = error.localizedDescription }
                        }
                    }.disabled(!loaded || working || (current != nil && selected == current?.asset?.id))
                }
                if working { ProgressView("Preparing Movie") }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle("Soundtrack")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }.labelStyle(.iconOnly).disabled(working)
                }
            }
            .task {
                do {
                    current = try model.repository.movieAudioSelection(filmID: filmID)
                    selected = current?.asset?.id
                    loaded = true
                } catch { self.error = error.localizedDescription }
            }
            .interactiveDismissDisabled(working)
        }
    }

    private func choice(_ title: String, id: String?) -> some View {
        Button { selected = id } label: {
            HStack { Text(title); Spacer(); Image(systemName: selected == id ? "checkmark.circle.fill" : "circle") }
        }.accessibilityAddTraits(selected == id ? .isSelected : []).disabled(working)
    }
}
