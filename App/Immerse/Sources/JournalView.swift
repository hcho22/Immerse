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
                .safeAreaBar(edge: .bottom, spacing: 10) { startFilm }
                .navigationTitle("Film Journal")
                .toolbarTitleDisplayMode(.inlineLarge)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink(value: JournalRoute.archive) {
                            Label("Archive", systemImage: "archivebox")
                        }
                        .buttonStyle(OrbitCircleButtonStyle())
                    }
                    .sharedBackgroundVisibility(.hidden)
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Settings", systemImage: "gearshape") { settings = true }
                            .buttonStyle(OrbitCircleButtonStyle())
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
                .navigationDestination(for: JournalRoute.self) { route in
                    switch route {
                    case .archive:
                        FilmList(archived: true).navigationTitle("Archive").navigationBarTitleDisplayMode(.large)
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

    /// Start a Film (A01): the round cream main action on the home area's top edge, 112 points across with its ring.
    /// Like a bar item, it keeps one size, its words follow the text size only up to Extra Extra Large, and larger sizes
    /// get the Large Content Viewer.
    private var startFilm: some View {
        Button { setup = true } label: {
            Label { Text("Start a Film") } icon: {
                Image(systemName: "plus").font(.system(size: 24, weight: .semibold))
            }
        }
        .buttonStyle(OrbitRoundMainActionStyle(diameter: 112))
        .dynamicTypeSize(...DynamicTypeSize.large)
        .accessibilityShowsLargeContentViewer()
        .accessibilityIdentifier("start-film")
        .disabled(model.initialRecoveryPending)
    }
}

private struct FilmList: View {
    @Environment(JournalModel.self) private var model
    let archived: Bool
    private var films: [Film] { model.films.filter { $0.isArchived == archived } }
    /// The Journal's order (A01): the Films still on their way as bubbles, then the developed Films beneath.
    private let states = ["On the roll", "Ready to develop", "Developing", "Pack complete"]

    var body: some View {
        ScrollView {
            if films.isEmpty {
                EmptyJournal(text: archived ? "No archived Films" : "Your Journal begins here",
                             symbol: archived ? "archivebox" : "camera")
                    .containerRelativeFrame(.vertical, alignment: .center) { length, _ in length * 0.8 }
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    let unfinished = states.flatMap { state in films.filter { $0.journalState == state } }
                    if !unfinished.isEmpty {
                        BubbleField {
                            ForEach(unfinished) { film in
                                NavigationLink(value: JournalRoute.film(film.id)) { FilmBubble(filmID: film.id) }
                                    .buttonStyle(BubblePressStyle())
                                    .accessibilityIdentifier("journal-film")
                            }
                        }
                    }
                    let developed = films.filter { $0.journalState == "Developed" }
                    if !developed.isEmpty {
                        OrbitSectionLabel("Developed")
                        LooseColumns {
                            ForEach(developed) { film in
                                NavigationLink(value: JournalRoute.film(film.id)) { DevelopedFilmItem(filmID: film.id) }
                                    .buttonStyle(BubblePressStyle())
                                    .accessibilityIdentifier("journal-film")
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                }
                .padding(.horizontal, Orbit.gutter)
                .padding(.top, 16).padding(.bottom, 24)
            }
        }
        .orbitGround()
        .refreshable { model.refresh() }
    }
}

/// The Journal with no Films (A02): orbits around the Camera, and the line that says where the Journal begins.
private struct EmptyJournal: View {
    let text: String
    let symbol: String

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                OrbitDashedRing(lineWidth: 1, dash: [2, 6], color: Orbit.hairline)
                Circle().strokeBorder(Orbit.pressed, lineWidth: 1).padding(36)
                Image(systemName: symbol).font(.system(size: 28, weight: .light)).foregroundStyle(.white)
                    .frame(width: 72, height: 72).background(Orbit.surface, in: Circle())
                    .accessibilityIdentifier(symbol)
                Circle().fill(Orbit.button).frame(width: 28, height: 28).offset(x: -100, y: -48)
                Circle().fill(Orbit.pressed).frame(width: 16, height: 16).offset(x: 80, y: -88)
                Circle().fill(Orbit.button).frame(width: 22, height: 22).offset(x: 107, y: 39)
            }
            .frame(width: 240, height: 240)
            .accessibilityHidden(true)
            Text(text).orbitFont(.heading).multilineTextAlignment(.center).foregroundStyle(.white)
                .padding(.horizontal, Orbit.gutter)
        }
        .frame(maxWidth: .infinity)
    }
}

/// A Film still on its way, as a bubble (K00): on the roll, a big dark bubble with a ring for what is used; ready to
/// develop or with its pack complete, a white one; developing, a dark one in a dashed ring.
private struct FilmBubble: View {
    @Environment(JournalModel.self) private var model
    let filmID: UUID

    var body: some View {
        if let film = model.film(filmID) { bubble(film) }
    }

    private func bubble(_ film: Film) -> some View {
        let state = film.journalState
        let white = state == "Ready to develop" || state == "Pack complete"
        let onTheRoll = state == "On the roll"
        let saving = model.hasPendingSave(film.id)
        let caption = saving ? "Finishing save"
            : onTheRoll ? "\(film.camera.shortName) · \(film.remainingAmountLabel(recordedFor: 0)) left"
            : film.camera.shortName
        return VStack(spacing: 2) {
            OrbitSectionLabel(state, color: white ? .black : Orbit.label)
            film.titleText
                .font(onTheRoll ? .orbit(.heading) : .orbit(.headline))
                .tracking(onTheRoll ? OrbitType.heading.tracking : 0)
                .lineLimit(3)
            Text(SpokenText.shown(caption))
                .font(white ? .orbit(.footnote, weight: .semibold) : .orbit(.footnote))
                .foregroundStyle(white ? Orbit.onWhiteSecondary : Orbit.body)
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(white ? Color.black : Color.white)
        .modifier(CircleFit(minimum: onTheRoll ? 200 : white ? 150 : 144))
        .background {
            ZStack {
                Circle().fill(white ? Color.white : state == "Developing" ? Orbit.sunken : Orbit.surface)
                if onTheRoll { OrbitRing(progress: film.progress, lineWidth: 6).padding(2) }
                if state == "Developing" { OrbitDashedRing().padding(1) }
            }
        }
        .contentShape(Circle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken(film, state: state, saving: saving))
    }

    private func spoken(_ film: Film, state: String, saving: Bool) -> String {
        let detail = saving ? "Finishing save" : state == "On the roll" ? film.remainingSpokenLabel : nil
        return [state, SpokenText.of(film.title), SpokenText.of(film.camera.shortName), detail].compactMap { $0 }
            .joined(separator: ", ")
    }
}

/// A developed Film (A01): its first print in a circle, or a play mark for a Movie, with its title and Camera beneath.
private struct DevelopedFilmItem: View {
    @Environment(JournalModel.self) private var model
    let filmID: UUID

    var body: some View {
        if let film = model.film(filmID) { item(film) }
    }

    private func item(_ film: Film) -> some View {
        let caption = model.hasPendingSave(film.id) ? "Finishing save" : Self.caption(film)
        return VStack(alignment: .leading, spacing: 2) {
            thumbnail(film)
                .frame(width: 112, height: 112)
                .clipShape(Circle())
                .padding(.bottom, 8)
            film.titleText.orbitFont(.body, weight: .bold).foregroundStyle(.white).lineLimit(3)
            Text(SpokenText.shown(caption)).orbitFont(.footnote).foregroundStyle(Orbit.label)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Developed, \(SpokenText.of(film.title)), \(SpokenText.of(caption))")
    }

    @ViewBuilder private func thumbnail(_ film: Film) -> some View {
        let first = film.captures.first { $0.revealState == .revealed && !$0.isDiscarded }
        if film.camera.medium == .photo, let first, !model.hiddenFilms.contains(film.id) {
            RevealedPhoto(filmID: film.id, sequence: first.sequenceNumber, fills: true)
        } else {
            ZStack {
                Orbit.pressed
                if film.camera.medium == .movie {
                    Image(systemName: "play.fill").font(.system(size: 24)).foregroundStyle(.white)
                }
            }
        }
    }

    /// "Disposable · 5 prints" or "Super 8 · 0:42 Movie".
    static func caption(_ film: Film) -> String {
        if film.camera.medium == .movie {
            return "\(film.camera.shortName) · \(MovieDurationText.clock(MovieDurationText.wholeSeconds(film.consumedMovieSeconds))) Movie"
        }
        let prints = film.captures.filter { $0.revealState == .revealed && !$0.isDiscarded }.count
        return "\(film.camera.shortName) · \(prints) \(prints == 1 ? "print" : "prints")"
    }
}

/// A bubble pressed: 96 percent of its size (K00).
private struct BubblePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// The bubbles of the Films still on their way, in the Journal's order (A01): each goes under the shorter of two loose
/// columns, the right one starting lower and every other bubble set in, and moves down until it clears every bubble
/// above it, so they never overlap and read top to bottom in order.
private struct BubbleField: Layout {
    var spacing: CGFloat = 16

    private func frames(width: CGFloat, subviews: Subviews) -> [CGRect] {
        var placed: [CGRect] = []
        var bottoms: [CGFloat] = [0, 18]
        var counts = [0, 0]
        var lastY: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
            let side = min(max(size.width, size.height), width)
            let column = bottoms[0] <= bottoms[1] ? 0 : 1
            let inset: CGFloat = column == 0 ? (counts[0] % 2 == 0 ? 0 : 28) : (counts[1] % 2 == 0 ? 0 : 10)
            let x = column == 0 ? min(inset, width - side) : max(0, width - side - inset)
            var y = max(bottoms[column], lastY)
            var moved = true
            while moved {
                moved = false
                for other in placed {
                    let reach = (side + other.width) / 2 + 8
                    let dx = (x + side / 2) - other.midX
                    guard abs(dx) < reach else { continue }
                    let needed = other.midY + (reach * reach - dx * dx).squareRoot() - side / 2
                    if y < needed - 0.5 { y = needed; moved = true }
                }
            }
            let frame = CGRect(x: x, y: y, width: side, height: side)
            placed.append(frame)
            bottoms[column] = frame.maxY + spacing
            counts[column] += 1
            lastY = y
        }
        return placed
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

/// Two loose columns (K00's rows of two): items alternate left and right in order, the right column dropped 40 points.
struct LooseColumns: Layout {
    var columnSpacing: CGFloat = 24
    var rowSpacing: CGFloat = 24
    var drop: CGFloat = 40

    private func frames(width: CGFloat, subviews: Subviews) -> [CGRect] {
        let column = (width - columnSpacing) / 2
        var bottoms: [CGFloat] = [0, drop]
        return subviews.enumerated().map { index, subview in
            let side = index % 2
            let height = subview.sizeThatFits(ProposedViewSize(width: column, height: nil)).height
            let frame = CGRect(x: side == 0 ? 0 : column + columnSpacing, y: bottoms[side], width: column, height: height)
            bottoms[side] = frame.maxY + rowSpacing
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
