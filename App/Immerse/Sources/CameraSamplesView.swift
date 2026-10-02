import AVKit
import FilmDomain
import FilmPersistence
import MediaCatalog
import SwiftUI

struct CameraSamplesView: View {
    @Environment(JournalModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let camera: CameraPackage

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    if let catalog = model.mediaCatalog {
                        ForEach(catalog.assets(for: camera.id, purpose: .cameraSample)) { sample in
                            CatalogSampleView(catalog: catalog, sample: sample)
                        }
                    }
                }.padding()
            }
            .navigationTitle(camera.shortName)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    // iOS 26 fills an icon-only confirmation with the tint.
                    Button("Done", systemImage: "checkmark") { dismiss() }.labelStyle(.iconOnly).tint(.primaryAction)
                }
            }
        }
    }
}

private struct CatalogSampleView: View {
    let catalog: BundleMediaCatalog
    let sample: CatalogMediaAsset
    @State private var image: UIImage?
    @State private var player: AVPlayer?
    @State private var aspect = 4.0 / 3
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if let image { Image(uiImage: image).resizable().scaledToFit().accessibilityLabel(sample.title) }
                else if let player { VideoPlayer(player: player).aspectRatio(aspect, contentMode: .fit) }
                else if failed { ContentUnavailableView("Sample unavailable", systemImage: "photo.badge.exclamationmark") }
                else { ProgressView().frame(height: 180) }
            }
            Text(sample.title).font(.headline)
            if !sample.rights.attribution.isEmpty { Text(sample.rights.attribution).font(.caption) }
        }
        .task(id: sample.id) {
            do {
                let verified = try catalog.resolve(id: sample.id)
                if sample.kind == .photo {
                    _ = try VerifiedMedia.photo(at: verified.url)
                    guard let decoded = DisplayPhoto.image(try verified.data()) else { throw MediaCatalogError.incompatibleAsset }
                    guard !Task.isCancelled else { return }
                    image = decoded
                } else if sample.kind == .movie {
                    _ = try await VerifiedMedia.movie(at: verified.url)
                    let asset = AVURLAsset(url: verified.url)
                    guard let track = try await asset.loadTracks(withMediaType: .video).first else {
                        throw MediaCatalogError.incompatibleAsset
                    }
                    let size = try await track.load(.naturalSize)
                    let transform = try await track.load(.preferredTransform)
                    let displayed = CGRect(origin: .zero, size: size).applying(transform).standardized
                    guard displayed.width > 0, displayed.height > 0, !Task.isCancelled else { return }
                    aspect = displayed.width / displayed.height
                    player = AVPlayer(url: verified.url)
                } else { throw MediaCatalogError.incompatibleAsset }
            } catch { if !Task.isCancelled { failed = true } }
        }
        .onDisappear { player?.pause(); player?.replaceCurrentItem(with: nil); player = nil; image = nil }
    }
}
