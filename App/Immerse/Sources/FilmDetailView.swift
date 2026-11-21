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
                    VStack(alignment: .leading, spacing: 16) {
                        header(film)
                        if model.hiddenFilms.contains(filmID) {
                            ProgressView("Removing private media").tint(.white).frame(maxWidth: .infinity).padding(.top, 40)
                        } else {
                            status(film)
                            notices(film)
                            media(film)
                        }
                    }
                    .padding(.horizontal, Orbit.gutter)
                    .padding(.bottom, 24)
                }
                .safeAreaBar(edge: .bottom, spacing: 8) { mainActions(film) }
                .navigationTitle(SpokenText.title(film.title)).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // The title is the screen's own heading (C01), so the bar shows only its buttons.
                    ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1).accessibilityHidden(true) }
                    toolbarActions(film)
                }
            } else {
                Text("Film removed").orbitFont(.heading).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .orbitGround()
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
        .orbitConfirmation(isPresented: $deleting, symbol: "trash", emphasized: true, title: "Delete Film?",
                           message: PrivacyCopy.deleteFilm, confirm: "Delete Film", identifier: "confirm-delete-film") {
            model.perform { try await model.remove(filmID); dismiss() }
        }
        .orbitConfirmation(isPresented: $early, ring: earlySnapshot.map { OrbitRingValue(progress: $0.progress, amount: $0.remainingAmountLabel(recordedFor: 0), caption: "unused") }, title: "Complete Film early?",
                           message: "\(earlySnapshot?.exactWasteLabel ?? "Unused capacity") will be permanently wasted. The Film cannot reopen. Development is a separate confirmation.",
                           confirm: "Complete Film") {
            model.perform {
                try await model.recoverCapture(filmID)
                guard let snapshot = earlySnapshot else { throw PersistenceError.capacityChangedSinceConfirmation }
                _ = try model.repository.completeEarly(filmID: filmID, confirmedCaptureCount: snapshot.savedCaptureCount)
                developing = true
            }
        }
        .orbitConfirmation(isPresented: Binding(get: { discard != nil }, set: { if !$0 { discard = nil } }),
                           symbol: "film", title: "Discard capture?", message: PrivacyCopy.discard,
                           confirm: discard.map { "Discard #\($0.sequenceNumber)" } ?? "Discard") {
            if let discard {
                model.perform { try await model.remove(filmID, sequence: discard.sequenceNumber) }
            }
        }
    }

    // MARK: Header

    /// The Film's state and Camera, its title, and a line of facts (C01, H02).
    private func header(_ film: Film) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            DotLine {
                OrbitSectionLabel(film.journalState)
                OrbitSectionLabel(film.camera.shortName)
            }
            .orbitFont(.label).foregroundStyle(Orbit.label)
            film.titleText.orbitFont(.title).foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            DotLine {
                if let stock = film.filmStock { Text("\(stock.label) Film Stock") }
                if film.developmentState == .developed, let summary = Self.summary(film) { Text(SpokenText.shown(summary)) }
                if let range = film.captureDateRange {
                    Text("\(range.lowerBound.formatted(date: .abbreviated, time: .omitted)) - \(range.upperBound.formatted(date: .abbreviated, time: .omitted))")
                }
            }
            .orbitFont(.footnote).foregroundStyle(Orbit.label)
        }
        .padding(.top, 4)
    }

    private static func exposures(_ film: Film) -> Int? {
        if case let .exposures(count) = film.camera.capacity { return count }
        return nil
    }

    /// "5 prints, 1 discarded" or "7 clips".
    private static func summary(_ film: Film) -> String? {
        let kept = film.captures.filter { !$0.isDiscarded }.count
        let discarded = film.captures.count - kept
        let noun = film.camera.medium == .photo ? (kept == 1 ? "print" : "prints") : (kept == 1 ? "clip" : "clips")
        return discarded > 0 ? "\(kept) \(noun), \(discarded) discarded" : "\(kept) \(noun)"
    }

    // MARK: Status

    /// The Film's ring (C01, G01, G03): what is left on a Film on the roll, its sealed exposures once it is ready to
    /// develop, and Development while it runs. A developed Film shows its prints or Movie instead.
    @ViewBuilder private func status(_ film: Film) -> some View {
        if model.busyFilms.contains(filmID) {
            ProcessingRing()
                .frame(width: 300, height: 300)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
        } else if model.hasPendingSave(filmID) {
            FilmRing(progress: film.progress, white: false) {
                ProgressView().tint(.white).controlSize(.large)
                Text("Finishing save").orbitFont(.footnote).foregroundStyle(Orbit.label)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Finishing save")
            .accessibilityAddTraits(.isStaticText)
        } else if film.developmentState != .developed && film.camera.revealRule != .instantPerExposure {
            ringOfCapacity(film)
        } else if film.camera.revealRule == .instantPerExposure && film.developmentState != .developed {
            HStack {
                remainingLine(film)
                Spacer()
                ZStack {
                    OrbitRing(progress: film.progress, lineWidth: 3)
                    Text(film.remainingAmountLabel(recordedFor: 0)).font(.orbit(size: 18, weight: .extraBold, relativeTo: .headline))
                }
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)
            }
        } else {
            remainingLine(film)
        }
    }

    /// The remaining capacity in words, as the Film's other screens show it; on a developed Film, what was wasted.
    private func remainingLine(_ film: Film) -> some View {
        film.remainingText.orbitFont(.footnote).foregroundStyle(Orbit.label)
    }

    /// The big ring: what is used, with what is left in its middle while the Film is open; full and white, with the sealed
    /// count, once it is ready to develop.
    private func ringOfCapacity(_ film: Film) -> some View {
        let open = film.completionState == .open
        let amount = film.remainingAmountLabel(recordedFor: 0)
        let sealed = film.captures.filter { $0.revealState == .sealed && !$0.isDiscarded }.count
        let label = film.remainingLabel
        let words = label.hasPrefix(amount + " ") ? String(label.dropFirst(amount.count + 1)) : label
        return FilmRing(progress: film.progress, white: !open) {
            Text(open ? amount : String(sealed)).orbitFont(.numeral)
                .minimumScaleFactor(0.5).lineLimit(1)
            Text(open ? words : film.camera.medium == .photo ? "sealed exposures" : "sealed clips")
                .font(.orbit(.footnote, weight: open ? nil : .semibold))
                .foregroundStyle(open ? Orbit.label : Orbit.onWhiteSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(film.remainingText)
        .accessibilityAddTraits(.isStaticText)
        .padding(.top, 6)
    }

    // MARK: Notices and actions

    @ViewBuilder private func notices(_ film: Film) -> some View {
        if !model.busyFilms.contains(filmID), !model.hasPendingSave(filmID),
           let step = film.stepNeedingSpace, let warning = model.storage.warning(for: step) {
            LowStorageNotice(text: warning)
        }
        if film.canPlaybackDevelopedMovie && offersSoundChoice(film) && !model.busyFilms.contains(filmID) {
            Button { soundtrack = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "waveform").font(.system(size: 17, weight: .semibold)).foregroundStyle(.black)
                        .frame(width: 40, height: 40).background(Color.white, in: Circle())
                    Text(movieSoundTitle(film)).orbitFont(.body, weight: .bold).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(Orbit.label)
                }
                .padding(.leading, 8).padding(.trailing, 20).padding(.vertical, 8)
                .frame(minHeight: 56)
                .background(Orbit.surface, in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(movieSoundTitle(film))
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("movie-sound-choice")
        }
    }

    /// The screen's actions on the home area: the one cream main action, and any other as a pill beside it.
    @ViewBuilder private func mainActions(_ film: Film) -> some View {
        if model.hiddenFilms.contains(filmID) {
            EmptyView()
        } else if model.busyFilms.contains(filmID) {
            HStack(spacing: 12) {
                Circle().fill(Color.white).frame(width: 10, height: 10).accessibilityHidden(true)
                Text("Keep Immerse open until it finishes.").orbitFont(.callout).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 22).padding(.vertical, 14)
            .background(Orbit.surface, in: Capsule())
            .padding(.horizontal, Orbit.gutter).padding(.bottom, 8)
        } else if model.hasPendingSave(filmID) {
            Button("Resume Save", systemImage: "arrow.clockwise") {
                model.perform { try await model.recoverCapture(filmID) }
            }
            .primaryAction()
            .disabled(model.initialRecoveryPending)
            .padding(.horizontal, 24).padding(.bottom, 8)
        } else {
            let actions = Self.actions(film)
            if !actions.isEmpty {
                VStack(spacing: 10) {
                    ForEach(Array(actions.enumerated()), id: \.element) { index, action in
                        actionButton(action, film: film, main: index == 0)
                    }
                }
                .padding(.horizontal, 24).padding(.bottom, 8)
            }
        }
    }

    private enum Action: Hashable { case openCamera, develop, resume }

    private static func actions(_ film: Film) -> [Action] {
        var actions: [Action] = []
        if film.completionState == .open { actions.append(.openCamera) }
        if film.canStartDevelopment { actions.append(.develop) }
        if film.offersResumeDevelopment { actions.append(.resume) }
        return actions
    }

    @ViewBuilder private func actionButton(_ action: Action, film: Film, main: Bool) -> some View {
        let button = switch action {
        case .openCamera: Button("Open Camera", systemImage: "camera") { capturing = true }
        case .develop: Button("Develop Film", systemImage: "sparkles") { developing = true }
        case .resume: Button("Resume Development", systemImage: "arrow.clockwise") {
            model.perform { try await model.develop(filmID) }
        }
        }
        if main { button.primaryAction() } else { button.buttonStyle(OrbitPillStyle(minHeight: 52, fullWidth: true)) }
    }

    /// The bar's buttons (H01): Save Developed to Photos, white, and Originals once a print is developed, and Film actions.
    @ToolbarContentBuilder private func toolbarActions(_ film: Film) -> some ToolbarContent {
        if !model.hiddenFilms.contains(filmID), !model.busyFilms.contains(filmID), !model.hasPendingSave(filmID),
           film.captures.contains(where: { $0.revealState == .revealed }) {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save Developed to Photos", systemImage: "square.and.arrow.down") {
                    model.perform { try await model.export(filmID, originals: false) }
                }
                .buttonStyle(OrbitCircleButtonStyle(selected: true))
            }
            .sharedBackgroundVisibility(.hidden)
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) {
                Button("Originals", systemImage: "photo.stack") { originals = true }
                    .buttonStyle(OrbitCircleButtonStyle())
            }
            .sharedBackgroundVisibility(.hidden)
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
        }
        ToolbarItem(placement: .topBarTrailing) { filmMenu(film) }
            .sharedBackgroundVisibility(.hidden)
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

    // MARK: Media

    @ViewBuilder private func media(_ film: Film) -> some View {
        if film.camera.medium == .photo {
            let sealed = film.captures.filter { $0.revealState == .sealed && !$0.isDiscarded }
            let shown = film.captures.filter { $0.revealState == .revealed || $0.isDiscarded }
            if !sealed.isEmpty, film.camera.revealRule != .instantPerExposure || shown.isEmpty {
                SealedDots(sealed: sealed.count, capacity: Self.exposures(film) ?? sealed.count,
                           open: film.completionState == .open)
                    .padding(.top, 8)
            }
            if !shown.isEmpty {
                PrintGrid {
                    ForEach(shown) { capture in printCell(capture, film: film) }
                }
                .padding(.top, 10)
            }
        } else {
            if film.canPlaybackDevelopedMovie {
                DevelopedMovieView(filmID: filmID).id(model.mediaRevision)
            }
            if !film.captures.isEmpty {
                OrbitSectionLabel("Clips").padding(.top, 4)
                VStack(spacing: 8) {
                    ForEach(film.captures) { capture in clipRow(capture) }
                }
            }
        }
    }

    @ViewBuilder private func printCell(_ capture: CaptureRecord, film: Film) -> some View {
        let number = Text(String(capture.sequenceNumber))
        if capture.isDiscarded {
            VStack(spacing: 4) {
                Image(systemName: "minus").font(.system(size: 16, weight: .semibold))
                Text("Discarded").font(.orbit(size: 12, weight: .semibold, relativeTo: .caption))
            }
            .foregroundStyle(Orbit.smallest)
            .frame(width: 120, height: 120)
            .overlay(Circle().strokeBorder(Orbit.hairline, lineWidth: 1))
            .overlay(alignment: .topTrailing) { FrameNumber(number: number, discarded: true) }
            .accessibilityElement(children: .combine)
            .printCellWidth(1)
        } else {
            Button { selectedPhoto = capture } label: {
                PrintThumbnail(filmID: filmID, sequence: capture.sequenceNumber, isInstant: film.camera.id == .instant1970s)
                    .overlay(alignment: .topTrailing) { FrameNumber(number: number, discarded: false) }
            }
            .buttonStyle(BubbleLikePressStyle())
            .accessibilityLabel("Open photo \(capture.sequenceNumber)")
        }
    }

    private func clipRow(_ capture: CaptureRecord) -> some View {
        HStack(spacing: 12) {
            Text(String(format: "%02d", capture.sequenceNumber))
                .font(.orbit(size: 13, weight: .extraBold, relativeTo: .footnote))
                .foregroundStyle(capture.isDiscarded ? Orbit.smallest : .white)
                .frame(width: 40, height: 40)
                .background { if capture.isDiscarded { Circle().strokeBorder(Orbit.hairline) } else { Circle().fill(Orbit.pressed) } }
            if capture.isDiscarded {
                Text("Discarded").orbitFont(.body, weight: .semibold).foregroundStyle(Orbit.smallest)
            } else if case let .movieClip(seconds, _) = capture.kind {
                Label {
                    Text(String(format: "%.3f sec", seconds)).orbitFont(.body, weight: .semibold).foregroundStyle(.white)
                } icon: {
                    if capture.revealState == .sealed {
                        Image(systemName: "lock").foregroundStyle(Orbit.label)
                    }
                }
            }
            Spacer(minLength: 0)
            if capture.revealState == .revealed && !capture.isDiscarded {
                Button("Discard clip", systemImage: "trash") { discard = capture }
                    .buttonStyle(OrbitCircleButtonStyle())
                    .accessibilityIdentifier("discard-clip-\(capture.sequenceNumber)")
            }
        }
        .padding(.leading, 8).padding(.trailing, 6).padding(.vertical, 6)
        .frame(minHeight: 56)
        .background {
            if capture.isDiscarded { Capsule().strokeBorder(Orbit.pressed, lineWidth: 1) } else { Capsule().fill(Orbit.surface) }
        }
    }

    private func filmMenu(_ film: Film) -> some View {
        Menu {
            Button("Rename", systemImage: "pencil") { title = film.title; renaming = true }
            Button(film.isArchived ? "Restore from Archive" : "Archive", systemImage: "archivebox") {
                model.perform { try model.repository.setArchived(filmID: filmID, archived: !film.isArchived) }
            }
            if film.completionState == .open && film.camera.revealRule != .instantPerExposure {
                Button(film.camera.medium == .photo ? "Finish & Develop Early" : "Stop & Develop Early",
                       systemImage: film.camera.medium == .photo ? "forward.end" : "backward.end") { earlySnapshot = film; early = true }
                    .disabled(film.savedCaptureCount == 0 || model.busyFilms.contains(filmID) || model.hasPendingSave(filmID))
            }
            // No destructive role: Orbit keeps red for the shutter alone.
            Button("Delete Film", systemImage: "trash") { deleting = true }
                .disabled(model.hiddenFilms.contains(filmID))
        } label: {
            Label("Film actions", systemImage: "ellipsis")
        }
        .menuStyle(.button)
        .buttonStyle(OrbitCircleButtonStyle())
    }
}

/// The Film's big ring (C01): 240 points with a 12-point ring and the count on the surface in its middle, or white once
/// the Film is ready to develop (G01).
private struct FilmRing<Content: View>: View {
    let progress: Double
    let white: Bool
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            OrbitRing(progress: white ? 1 : progress, lineWidth: 12)
            VStack(spacing: 2) { content }
                .foregroundStyle(white ? Color.black : Color.white)
                .multilineTextAlignment(.center)
                .padding(12)
                .frame(width: 168, height: 168)
                .background(white ? Color.white : Orbit.surface, in: Circle())
        }
        .frame(width: 240, height: 240)
        .frame(maxWidth: .infinity)
    }
}

/// Development running (G03): a 16-point ring turning round its track, with Processing Film in its middle.
private struct ProcessingRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var turning = false

    var body: some View {
        ZStack {
            Circle().inset(by: 8).stroke(Orbit.pressed, lineWidth: 16)
            Circle().inset(by: 8).trim(from: 0, to: 0.3)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(turning ? 270 : -90))
                .animation(reduceMotion ? nil : .linear(duration: 1.6).repeatForever(autoreverses: false), value: turning)
            VStack(spacing: 4) {
                Image(systemName: "sparkles").font(.system(size: 34, weight: .light))
                Text("Processing Film").orbitFont(.headline)
            }
            .foregroundStyle(.white)
            .frame(width: 200, height: 200)
            .background(Orbit.surface, in: Circle())
        }
        .onAppear { turning = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Processing Film")
        .accessibilityIdentifier("processing-film")
    }
}

/// A Film's sealed exposures (C01): a dot for each one taken, grey, and an empty one for each still to take, under a
/// label that says how many are sealed.
private struct SealedDots: View {
    let sealed: Int
    let capacity: Int
    let open: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                OrbitSectionLabel("\(sealed) sealed until Development")
                Spacer()
                Image(systemName: "lock").font(.system(size: 12, weight: .semibold)).foregroundStyle(Orbit.label)
                    .accessibilityHidden(true)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 9), spacing: 12) {
                ForEach(0..<max(capacity, sealed), id: \.self) { index in
                    Group {
                        if index < sealed { Circle().fill(Orbit.disabledMark) }
                        else { Circle().strokeBorder(Orbit.hairline, lineWidth: 1) }
                    }
                    .frame(width: 22, height: 22)
                }
            }
            .accessibilityHidden(true)
        }
    }
}

/// A frame number on a print's corner (H01): a white disc with a black ring around it, grey for a discarded frame.
private struct FrameNumber: View {
    let number: Text
    let discarded: Bool

    var body: some View {
        number.font(.orbit(size: 11, weight: .extraBold, relativeTo: .caption2))
            .foregroundStyle(discarded ? Orbit.label : .black)
            .frame(minWidth: 26, minHeight: 26)
            .background(discarded ? Orbit.pressed : Color.white, in: Circle())
            .background(Circle().fill(Color.black).padding(-3))
            .offset(x: 8, y: -8)
            .accessibilityHidden(true)
    }
}

/// A developed print in the Film screen's grid (H01, H02): in its own shape, upright or sideways, and an Instant print on
/// its white card.
private struct PrintThumbnail: View {
    let filmID: UUID
    let sequence: Int
    let isInstant: Bool

    var body: some View {
        RevealedPhoto(filmID: filmID, sequence: sequence, keepsPictureOutOfSight: true, takesItsShape: true)
            .clipShape(RoundedRectangle(cornerRadius: isInstant ? 0 : 3))
    }
}

private struct BubbleLikePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct PrintCellWidthKey: LayoutValueKey {
    static let defaultValue: CGFloat? = nil
}

private extension View {
    /// A cell's own width as a share of its column, for one that keeps a size of its own.
    func printCellWidth(_ share: CGFloat) -> some View { layoutValue(key: PrintCellWidthKey.self, value: share) }
}

/// The developed prints in two loose columns (H01, H02, "option A"): prints alternate left and right in capture order,
/// the right column starts 52 points lower, and every second print in a column is narrower and set to one side, so the
/// grid reads loose rather than as a contact sheet.
private struct PrintGrid: Layout {
    var spacing: CGFloat = 20
    var rowSpacing: CGFloat = 16

    private func frames(width: CGFloat, subviews: Subviews) -> [CGRect] {
        let column = (width - spacing) / 2
        var bottoms: [CGFloat] = [0, 52]
        var counts = [0, 0]
        return subviews.enumerated().map { index, subview in
            let side = index % 2
            let narrow = counts[side] % 3 == 1
            let cellWidth = subview[PrintCellWidthKey.self].map { _ in subview.sizeThatFits(.unspecified).width }
                ?? (narrow ? column * 0.82 : column)
            let size = subview.sizeThatFits(ProposedViewSize(width: cellWidth, height: nil))
            let trailing = side == 0 ? narrow : counts[side] % 3 == 2
            let x = (side == 0 ? 0 : column + spacing) + (trailing ? column - size.width : 0)
            let frame = CGRect(x: x, y: bottoms[side], width: size.width, height: size.height)
            bottoms[side] = frame.maxY + rowSpacing
            counts[side] += 1
            return frame
        }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? 358
        return CGSize(width: width, height: frames(width: width, subviews: subviews).map(\.maxY).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (subview, frame) in zip(subviews, frames(width: bounds.width, subviews: subviews)) {
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), anchor: .topLeading,
                          proposal: ProposedViewSize(width: frame.width, height: frame.height))
        }
    }
}

/// Short facts on one line with a dot between them, wrapping to the next line where they do not fit. Each fact stays its
/// own text for VoiceOver; the dots are not read.
struct DotLine<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        DotLineLayout { Group(subviews: content) { subviews in
            ForEach(Array(subviews.enumerated()), id: \.element.id) { index, subview in
                if index > 0 { Text("·").accessibilityHidden(true) }
                subview
            }
        } }
    }
}

private struct DotLineLayout: Layout {
    var spacing: CGFloat = 5
    var lineSpacing: CGFloat = 2

    private func frames(width: CGFloat, subviews: Subviews) -> [CGRect] {
        var frames: [CGRect] = []
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0
        for subview in subviews {
            var size = subview.sizeThatFits(.unspecified)
            if size.width > width { size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil)) }
            if x > 0, x + size.width > width {
                x = 0; y += lineHeight + lineSpacing; lineHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return frames
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? 358
        let frames = frames(width: width, subviews: subviews)
        return CGSize(width: frames.map(\.maxX).max() ?? 0, height: frames.map(\.maxY).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (subview, frame) in zip(subviews, frames(width: bounds.width, subviews: subviews)) {
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), anchor: .topLeading,
                          proposal: ProposedViewSize(frame.size))
        }
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
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(PrivacyCopy.sources).orbitFont(.body).foregroundStyle(Orbit.body)
                        .fixedSize(horizontal: false, vertical: true)
                    if !undecided.isEmpty {
                        OrbitSectionLabel(heading).padding(.top, 4)
                        VStack(spacing: 10) {
                            // A revealed print is saved as soon as its choice is confirmed, so its rows say what happens now.
                            OrbitRadioRow(title: startsDevelopment ? "Save Originals to Photos after reveal" : "Save to Photos, then remove from Immerse",
                                          selected: choice == true) { choice = true }
                            OrbitRadioRow(title: startsDevelopment ? "Remove originals after verified Development" : "Remove from Immerse without saving",
                                          selected: choice == false) { choice = false }
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel(heading)
                    }
                    if let error { OrbitNote(.error, error) }
                    if working { ProgressView().tint(.white).frame(maxWidth: .infinity) }
                }
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
            }
            .safeAreaBar(edge: .bottom, spacing: 8) {
                VStack(spacing: 10) {
                    if startsDevelopment || !undecided.isEmpty {
                        Button(startsDevelopment ? "Develop Film" : "Confirm choice") { confirm() }
                            .primaryAction()
                            .disabled(working || (!undecided.isEmpty && choice == nil))
                            .accessibilityIdentifier("confirm-original-choice")
                    }
                    if !startsDevelopment && awaitingExport {
                        Button("Save Originals to Photos", systemImage: "square.and.arrow.down") { saveOriginals() }
                            .buttonStyle(OrbitPillStyle(minHeight: 52, fullWidth: true))
                            .disabled(working)
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 8)
            }
            .navigationTitle(startsDevelopment ? "Development" : "Originals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.buttonStyle(OrbitPillStyle(inBar: true)).disabled(working)
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .interactiveDismissDisabled(working)
            .orbitSheetGround()
        }
        .orbitSheet()
    }

    private func confirm() {
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
    }

    private func saveOriginals() {
        working = true
        Task {
            defer { working = false }
            do { try await model.export(filmID, originals: true); dismiss() }
            catch { self.error = FailureCopy.message(for: error) }
        }
    }

    private var heading: String {
        guard let prints, !startsDevelopment else { return "Original captures" }
        return prints.count == 1 ? "Original of photo \(prints[0])" : "Originals of \(prints.count) photos"
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
            else if model.busyFilms.contains(filmID) {
                ProgressView("Preparing Movie").tint(.white).frame(maxWidth: .infinity, minHeight: 200)
            }
            else if let player {
                VideoPlayer(player: player)
                    .aspectRatio(model.film(filmID)?.movieOrientation == .portrait ? 0.75 : 4.0 / 3, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .accessibilityIdentifier("developed-movie-player")
            }
            else if let error {
                VStack(spacing: 14) {
                    Text(error).orbitFont(.body).foregroundStyle(Orbit.body).multilineTextAlignment(.center)
                    Button("Rebuild Movie", systemImage: "arrow.clockwise") { model.perform { try await model.develop(filmID) } }
                        .buttonStyle(OrbitPillStyle())
                }
                .padding(24).frame(maxWidth: .infinity, minHeight: 200)
                .background(Orbit.pressed, in: RoundedRectangle(cornerRadius: 20))
            } else { ProgressView().tint(.white).frame(maxWidth: .infinity, minHeight: 200) }
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
        if player != nil { MoviePlaybackAudio.finish() }
        player?.pause(); player?.replaceCurrentItem(with: nil); player = nil
    }
}
