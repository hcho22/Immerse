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
/// Super 8 shows developed on the shooting screen as soon as it is saved, rendered by Development's own code with the
/// treatment Development will give it (`PreviewDevelopment`). The roll stays sealed and develops as before; an Instant
/// print develops by itself and is left as it is. Previews live only in a disposable cache outside the Film store and
/// are removed when they are closed or replaced, when the roll develops, when its Film is deleted, when the switch is
/// turned off and at launch; the latest stays while the camera is closed and shows again when it opens. The whole type is compiled out of Release, which therefore has no preview path or copy;
/// `Scripts/verify-release-excludes-testing-unlock.sh` checks the Release binary.
@MainActor @Observable
final class DevelopedPreviews {
    static let defaultsKey = "ImmerseDebugDevelopedPreview"
    static let label = "Develop at once - Debug build"
    /// Caches are never backed up and iOS may empty them; a preview is made again only by the next capture.
    static var cacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DebugDevelopedPreviews", isDirectory: true)
    }

    /// One saved capture's preview, from its save until it is closed.
    struct Preview: Identifiable, Equatable {
        enum State: Equatable {
            case developing
            case ready(URL, thumbnail: UIImage?)
            case failed
        }
        let filmID: UUID
        let sequenceNumber: Int
        let medium: CameraMedium
        var state: State
        var id: String { "\(filmID)-\(sequenceNumber)" }

        var url: URL? { if case let .ready(url, _) = state { url } else { nil } }
    }

    private let root: URL
    private let defaults: UserDefaults?
    let directory: URL
    /// The latest saved capture's preview, shown on its Film's shooting screen.
    private(set) var current: Preview?
    @ObservationIgnored private var job: Task<URL, Error>?

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

    /// A capture of `film` was saved: its newest capture develops now, replacing the preview before it. Nothing happens
    /// while the switch is off or for an Instant, whose prints develop as they are saved. A failed preview shows a note
    /// and never touches the save.
    func captureSaved(_ film: Film) {
        guard enabled, film.camera.revealRule != .instantPerExposure,
              let newest = film.captures.last(where: { !$0.isDiscarded }) else { return }
        // Recovery reports each staged save it finishes; the newest is developed once.
        if let current, current.filmID == film.id, current.sequenceNumber == newest.sequenceNumber { return }
        clearCurrent()
        let preview = Preview(filmID: film.id, sequenceNumber: newest.sequenceNumber, medium: film.camera.medium,
                              state: .developing)
        current = preview
        let (root, directory, filmID, sequence) = (self.root, self.directory, film.id, newest.sequenceNumber)
        let job = Task.detached(priority: .utility) {
            try await PreviewDevelopment.render(root: root, filmID: filmID, sequenceNumber: sequence, directory: directory)
        }
        self.job = job
        Task { [weak self] in
            let result = await job.result
            let thumbnail = try? await Self.thumbnail(of: result.get(), medium: preview.medium)
            guard let self, self.current?.id == preview.id, self.job == job else {
                // Closed or replaced while it developed.
                if let url = try? result.get() { try? FileManager.default.removeItemIfPresent(at: url) }
                return
            }
            self.job = nil
            switch result {
            case let .success(url): self.current?.state = .ready(url, thumbnail: thumbnail)
            case .failure: self.current?.state = .failed
            }
        }
    }

    /// Closes the preview and removes its file.
    func dismiss() { clearCurrent() }

    /// The roll develops or its Film is deleted: its preview goes.
    func clear(filmID: UUID) {
        guard current?.filmID == filmID else { return }
        clearCurrent()
    }

    /// The switch is off, or the app has launched: every preview goes, with anything an earlier run left.
    func clearAll() {
        clearCurrent()
        try? FileManager.default.removeItemIfPresent(at: directory)
    }

    private func clearCurrent() {
        job?.cancel()
        job = nil
        if let url = current?.url { try? FileManager.default.removeItemIfPresent(at: url) }
        current = nil
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

/// The preview on the shooting screen, over the viewfinder with its other notices: the developed picture, marked as a
/// Debug preview so a screenshot is never taken for the real thing, opening full size, with a button to close it.
struct DevelopedPreviewCard: View {
    /// How long the card reads when the iPhone is on its side, at least, so its lines do not wrap word by word.
    static let sidewaysLength: CGFloat = 300
    let preview: DevelopedPreviews.Preview
    let open: () -> Void
    let close: () -> Void

    var body: some View {
        // Within the viewfinder at every text size, as the zoom steps are; the picture's size follows the same cap.
        PreviewCardContent(preview: preview, open: open, close: close).dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}

private struct PreviewCardContent: View {
    let preview: DevelopedPreviews.Preview
    let open: () -> Void
    let close: () -> Void
    @ScaledMetric(relativeTo: .caption) private var side: CGFloat = 48
    /// The room the close button's glyph takes at the card's top corner, beside the text.
    @ScaledMetric(relativeTo: .footnote) private var closeRoom: CGFloat = 24

    var body: some View {
        // The close button sits over the card's top corner, so the text keeps the card's width.
        Button(action: open) {
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
        .buttonStyle(.plain)
        .disabled(preview.url == nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Debug preview. \(status)")
        .accessibilityIdentifier("developed-preview")
        .overlay(alignment: .topTrailing) {
            Button("Close debug preview", systemImage: "xmark", action: close)
                .labelStyle(.iconOnly).font(.footnote.weight(.semibold))
                .frame(width: 44, height: 44).contentShape(Rectangle())
                .accessibilityIdentifier("developed-preview-close")
        }
        .foregroundStyle(.white)
        .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
    }

    private var status: String {
        let capture = preview.medium == .photo ? "Photo \(preview.sequenceNumber)" : "Clip \(preview.sequenceNumber)"
        switch preview.state {
        case .developing: return "\(capture) developing"
        case .ready: return "\(capture) developed. Tap to view."
        case .failed: return "\(capture) could not develop here. It is saved and develops with the roll."
        }
    }

    @ViewBuilder private var picture: some View {
        switch preview.state {
        case .developing: ProgressView().tint(.white).frame(maxWidth: .infinity, maxHeight: .infinity).background(.white.opacity(0.15))
        case let .ready(_, thumbnail?): Image(uiImage: thumbnail).resizable().scaledToFill()
        case .ready, .failed:
            Image(systemName: preview.state == .failed ? "exclamationmark.triangle" : "photo")
                .frame(maxWidth: .infinity, maxHeight: .infinity).background(.white.opacity(0.15))
        }
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
                let queue = AVQueuePlayer()
                looper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: url))
                player = queue
                queue.play()
            }
        }
        .onDisappear { player?.pause(); looper = nil; player = nil; image = nil }
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
