import AVKit
import FilmDomain
import FilmPersistence
import SwiftUI

struct FilmDetailView: View {
    @Environment(JournalModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let filmID: UUID
    @State private var capturing = false
    @State private var renaming = false
    @State private var title = ""
    @State private var deleting = false
    @State private var early = false
    @State private var earlySnapshot: Film?
    @State private var developing = false
    @State private var originals = false
    @State private var soundtrack = false
    @State private var selectedPhoto: CaptureRecord?
    @State private var discard: CaptureRecord?

    var body: some View {
        Group {
            if let film = model.film(filmID) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header(film)
                        if model.hiddenFilms.contains(filmID) {
                            ProgressView("Removing private media")
                        } else {
                            actions(film)
                            media(film)
                        }
                    }.padding()
                }
                .navigationTitle(SpokenText.title(film.title)).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { filmMenu(film) } }
            } else { ContentUnavailableView("Film removed", systemImage: "film") }
        }
        .task { await model.storage.refresh() }
        .fullScreenCover(isPresented: $capturing, onDismiss: { model.capture.endShootingSession() }) {
            CaptureView(filmID: filmID)
        }
        .sheet(isPresented: $developing) { OriginalChoiceView(filmID: filmID, startsDevelopment: true) }
        .sheet(isPresented: $originals) { OriginalChoiceView(filmID: filmID, startsDevelopment: false) }
        .sheet(isPresented: $soundtrack) { SoundtrackView(filmID: filmID) }
        .fullScreenCover(item: $selectedPhoto) { capture in PhotoView(filmID: filmID, sequence: capture.sequenceNumber) }
        .alert("Rename Film", isPresented: $renaming) {
            TextField("Film title", text: $title)
            Button("Cancel", role: .cancel) {}
            Button("Save") { model.perform { try model.repository.rename(filmID: filmID, title: title) } }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .confirmationDialog("Delete Film?", isPresented: $deleting, titleVisibility: .visible) {
            Button("Delete Film", role: .destructive) {
                model.perform { try await model.remove(filmID); dismiss() }
            }.accessibilityIdentifier("confirm-delete-film")
        } message: { Text(PrivacyCopy.deleteFilm) }
        .confirmationDialog("Complete Film early?", isPresented: $early, titleVisibility: .visible) {
            Button("Complete Film", role: .destructive) {
                model.perform {
                    try await model.recoverCapture(filmID)
                    guard let snapshot = earlySnapshot else { throw PersistenceError.capacityChangedSinceConfirmation }
                    _ = try model.repository.completeEarly(filmID: filmID, confirmedCaptureCount: snapshot.savedCaptureCount)
                    developing = true
                }
            }
        } message: {
            Text("\(earlySnapshot?.exactWasteLabel ?? "Unused capacity") will be permanently wasted. The Film cannot reopen. Development is a separate confirmation.")
        }
        .confirmationDialog("Discard capture?", isPresented: Binding(get: { discard != nil }, set: { if !$0 { discard = nil } }), titleVisibility: .visible) {
            if let discard {
                Button("Discard #\(discard.sequenceNumber)", role: .destructive) {
                    model.perform { try await model.remove(filmID, sequence: discard.sequenceNumber) }
                }
            }
        } message: { Text(PrivacyCopy.discard) }
    }

    private func header(_ film: Film) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            film.camera.shortNameText.font(.system(.title2, design: .serif))
            if let stock = film.filmStock { Text("\(stock.label) Film Stock").font(.subheadline) }
            Text(film.journalState).font(.headline)
            // The system secondary label is 3.44:1 on this screen's white ground in light mode, under the 4.5:1 bar.
            (model.hasPendingSave(filmID) ? Text("Finishing save") : film.remainingText)
                .font(.subheadline.monospaced()).foregroundStyle(Color.cardSecondaryText)
            if model.hasPendingSave(filmID) { ProgressView().accessibilityLabel("Finishing save") }
            // The bar draws what the line above says in words, so VoiceOver reads the line alone; as its own
            // element the 4-point bar was reported as a control too small to tap.
            else { ProgressView(value: film.progress).accessibilityHidden(true) }
            if let range = film.captureDateRange {
                Text("\(range.lowerBound.formatted(date: .abbreviated, time: .omitted)) - \(range.upperBound.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption).foregroundStyle(Color.cardSecondaryText)
            }
        }
    }

    @ViewBuilder private func actions(_ film: Film) -> some View {
        if model.busyFilms.contains(filmID) {
            ProgressView("Processing Film").accessibilityIdentifier("processing-film")
        } else if model.hasPendingSave(filmID) {
            Button("Resume Save", systemImage: "arrow.clockwise") {
                model.perform { try await model.recoverCapture(filmID) }
            }.disabled(model.initialRecoveryPending)
        } else {
            // Before the step that needs space, Open Camera or Development, and never beside a developed Film.
            if let step = film.stepNeedingSpace, let warning = model.storage.warning(for: step) {
                LowStorageNotice(text: warning)
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            }
            if film.completionState == .open {
                Button("Open Camera", systemImage: "camera") { capturing = true }.primaryAction()
            }
            if film.canStartDevelopment {
                Button("Develop Film", systemImage: "sparkles") { developing = true }.primaryAction()
            }
            if film.offersResumeDevelopment {
                Button("Resume Development", systemImage: "arrow.clockwise") { model.perform { try await model.develop(filmID) } }
            }
            if film.captures.contains(where: { $0.revealState == .revealed }) {
                VStack(alignment: .leading, spacing: 16) {
                    Button("Save Developed to Photos", systemImage: "square.and.arrow.down") {
                        model.perform { try await model.export(filmID, originals: false) }
                    }
                    Button("Originals", systemImage: "photo.stack") { originals = true }
                }
            }
            if film.canPlaybackDevelopedMovie && offersSoundChoice(film) {
                Button(movieSoundTitle(film), systemImage: "waveform") { soundtrack = true }
                    .accessibilityIdentifier("movie-sound-choice")
            }
        }
    }

    /// Whether the Movie has a sound to choose: its recorded sound, or a Soundtrack in the catalog for its Camera. A Film
    /// loaded before live sound with no Soundtrack to offer stays silent and shows no choice.
    private func offersSoundChoice(_ film: Film) -> Bool {
        film.camera.recordsLiveSound == true
            || model.mediaCatalog?.assets(for: film.camera.id, purpose: .instrumental).isEmpty == false
    }

    private func movieSoundTitle(_ film: Film) -> String {
        guard let choice = try? model.repository.movieSoundChoice(filmID: filmID) else { return "Movie sound" }
        switch choice {
        case .recordedSound: return "Movie sound: Recorded sound"
        case .soundtrack:
            let title = (try? model.repository.movieAudioSelection(filmID: filmID))?.asset?.title ?? "Soundtrack"
            return "Movie sound: \(title)"
        case .silent: return "Movie sound: Silent"
        }
    }

    @ViewBuilder private func media(_ film: Film) -> some View {
        if film.camera.medium == .photo {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 18) {
                ForEach(film.captures) { capture in
                    VStack(alignment: .leading, spacing: 6) {
                        if capture.revealState == .revealed {
                            Button { selectedPhoto = capture } label: {
                                RevealedPhoto(filmID: filmID, sequence: capture.sequenceNumber)
                                    .aspectRatio(film.camera.printAspectRatio, contentMode: .fit)
                            }.buttonStyle(.plain).accessibilityLabel("Open photo \(capture.sequenceNumber)")
                        } else { placeholder(capture).aspectRatio(film.camera.printAspectRatio, contentMode: .fit) }
                        Text(String(format: "%02d", capture.sequenceNumber)).font(.caption.monospaced())
                    }
                }
            }
        } else {
            if film.canPlaybackDevelopedMovie {
                DevelopedMovieView(filmID: filmID).id(model.mediaRevision)
            }
            ForEach(film.captures) { capture in
                HStack {
                    Text(String(format: "%02d", capture.sequenceNumber)).font(.body.monospaced())
                    if capture.isDiscarded { Text("Discarded").foregroundStyle(Color.cardSecondaryText) }
                    else if case let .movieClip(seconds, _) = capture.kind {
                        Label(String(format: "%.3f sec", seconds), systemImage: capture.revealState == .sealed ? "lock" : "film")
                    }
                    Spacer()
                    if capture.revealState == .revealed {
                        Button("Discard clip", systemImage: "trash", role: .destructive) { discard = capture }
                            .labelStyle(.iconOnly)
                            .accessibilityIdentifier("discard-clip-\(capture.sequenceNumber)")
                    }
                }.padding(.vertical, 8)
            }
        }
    }

    private func placeholder(_ capture: CaptureRecord) -> some View {
        ZStack {
            Rectangle().fill(Color(uiColor: .secondarySystemBackground))
            VStack {
                Image(systemName: capture.isDiscarded ? "minus" : "lock")
                Text(capture.isDiscarded ? "Discarded" : "Sealed").font(.caption)
            }.foregroundStyle(Color.frameSecondaryText)
        }.accessibilityElement(children: .combine)
    }

    private func filmMenu(_ film: Film) -> some View {
        Menu {
            Button("Rename", systemImage: "pencil") { title = film.title; renaming = true }
            Button(film.isArchived ? "Restore from Archive" : "Archive", systemImage: "archivebox") {
                model.perform { try model.repository.setArchived(filmID: filmID, archived: !film.isArchived) }
            }
            if film.completionState == .open && film.camera.revealRule != .instantPerExposure {
                Button(film.camera.medium == .photo ? "Rewind & Develop Early" : "Stop & Develop Early", systemImage: "backward.end") { earlySnapshot = film; early = true }
                    .disabled(film.savedCaptureCount == 0 || model.busyFilms.contains(filmID) || model.hasPendingSave(filmID))
            }
            Button("Delete Film", systemImage: "trash", role: .destructive) { deleting = true }
                .disabled(model.hiddenFilms.contains(filmID))
        } label: { Label("Film actions", systemImage: "ellipsis") }
    }
}

/// An Instant asks about the original of each print after it is revealed (DEC-11): the prints one ask covers.
struct OriginalAsk: Identifiable {
    let prints: [Int]
    var id: [Int] { prints }
}

struct OriginalChoiceView: View {
    @Environment(JournalModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let filmID: UUID
    let startsDevelopment: Bool
    /// The newly revealed Instant prints this choice is asked about; nil for every capture of the Film the choice is open for.
    var prints: [Int]?
    @State private var choice: Bool?
    @State private var working = false
    @State private var error: String?

    private var sequences: [Int] {
        model.film(filmID)?.captures.filter {
            !$0.isDiscarded && (startsDevelopment || $0.revealState == .revealed) && (prints?.contains($0.sequenceNumber) ?? true)
        }.map(\.sequenceNumber) ?? []
    }
    private var undecided: [Int] {
        sequences.filter { (try? model.repository.originalDisposition(filmID: filmID, sequenceNumber: $0)) == nil }
    }
    private var awaitingExport: Bool {
        sequences.contains { (try? model.repository.originalDisposition(filmID: filmID, sequenceNumber: $0)) == .exportRequested }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section { Text(PrivacyCopy.sources) }
                if !undecided.isEmpty {
                    Section(heading) {
                        // A revealed print is saved as soon as its choice is confirmed, so its rows say what happens now.
                        choiceRow(startsDevelopment ? "Save Originals to Photos after reveal" : "Save to Photos, then remove from Immerse", value: true)
                        choiceRow(startsDevelopment ? "Remove originals after verified Development" : "Remove from Immerse without saving", value: false)
                    }
                }
                if let error { Text(error).foregroundStyle(.red) }
                if startsDevelopment || !undecided.isEmpty {
                    Button(startsDevelopment ? "Develop Film" : "Confirm choice", systemImage: "checkmark") {
                        working = true
                        Task {
                            defer { working = false }
                            do {
                                if let choice { try model.chooseOriginals(filmID, sequences: undecided, export: choice) }
                                if startsDevelopment {
                                    dismiss()
                                    model.perform { try await model.develop(filmID) }
                                } else if choice == true {
                                    // Already revealed, so the save happens now. If it fails, the choice stands and
                                    // Save Originals to Photos below tries again.
                                    try await model.export(filmID, originals: true)
                                    dismiss()
                                } else { try await model.processor.cleanupSources(filmID: filmID); dismiss() }
                            } catch { self.error = FailureCopy.message(for: error) }
                        }
                    }.disabled(working || (!undecided.isEmpty && choice == nil))
                        .accessibilityIdentifier("confirm-original-choice")
                }
                if !startsDevelopment && awaitingExport {
                    Button("Save Originals to Photos", systemImage: "square.and.arrow.down") {
                        working = true
                        Task {
                            defer { working = false }
                            do { try await model.export(filmID, originals: true); dismiss() }
                            catch { self.error = FailureCopy.message(for: error) }
                        }
                    }.disabled(working)
                }
                if working { ProgressView() }
            }
            .navigationTitle(startsDevelopment ? "Development" : "Originals")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(working) } }
            .interactiveDismissDisabled(working)
        }
    }

    private var heading: String {
        guard let prints, !startsDevelopment else { return "Original captures" }
        return prints.count == 1 ? "Original of photo \(prints[0])" : "Originals of \(prints.count) photos"
    }

    private func choiceRow(_ title: String, value: Bool) -> some View {
        Button { choice = value } label: {
            HStack { Text(title); Spacer(); Image(systemName: choice == value ? "checkmark.circle.fill" : "circle") }
        }.foregroundStyle(.primary).accessibilityAddTraits(choice == value ? .isSelected : [])
    }
}

private struct DevelopedMovieView: View {
    @Environment(JournalModel.self) private var model
    let filmID: UUID
    @State private var player: AVPlayer?
    @State private var error: String?

    var body: some View {
        Group {
            if model.hiddenFilms.contains(filmID) { Color.clear }
            else if model.busyFilms.contains(filmID) { ProgressView("Preparing Movie") }
            else if let player {
                VideoPlayer(player: player)
                    .aspectRatio(model.film(filmID)?.movieOrientation == .portrait ? 0.75 : 4.0 / 3, contentMode: .fit)
                    .accessibilityIdentifier("developed-movie-player")
            }
            else if let error {
                VStack {
                    Text(error)
                    Button("Rebuild Movie", systemImage: "arrow.clockwise") { model.perform { try await model.develop(filmID) } }
                }
            } else { ProgressView() }
        }
        .task {
            do {
                let asset = try model.repository.revealedAsset(filmID: filmID, sequenceNumber: 0, kind: .movie)
                MoviePlaybackAudio.prepare()
                player = AVPlayer(url: asset.url)
            } catch { self.error = "Movie is unavailable until reassembly finishes." }
        }
        .onChange(of: model.hiddenFilms.contains(filmID)) { _, hidden in if hidden { clear() } }
        .onChange(of: model.busyFilms.contains(filmID)) { _, busy in if busy { clear() } }
        .onDisappear { clear() }
    }
    private func clear() {
        player?.pause(); player?.replaceCurrentItem(with: nil); player = nil
        MoviePlaybackAudio.finish()
    }
}
