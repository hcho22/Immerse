#if DEBUG
@preconcurrency import AVFoundation
import AVKit
import FilmDomain
import FilmPersistence
import FilmRuntime
import ImageIO
import Observation
import SwiftUI

/// Debug-only preview of each saved capture, for the captain's feedback on a Camera's look without finishing its roll
/// (the captain, 2026-10-21). While on, every photo of the 6×6 and the Disposable and every clip of the 16mm and the
/// Super 8 develops as soon as it is saved, rendered by Development's own code with the treatment Development will give it
/// (`PreviewDevelopment`), and shows on the shooting screen, and those Cameras' shooting screens say beside Done that the
/// switch is on (`DevelopAtOnceNotice`) beside Done in the one-line shooting header. Every capture develops, one at a time in the order they were saved (the captain,
/// 2026-10-21: "preview - every shot"): each preview takes the card from the one before as it finishes, and in a quick
/// burst the newest waits behind the ones before it. Nothing develops while the app is in the background; the capture
/// it stopped develops again on return. The roll stays sealed and develops as before; an Instant print
/// develops by itself and is left as it is. Previews live only in a disposable cache outside the Film store, which holds
/// no more than the preview shown and the one developing: a preview goes once nothing shows it, and every preview and
/// every capture still to develop goes when the roll develops, when its Film is deleted, when the switch is turned off
/// and at launch. The latest stays while the camera is closed and shows again when it opens. The whole type is compiled
/// out of Release, which therefore has no preview path or copy; `Scripts/verify-release-excludes-testing-unlock.sh`
/// checks the Release binary.
@MainActor @Observable
final class DevelopedPreviews {
    static let defaultsKey = "ImmerseDebugDevelopedPreview"
    static let label = "Develop at once - Debug build"
    /// Caches are never backed up and iOS may empty them; a preview is made again only by the next capture.
    static var cacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DebugDevelopedPreviews", isDirectory: true)
    }

    /// A saved capture to develop.
    struct Capture: Equatable {
        let filmID: UUID
        let sequenceNumber: Int
        let medium: CameraMedium
    }

    /// One capture's finished preview, on the card until a newer one finishes or it is closed.
    struct Preview: Identifiable, Equatable {
        enum State: Equatable {
            case ready(URL, thumbnail: UIImage?)
            case failed
        }
        let filmID: UUID
        let sequenceNumber: Int
        let medium: CameraMedium
        let state: State
        var id: String { "\(filmID)-\(sequenceNumber)" }

        var url: URL? { if case let .ready(url, _) = state { url } else { nil } }
    }

    /// The newest capture of a Film still to develop, and whether it is developing or waits behind earlier ones.
    struct Pending: Equatable {
        let capture: Capture
        let developing: Bool
    }

    private let root: URL
    private let defaults: UserDefaults?
    let directory: URL
    /// The latest finished preview, shown on its Film's shooting screen.
    private(set) var current: Preview?
    /// The preview open full size. Its file stays while it is open, though a newer preview takes the card.
    var inspected: Preview? {
        didSet { if oldValue?.id != inspected?.id { removeIfUnshown(oldValue) } }
    }
    /// Saved captures still to develop, in the order they were saved; the first is developing.
    private(set) var waiting: [Capture] = []
    @ObservationIgnored private var render: Task<URL, Error>?
    /// While the app is in the background nothing develops: iOS refuses an app's GPU work there, which is why the roll's
    /// Development is suspended there too.
    @ObservationIgnored private var suspended = false
    /// The newest capture of the Film the camera saves to that is already taken up or was there before it attached, so
    /// each capture saved after it develops once.
    @ObservationIgnored private var newestSeen: (filmID: UUID, sequenceNumber: Int)?

    var enabled: Bool {
        didSet {
            defaults?.set(enabled, forKey: Self.defaultsKey)
            if !enabled { clearAll() }
        }
    }

    /// Reads the persisted switch, which starts on in a Debug build. Without defaults the switch is in memory only and
    /// starts off, as directly constructed Journals in tests expect.
    init(root: URL, defaults: UserDefaults?, directory: URL = DevelopedPreviews.cacheDirectory) {
        self.root = root
        self.defaults = defaults
        self.directory = directory
        // `bool(forKey:)` also reads a `-ImmerseDebugDevelopedPreview NO` launch argument, as UI tests can pass.
        enabled = defaults.map { $0.object(forKey: Self.defaultsKey) == nil || $0.bool(forKey: Self.defaultsKey) } ?? false
    }

    /// Whether the switch changes `film`'s shooting screen: it is on, and the Film is not an Instant's, whose prints
    /// develop as they are saved.
    func applies(to film: Film) -> Bool { enabled && film.camera.revealRule != .instantPerExposure }

    /// The camera now saves to `film`: each capture it saves from here on develops, and none from before.
    func cameraAttached(to film: Film) {
        newestSeen = (film.id, film.captures.map(\.sequenceNumber).max() ?? 0)
    }

    /// Captures of `film` were saved: each saved since the newest seen develops, after every capture saved before it, so a
    /// save event that finds two new captures, as a camera finishing two saves at once can, develops both. Nothing develops
    /// where the switch does not apply. A failed preview shows a note and never touches the save.
    func captureSaved(_ film: Film) {
        let newest = film.captures.map(\.sequenceNumber).max() ?? 0
        // A Film the camera did not attach to here has only its newest capture to develop.
        let after = newestSeen.flatMap { $0.filmID == film.id ? $0.sequenceNumber : nil } ?? newest - 1
        newestSeen = (film.id, max(newest, after))
        guard applies(to: film) else { return }
        waiting += film.captures.filter { !$0.isDiscarded && $0.sequenceNumber > after }
            .sorted { $0.sequenceNumber < $1.sequenceNumber }
            .map { Capture(filmID: film.id, sequenceNumber: $0.sequenceNumber, medium: film.camera.medium) }
        developNext()
    }

    /// The newest capture of `filmID` still to develop, if any.
    func pending(for filmID: UUID) -> Pending? {
        guard let newest = waiting.last(where: { $0.filmID == filmID }) else { return nil }
        return Pending(capture: newest, developing: newest == waiting.first)
    }

    /// Closes the card's preview; the captures still to develop go on.
    func dismiss() {
        let shown = current
        current = nil
        removeIfUnshown(shown)
    }

    /// The app went to the background: the capture developing stops and stays first, to develop again from the start.
    func suspend() {
        suspended = true
        render?.cancel()
    }

    /// The app is active again: the captures still to develop go on in the order they were saved.
    func resume() {
        suspended = false
        developNext()
    }

    /// The roll develops or its Film is deleted: its previews go, with every capture of it still to develop.
    func clear(filmID: UUID) {
        if waiting.first?.filmID == filmID { stopRender() }
        waiting.removeAll { $0.filmID == filmID }
        let shown = current
        if current?.filmID == filmID { current = nil }
        if inspected?.filmID == filmID { inspected = nil }
        removeIfUnshown(shown)
        developNext()
    }

    /// The switch is off, or the app has launched: every preview and every capture still to develop goes, with anything
    /// an earlier run left.
    func clearAll() {
        stopRender()
        waiting = []
        current = nil
        inspected = nil
        try? FileManager.default.removeItemIfPresent(at: directory)
    }

    /// Develops the first capture waiting, unless one is developing or the app is in the background.
    private func developNext() {
        guard !suspended, render == nil, let next = waiting.first else { return }
        let (root, directory, filmID, sequence) = (self.root, self.directory, next.filmID, next.sequenceNumber)
        let render = Task.detached(priority: .utility) {
            try await PreviewDevelopment.render(root: root, filmID: filmID, sequenceNumber: sequence, directory: directory)
        }
        self.render = render
        Task { [weak self] in
            let result = await render.result
            let thumbnail = try? await Self.thumbnail(of: result.get(), medium: next.medium)
            guard let self, self.render == render else {
                // Cleared while it developed.
                if let url = try? result.get() { try? FileManager.default.removeItemIfPresent(at: url) }
                return
            }
            self.render = nil
            guard !render.isCancelled else {
                // Stopped by the background: the capture develops again.
                if let url = try? result.get() { try? FileManager.default.removeItemIfPresent(at: url) }
                self.developNext()
                return
            }
            self.waiting.removeFirst()
            let state: Preview.State = switch result {
            case let .success(url): .ready(url, thumbnail: thumbnail)
            case .failure: .failed
            }
            let shown = self.current
            self.current = Preview(filmID: filmID, sequenceNumber: sequence, medium: next.medium, state: state)
            self.removeIfUnshown(shown)
            self.developNext()
        }
    }

    private func stopRender() {
        render?.cancel()
        render = nil
    }

    /// Removes a preview's file once neither the card nor the full-size view shows it.
    private func removeIfUnshown(_ preview: Preview?) {
        guard let preview, let url = preview.url, preview.id != current?.id, preview.id != inspected?.id else { return }
        try? FileManager.default.removeItemIfPresent(at: url)
    }

    /// A small picture for the card: the photo's own thumbnail, or a clip's first frame.
    @concurrent nonisolated private static func thumbnail(of url: URL, medium: CameraMedium) async throws -> UIImage? {
        let side: CGFloat = 240
        if medium == .photo {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                      kCGImageSourceCreateThumbnailFromImageAlways: true,
                      kCGImageSourceCreateThumbnailWithTransform: true,
                      kCGImageSourceThumbnailMaxPixelSize: side
                  ] as CFDictionary) else { return nil }
            return UIImage(cgImage: image)
        }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: side, height: side)
        return UIImage(cgImage: try await generator.image(at: .zero).image)
    }
}

/// The preview on the shooting screen, over the viewfinder with its other notices: the latest developed picture and the
/// newest capture still to develop, marked as a Debug preview so a screenshot is never taken for the real thing. The
/// picture opens full size, and a button closes it.
struct DevelopedPreviewCard: View {
    /// How long the card reads when the iPhone is on its side, at least, so its lines do not wrap word by word.
    static let sidewaysLength: CGFloat = 300
    let preview: DevelopedPreviews.Preview?
    let pending: DevelopedPreviews.Pending?
    /// Whether the picture opens full size: not while a clip starts, records or saves, since the full-size player would
    /// take the iPhone's sound from the clip's microphone. The card then shows dimmed, and its close button still works.
    var opens = true
    let open: () -> Void
    let close: () -> Void

    var body: some View {
        // Within the viewfinder at every text size, as the zoom steps are; the picture's size follows the same cap.
        PreviewCardContent(preview: preview, pending: pending, opens: opens, open: open, close: close)
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}

private struct PreviewCardContent: View {
    let preview: DevelopedPreviews.Preview?
    let pending: DevelopedPreviews.Pending?
    let opens: Bool
    let open: () -> Void
    let close: () -> Void
    @ScaledMetric(relativeTo: .caption) private var side: CGFloat = 48
    /// The room the close button's glyph takes at the card's top corner, beside the text.
    @ScaledMetric(relativeTo: .footnote) private var closeRoom: CGFloat = 24

    var body: some View {
        // The close button sits over the card's top corner, so the text keeps the card's width.
        tappableContent
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Debug preview. \(status)")
            .accessibilityIdentifier("developed-preview")
            .overlay(alignment: .topTrailing) {
                if preview != nil {
                    Button("Close debug preview", systemImage: "xmark", action: close)
                        .labelStyle(.iconOnly).font(.footnote.weight(.semibold))
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                        .accessibilityIdentifier("developed-preview-close")
                }
            }
            .foregroundStyle(.white)
            .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
    }

    /// The picture and the lines, which open the preview full size once there is one to open, dimmed while it cannot
    /// open; with none to open they are no button, which would dim them.
    @ViewBuilder private var tappableContent: some View {
        if preview?.url != nil {
            Button(action: open) { content }.buttonStyle(.plain).disabled(!opens)
        } else {
            content
        }
    }

    private var content: some View {
        PreviewCardLayout(closeRoom: closeRoom) {
            picture.frame(width: side, height: side).clipShape(RoundedRectangle(cornerRadius: 6))
            Text("Debug preview").font(.caption.weight(.semibold))
            Text(status).font(.caption).foregroundStyle(.white.opacity(0.85))
        }
        .multilineTextAlignment(.leading)
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// What the finished preview is, then, on a line of its own, what the newest capture still to develop is doing.
    private var status: String {
        var lines: [String] = []
        if let preview {
            let capture = name(preview.medium, preview.sequenceNumber)
            switch preview.state {
            case .ready: lines.append("\(capture) developed. \(opens ? "Tap to view." : "Opens when the clip ends.")")
            case .failed: lines.append("\(capture) could not develop here. It is saved and develops with the roll.")
            }
        }
        if let pending {
            let capture = name(pending.capture.medium, pending.capture.sequenceNumber)
            lines.append(pending.developing ? "\(capture) developing." : "\(capture) waiting to develop.")
        }
        return lines.joined(separator: "\n")
    }

    private func name(_ medium: CameraMedium, _ sequenceNumber: Int) -> String {
        medium == .photo ? "Photo \(sequenceNumber)" : "Clip \(sequenceNumber)"
    }

    /// The developed picture, or while there is none the progress of the capture developing, or the failed one's mark.
    @ViewBuilder private var picture: some View {
        if case let .ready(_, thumbnail?) = preview?.state {
            Image(uiImage: thumbnail).resizable().scaledToFill()
        } else if preview?.url != nil {
            glyph("photo")
        } else if pending != nil {
            ProgressView().tint(.white).frame(maxWidth: .infinity, maxHeight: .infinity).background(.white.opacity(0.15))
        } else {
            glyph("exclamationmark.triangle")
        }
    }

    private func glyph(_ name: String) -> some View {
        Image(systemName: name).frame(maxWidth: .infinity, maxHeight: .infinity).background(.white.opacity(0.15))
    }
}

/// The card's picture, heading and line: the two lines beside the picture, clear of the close button, where the heading
/// fits there on one line, and below the picture across the card's width where it does not, as in the 6×6's viewfinder
/// at the largest text sizes on a small iPhone. One layout for both, so the card keeps its views as the text grows.
private struct PreviewCardLayout: Layout {
    var closeRoom: CGFloat
    var spacing: CGFloat = 10
    var lineSpacing: CGFloat = 2

    /// The width the lines take beside the picture, or nil where they go below it.
    private func besideWidth(_ subviews: Subviews, width: CGFloat) -> CGFloat? {
        let room = width - subviews[0].sizeThatFits(.unspecified).width - spacing - closeRoom
        return room >= subviews[1].sizeThatFits(.unspecified).width ? room : nil
    }

    private func linesHeight(_ subviews: Subviews, width: CGFloat) -> CGFloat {
        let proposal = ProposedViewSize(width: width, height: nil)
        return subviews[1].sizeThatFits(proposal).height + lineSpacing + subviews[2].sizeThatFits(proposal).height
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 3 else { return .zero }
        let picture = subviews[0].sizeThatFits(.unspecified)
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? 320
        if let lines = besideWidth(subviews, width: width) {
            return CGSize(width: width, height: max(picture.height, linesHeight(subviews, width: lines)))
        }
        return CGSize(width: width, height: picture.height + spacing + linesHeight(subviews, width: width))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 3 else { return }
        let picture = subviews[0].sizeThatFits(.unspecified)
        let x: CGFloat, width: CGFloat, top: CGFloat
        if let lines = besideWidth(subviews, width: bounds.width) {
            subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading, proposal: ProposedViewSize(picture))
            (x, width) = (bounds.minX + picture.width + spacing, lines)
            top = bounds.midY - linesHeight(subviews, width: lines) / 2
        } else {
            subviews[0].place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(picture))
            (x, width, top) = (bounds.minX, bounds.width, bounds.minY + picture.height + spacing)
        }
        let proposal = ProposedViewSize(width: width, height: nil)
        let heading = subviews[1].sizeThatFits(proposal)
        // Offered no height, so each text takes the height it measured (as `TurnedLayout` does).
        subviews[1].place(at: CGPoint(x: x, y: top), anchor: .topLeading, proposal: proposal)
        subviews[2].place(at: CGPoint(x: x, y: top + heading.height + lineSpacing), anchor: .topLeading, proposal: proposal)
    }
}

/// The preview at full size: the developed photo, or the Developed Clip playing on a loop.
struct DevelopedPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let preview: DevelopedPreviews.Preview
    @State private var image: UIImage?
    @State private var player: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?
    @State private var unavailable = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                    Color.black
                    if let image {
                        Image(uiImage: image).resizable().scaledToFit()
                            .accessibilityLabel("Developed photo \(preview.sequenceNumber)")
                    } else if let player {
                        VideoPlayer(player: player).accessibilityLabel("Developed clip \(preview.sequenceNumber)")
                    } else if unavailable {
                        Label("This preview is no longer here. Take another capture for a new one.",
                              systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.white).multilineTextAlignment(.center).padding()
                    } else { ProgressView().tint(.white) }
                }
                DevelopedPreviewNotice(medium: preview.medium).padding()
            }
            .navigationTitle("Debug preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }.labelStyle(.iconOnly).tint(.primaryAction)
                }
            }
        }
        .task(id: preview.id) {
            guard let url = preview.url, (try? FileManager.default.itemExists(at: url)) == true else {
                unavailable = true
                return
            }
            if preview.medium == .photo {
                image = await Task.detached { UIImage(contentsOfFile: url.path)?.preparingForDisplay() }.value
                unavailable = image == nil
            } else {
                MoviePlaybackAudio.prepare()
                let queue = AVQueuePlayer()
                looper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: url))
                player = queue
                queue.play()
            }
        }
        .onDisappear {
            if player != nil { MoviePlaybackAudio.finish() }
            player?.pause(); looper = nil; player = nil; image = nil
        }
    }
}

/// Says what a preview is, wherever one is shown in full, so a screenshot of it is never taken for the real thing.
struct DevelopedPreviewNotice: View {
    let medium: CameraMedium

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(DevelopedPreviews.label)
                Text(medium == .photo
                     ? "Developed now, as the roll's Development will develop it. The Film stays sealed and develops as usual. Turn off Develop at once in Settings to test the real experience."
                     : "Developed now, as the roll's Development will develop it, without the soundtrack, which only the developed Movie has. The Film stays sealed and develops as usual. Turn off Develop at once in Settings to test the real experience.")
                    .font(.footnote).fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: "hammer")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("developed-preview-notice")
    }
}

/// Says on the shooting screen that Develop at once is on, whenever it is on for that Camera, so a screenshot of a Camera
/// that previews its captures is never taken for the real thing. It sits beside Done in the shooting header (`CaptureDoneRow`).
struct DevelopAtOnceNotice: View {
    var body: some View {
        // Short enough to stay beside Done in the one-line header.
        HStack(spacing: 4) {
            Image(systemName: "hammer")
            Text("Develop at once")
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 6).padding(.vertical, 4)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 8))
        // The notice stays capped at xxLarge so it can share the header with the Camera name and count at accessibility sizes.
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Develop at once is on. Debug build.")
        .accessibilityIdentifier("develop-at-once-notice")
    }
}

/// The header's first line: Done against the leading edge and, where a second view is given, Develop at once's notice
/// at the far end where the two fit on one line, as they always do held upright, or under Done where they do not, as in
/// the header's shorter lines with the iPhone on its side, which lengthens the turned header across the screen but not
/// the height it reserves. Beside Done the notice is shorter than it, so the header, and the viewfinder under it, keep
/// their heights whether the switch is on or off. One layout for both, so Done keeps its view.
struct DoneRowLayout: Layout {
    var spacing: CGFloat = 8

    private struct Plan {
        var done: CGSize
        var notice: CGSize?
        var beside: Bool
        var width: CGFloat
    }

    private func plan(_ proposal: ProposedViewSize, _ subviews: Subviews) -> Plan? {
        guard let first = subviews.first else { return nil }
        let offered = proposal.width.flatMap { $0.isFinite ? $0 : nil }
        let done = first.sizeThatFits(ProposedViewSize(width: offered, height: nil))
        guard subviews.count > 1 else { return Plan(done: done, notice: nil, beside: true, width: offered ?? done.width) }
        let line = subviews[1].sizeThatFits(.unspecified)
        let width = offered ?? done.width + spacing + line.width
        if done.width + spacing + line.width <= width { return Plan(done: done, notice: line, beside: true, width: width) }
        return Plan(done: done, notice: subviews[1].sizeThatFits(ProposedViewSize(width: width, height: nil)), beside: false,
                    width: width)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let plan = plan(proposal, subviews) else { return .zero }
        guard let notice = plan.notice else { return CGSize(width: plan.width, height: plan.done.height) }
        let height = plan.beside ? max(plan.done.height, notice.height) : plan.done.height + spacing + notice.height
        return CGSize(width: plan.width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let plan = plan(ProposedViewSize(width: bounds.width, height: nil), subviews) else { return }
        guard plan.beside else {
            subviews[0].place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(plan.done))
            // Offered no height, so the text takes the height it measured (as `TurnedLayout` does).
            subviews[1].place(at: CGPoint(x: bounds.minX, y: bounds.minY + plan.done.height + spacing), anchor: .topLeading,
                              proposal: ProposedViewSize(width: plan.width, height: nil))
            return
        }
        subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading, proposal: ProposedViewSize(plan.done))
        if let notice = plan.notice {
            subviews[1].place(at: CGPoint(x: bounds.maxX, y: bounds.midY), anchor: .trailing, proposal: ProposedViewSize(notice))
        }
    }
}

/// The Debug-only switch in Settings, under the testing unlock.
struct DevelopedPreviewSection: View {
    @Bindable var previews: DevelopedPreviews

    var body: some View {
        Section {
            Toggle(DevelopedPreviews.label, isOn: $previews.enabled)
                .accessibilityIdentifier("developed-preview-switch")
        } footer: {
            Text("While on, each capture on every Camera but the Instant shows developed on the camera right away. The Film stays sealed and still develops when it is finished.")
        }
    }
}
#endif
