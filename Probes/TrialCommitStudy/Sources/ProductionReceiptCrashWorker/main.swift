import Darwin
import EntitlementCore
import FilmDomain
import FilmPersistence
import FilmRuntime
import Foundation
import NativeAdapters
import ProductionReceiptHarness

@main struct ProductionReceiptCrashWorker {
    static func main() async throws {
        let args = CommandLine.arguments
        guard args.count == 6, let camera = CameraCatalog.all.first(where: { $0.id.rawValue == args[4] }) else { _exit(64) }
        let root = URL(fileURLWithPath: args[1]), source = URL(fileURLWithPath: args[3])
        let calls = FileKeychainCalls(url: URL(fileURLWithPath: args[2]))
        let owner = try TrialCoordinator(root: root, store: KeychainDeviceTrialStore(calls: calls), checkpoint: {
            if String(describing: $0) == args[5] { _exit(77) }
        })
        let film = try await owner.start(camera: camera, title: "Production process-exit fixture",
            orientation: camera.medium == .movie ? .portrait : nil, filmStock: camera.defaultFilmStock)
        let repository = try FilmRepository(rootURL: root)
        let files = try CapturedMediaFiles(directory: repository.captureStagingDirectory(filmID: film.id))
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000789")!
        try files.prepare(PendingCaptureRecord(id: id, mediaKind: camera.medium == .photo ? .photo : .movie,
            createdAt: Date(timeIntervalSince1970: 1_790_870_000),
            orientation: camera.medium == .movie ? .landscape : nil, remainingFrames: film.remainingMovieFrames))
        let event: CaptureSaveEvent
        if camera.medium == .photo { event = .photoSaved(try files.savePhoto(Data(contentsOf: source), id: id)) }
        else {
            try FileManager.default.copyItem(at: source, to: files.movieDestination(id: id))
            event = try await files.movieSavedEvent(id: id, orientation: .landscape, remainingFrames: film.remainingMovieFrames!)
        }
        let receiver = try await owner.receiver(filmID: film.id)
        try await receiver.commit(event)
        _exit(65)
    }
}
