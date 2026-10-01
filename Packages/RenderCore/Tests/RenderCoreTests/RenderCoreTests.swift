import FilmDomain
@testable import RenderCore
import XCTest

final class RenderCoreTests: XCTestCase {
    func testTreatmentAssignmentIsStableAcrossResumeAndNeverRerollsCompletedWork() throws {
        var film = try Film(camera: CameraCatalog.disposable1990s, title: "Disposable - Roll #01")
        _ = try film.recordSavedPhoto()
        _ = try film.recordSavedPhoto()
        try film.completeEarly()

        var run = DevelopmentRun(filmID: film.id)
        try run.assignMissingTreatments(for: film)
        let firstAssignments = run.assignments
        try run.markRendered(sequenceNumber: 1, in: film)

        var resumed = run.resumed()
        try resumed.assignMissingTreatments(for: film)
        try resumed.markRendered(sequenceNumber: 2, in: film)

        XCTAssertEqual(resumed.assignments, firstAssignments)
        XCTAssertEqual(resumed.completedSequences, [1, 2])
        XCTAssertTrue(resumed.isComplete)
    }

    func testDevelopmentRunRejectsEmptyFilm() throws {
        let film = try Film(camera: CameraCatalog.disposable1990s, title: "Disposable - Roll #01")
        var run = DevelopmentRun(filmID: film.id)

        XCTAssertThrowsError(try run.assignMissingTreatments(for: film)) { error in
            XCTAssertEqual(error as? DevelopmentRunError, .emptyFilm)
        }
    }

    func testTreatmentAssignmentUsesPinnedStableSeed() throws {
        let filmID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        var film = try Film(id: filmID, camera: CameraCatalog.disposable1990s, title: "Disposable - Roll #01")
        for _ in 1...7 {
            _ = try film.recordSavedPhoto()
        }

        var run = DevelopmentRun(filmID: film.id)
        try run.assignMissingTreatments(for: film)

        XCTAssertEqual(run.assignments[7]?.seed, 0xdfa3c52769cb8401)
    }

    func testMovieAssemblyUsesSurvivingDevelopedClipOrderAndDetectsEmptyMovie() throws {
        var film = try Film(
            camera: CameraCatalog.super8HomeMovie,
            title: "Super 8 - Roll #01",
            movieOrientation: .landscape
        )
        _ = try film.recordSavedMovieClip(durationSeconds: 20, orientation: .landscape)
        _ = try film.recordSavedMovieClip(durationSeconds: 35, orientation: .portrait)
        _ = try film.recordSavedMovieClip(durationSeconds: 10, orientation: .landscape)
        try film.completeEarly()
        try film.startDevelopment()
        try film.finishDevelopment()

        try film.discardRevealedCapture(sequenceNumber: 2)
        var assembly = MovieAssemblyPlan(film: film)

        XCTAssertEqual(assembly.clipSequenceNumbers, [1, 3])
        XCTAssertTrue(assembly.hasPlayback)

        try film.discardRevealedCapture(sequenceNumber: 1)
        try film.discardRevealedCapture(sequenceNumber: 3)
        assembly = MovieAssemblyPlan(film: film)

        XCTAssertEqual(assembly.clipSequenceNumbers, [])
        XCTAssertFalse(assembly.hasPlayback)
    }

    func testDarkroomResetReturnsExactOriginalRecipe() {
        var recipe = DarkroomRecipe(
            printExposureStops: 1.25,
            contrastGrade: 4,
            colorFiltration: ColorFiltration(cyan: 0, magenta: 12, yellow: -4),
            crop: Crop(x: 0.1, y: 0.1, width: 0.8, height: 0.7),
            dodgeBurnMasks: [
                LocalMask(
                    kind: .burn,
                    points: [MaskPoint(x: 0.2, y: 0.3), MaskPoint(x: 0.4, y: 0.5)],
                    exposureStops: 0.5
                )
            ]
        )

        recipe.resetToOriginal()

        XCTAssertEqual(recipe, .original)
    }
}
