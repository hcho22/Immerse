import AVFoundation
import FilmDomain
import FilmPersistence
import MediaCatalog
import SwiftUI

struct SoundtrackView: View {
    @Environment(JournalModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let filmID: UUID
    @State private var current: MovieAudioSelection?
    @State private var selected = MovieSoundChoice.silent.rawValue
    @State private var loaded = false
    @State private var working = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Current sound") {
                    Text(currentTitle)
                    if let credit = current?.asset?.rights.attribution, !credit.isEmpty { Text(credit).font(.caption) }
                }
                if let film = model.film(filmID) {
                    Section("Movie sound") {
                        Picker("Sound", selection: $selected) {
                            if film.camera.recordsLiveSound == true {
                                Text("Recorded sound").tag(MovieSoundChoice.recordedSound.rawValue)
                            }
                            if let catalog = model.mediaCatalog {
                                ForEach(catalog.assets(for: film.camera.id, purpose: .instrumental)) { asset in
                                    Text(asset.title).tag("soundtrack:\(asset.id)")
                                }
                            }
                            Text("Silent").tag(MovieSoundChoice.silent.rawValue)
                        }
                        // The section names it; shown, an inline picker's label is a row that reads as one more choice.
                        .pickerStyle(.inline).labelsHidden()
                    }
                    Button("Apply sound choice", systemImage: "checkmark") {
                        working = true
                        Task {
                            defer { working = false }
                            do {
                                guard let choice = selectedChoice else { throw PersistenceError.invalidMedia }
                                try await model.selectMovieSound(filmID, choice: choice, assetID: selectedAssetID)
                                dismiss()
                            }
                            catch { self.error = FailureCopy.message(for: error) }
                        }
                    }.disabled(!loaded || working || selectionIsUnchanged)
                }
                if working { ProgressView("Preparing Movie") }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle("Movie sound")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }.labelStyle(.iconOnly).disabled(working)
                }
            }
            .task {
                do {
                    current = try model.repository.movieAudioSelection(filmID: filmID)
                    if let film = model.film(filmID) {
                        let choice = current?.effectiveChoice(recordsLiveSound: film.camera.recordsLiveSound == true)
                            ?? (film.camera.recordsLiveSound == true ? .recordedSound : .silent)
                        selected = choice == .soundtrack
                            ? "soundtrack:\(current?.asset?.id ?? "")" : choice.rawValue
                    }
                    loaded = true
                } catch { self.error = FailureCopy.message(for: error) }
            }
            .interactiveDismissDisabled(working)
        }
    }

    private var selectedChoice: MovieSoundChoice? {
        if selected == MovieSoundChoice.recordedSound.rawValue { return .recordedSound }
        if selected == MovieSoundChoice.silent.rawValue { return .silent }
        return selected.hasPrefix("soundtrack:") ? .soundtrack : nil
    }

    private var selectedAssetID: String? {
        guard selectedChoice == .soundtrack else { return nil }
        return String(selected.dropFirst("soundtrack:".count))
    }

    private var currentTitle: String {
        guard let film = model.film(filmID) else { return "Silent" }
        let choice = current?.effectiveChoice(recordsLiveSound: film.camera.recordsLiveSound == true)
            ?? (film.camera.recordsLiveSound == true ? .recordedSound : .silent)
        switch choice {
        case .recordedSound: return "Recorded sound"
        case .soundtrack: return current?.asset?.title ?? "Soundtrack"
        case .silent: return "Silent"
        }
    }

    private var selectionIsUnchanged: Bool {
        guard let film = model.film(filmID), let selectedChoice else { return false }
        let currentChoice = current?.effectiveChoice(recordsLiveSound: film.camera.recordsLiveSound == true)
            ?? (film.camera.recordsLiveSound == true ? .recordedSound : .silent)
        return selectedChoice == currentChoice && selectedAssetID == current?.asset?.id
    }
}

/// The sound of a developed Movie or a sample movie plays as a video in Photos does: through the speaker, whatever the
/// Ring/Silent switch, and not through the earpiece a movie Camera's microphone left the app routed to. The category is
/// set as a player is made; the player makes it active as it starts, so other audio stops only once a movie plays.
/// Each view that made a player calls `finish` once as the player goes.
@MainActor
enum MoviePlaybackAudio {
    /// The players made and not yet gone.
    private static var players = 0

    static func prepare() {
        players += 1
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
    }

    /// Lets other audio resume once the last player is gone, never while another still plays.
    static func finish() {
        players -= 1
        guard players == 0 else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
