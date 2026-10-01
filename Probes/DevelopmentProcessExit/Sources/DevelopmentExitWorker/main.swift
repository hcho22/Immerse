import Darwin
import DevelopmentExitEvidence
import FilmDomain
import FilmPersistence
import FilmRuntime
import Foundation

@main struct DevelopmentExitWorker {
    static func main() async throws {
        let args = CommandLine.arguments
        guard args.count == 6, let id = UUID(uuidString: args[2]),
              let boundary = ExitBoundary(rawValue: args[3]), let sequence = Int(args[4]),
              ["develop", "discardFirst"].contains(args[5]) else { _exit(64) }
        let directory = URL(fileURLWithPath: args[1], isDirectory: true)
        let root = directory.appendingPathComponent("App")
        let film = try FilmRepository(rootURL: root).film(id: id)
        let target = boundary.stage(camera: film.camera.id, sequence: sequence)
        let processor = try FilmProcessor(root: root, developmentObserver: { observedID, stage in
            guard observedID == id, stage == target else { return }
            let snapshot = try await DevelopmentExitSnapshot.read(root: root, filmID: id)
            try snapshot.persist(to: directory.appendingPathComponent("at-exit.json"))
            _exit(81)
        })
        if args[5] == "discardFirst" { try await processor.discard(filmID: id, sequence: 1) }
        else { try await processor.develop(filmID: id) }
        // A missed observer boundary is a failed experiment, not successful recovery.
        _exit(82)
    }
}
