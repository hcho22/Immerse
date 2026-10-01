import FilmDomain
import RenderFixtures
import SwiftUI

@main
struct WorkflowHarnessApp: App {
    @State private var model: JournalModel?
    @State private var failure: String?

    var body: some Scene {
        WindowGroup {
            Group {
                if let model { JournalView().environment(model) }
                else if let failure { Text(failure).accessibilityIdentifier("fixture-failed") }
                else { ProgressView("Preparing private fixtures").task { await prepare() } }
            }.tint(.accentColor)
        }
    }

    @MainActor private func prepare() async {
        do {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("Workflow-\(UUID())")
            let fixtures = root.appendingPathComponent("Fixtures")
            var settings = RenderFixtureSettings.defaultExperimental
            settings.movieWidth = 160; settings.movieHeight = 120; settings.movieDurationSeconds = 0.16
            let manifest = try await RenderFixtureGenerator.writeFixtures(outputDirectory: fixtures, settings: settings)
            let model = try JournalModel(root: root)
            let movie = ProcessInfo.processInfo.arguments.contains("--movie")
            let instant = ProcessInfo.processInfo.arguments.contains("--instant")
            let camera = movie ? CameraCatalog.cinema16mm : (instant ? CameraCatalog.instant1970s : CameraCatalog.disposable1990s)
            let film = try model.repository.createFilm(camera: camera, title: "Private synthetic Film",
                movieOrientation: movie ? .portrait : nil, access: .subscription)
            if movie {
                let data = try Data(contentsOf: fixtures.appendingPathComponent("synthetic-developed-movie.mov"))
                for _ in 0..<2 {
                    try model.repository.saveMovieClip(filmID: film.id, sourceData: data,
                        durationSeconds: manifest.movie.durationSeconds, orientation: .landscape)
                }
                try model.repository.completeEarly(filmID: film.id)
                try await model.develop(film.id)
            } else {
                let data = try Data(contentsOf: fixtures.appendingPathComponent("synthetic-developed-photo.jpg"))
                for _ in 0..<2 { try model.repository.savePhotoCapture(filmID: film.id, sourceData: data) }
                if instant { try await model.develop(film.id) }
            }
            model.refresh()
            self.model = model
        } catch { failure = error.localizedDescription }
    }
}
