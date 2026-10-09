@preconcurrency import AVFoundation
import CoreGraphics
@testable import FilmPersistence
import FilmDomain
import FilmRuntime
import Foundation
import ImageIO
import NativeAdapters
import RenderCore
import RenderFixtures
import XCTest

/// Film Stock end to end through the production processor (ADR 0014, PRD 2.1 slice 3): a black-and-white Film develops
/// monochrome masters, Developed Clips and Developed Movie, its prints take chemical toning, and what it saves to Photos
/// is what it developed. An earlier Film keeps developing in color.
final class FilmStockDevelopmentTests: XCTestCase {
    private var root: URL!
    private var fixtures: URL!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("FilmStockDevelopmentTests-\(UUID())")
        fixtures = root.appendingPathComponent("Fixtures")
        var settings = RenderFixtureSettings.defaultExperimental
        settings.movieWidth = 160; settings.movieHeight = 96; settings.movieDurationSeconds = 0.2
        _ = try await RenderFixtureGenerator.writeFixtures(outputDirectory: fixtures, settings: settings)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
    }

    private var photo: Data { get throws { try Data(contentsOf: fixtures.appendingPathComponent("synthetic-developed-photo.jpg")) } }
    private var clip: URL { fixtures.appendingPathComponent("synthetic-developed-movie.mov") }

    func testABlackAndWhiteSixBySixFilmDevelopsPrintsTonesAndExportsMonochrome() async throws {
        let repository = try FilmRepository(rootURL: root)
        let mono = try repository.createFilm(camera: CameraCatalog.mediumFormat6x6, title: "Harbour", filmStock: .blackAndWhite)
        let color = try repository.createFilm(camera: CameraCatalog.mediumFormat6x6, title: "Garden", filmStock: .color)
        for film in [mono, color] {
            for _ in 0..<2 { try repository.savePhotoCapture(filmID: film.id, sourceData: photo) }
            try repository.completeEarly(filmID: film.id)
        }
        let processor = try FilmProcessor(root: root)
        try await processor.develop(filmID: mono.id)
        try await processor.develop(filmID: color.id)
        let run = try XCTUnwrap(repository.developmentRun(filmID: mono.id))
        XCTAssertEqual(run.treatmentVersion, NativePhotoRenderer.treatmentVersion)

        for sequence in [1, 2] {
            let master = try Data(contentsOf: repository.revealedAsset(filmID: mono.id, sequenceNumber: sequence, kind: .master).url)
            XCTAssertLessThanOrEqual(try channelSpread(master), 2, "Black-and-white master \(sequence) is gray")
            let colorMaster = try Data(contentsOf: repository.revealedAsset(filmID: color.id, sequenceNumber: sequence, kind: .master).url)
            XCTAssertGreaterThan(try channelSpread(colorMaster), 40, "Color master \(sequence) keeps its color")
            let unedited = try await processor.photo(filmID: mono.id, sequence: sequence)
            XCTAssertEqual(unedited, master, "Unedited, the print is the master")
        }

        // The Darkroom: toning and contrast grades on black-and-white prints, never filtration; toning never on color.
        let toned = DarkroomRecipe(contrastGrade: 4, chemicalToning: ChemicalToning(chemistry: .sepia, amount: 0.8))
        let print = try await processor.saveRecipe(filmID: mono.id, sequence: 2, recipe: toned)
        XCTAssertGreaterThan(try channelSpread(print), 10, "A sepia-toned print is no longer neutral")
        do { _ = try await processor.saveRecipe(filmID: mono.id, sequence: 1, recipe: DarkroomRecipe(colorFiltration: ColorFiltration(yellow: 5)))
             XCTFail("Filtration is for color prints") } catch { XCTAssertEqual(error as? NativeRenderError, .invalidRecipe) }
        do { _ = try await processor.saveRecipe(filmID: color.id, sequence: 1, recipe: toned)
             XCTFail("Toning is for black-and-white prints") } catch { XCTAssertEqual(error as? NativeRenderError, .invalidRecipe) }

        // Save Developed to Photos writes the developed print: gray as developed, toned where the Darkroom toned it.
        let writer = CollectingWriter()
        let coordinator = PhotoExportCoordinator(authorizer: Authorized(), writer: writer)
        try await processor.export(filmID: mono.id, sequences: [1, 2], originals: false, coordinator: coordinator)
        let saved = await writer.saved
        XCTAssertEqual(saved.count, 2)
        XCTAssertLessThanOrEqual(try channelSpread(saved[0]), 2)
        XCTAssertEqual(saved[1], print)
    }

    func testABlackAndWhiteSixteenMillimeterFilmDevelopsAMonochromeMovieEndToEnd() async throws {
        let repository = try FilmRepository(rootURL: root)
        let reel = try repository.createFilm(camera: CameraCatalog.cinema16mm, title: "Reel", movieOrientation: .landscape,
                                             filmStock: .blackAndWhite)
        let seconds = try await VerifiedMedia.movie(at: clip).durationSeconds ?? 0
        for _ in 0..<2 {
            _ = try repository.saveMovieClip(filmID: reel.id, sourceData: Data(contentsOf: clip), durationSeconds: seconds, orientation: .landscape)
        }
        try repository.completeEarly(filmID: reel.id)
        let processor = try FilmProcessor(root: root)
        try await processor.develop(filmID: reel.id)
        XCTAssertEqual(try repository.film(id: reel.id).developmentState, .developed)

        for sequence in [1, 2] {
            let developed = try repository.revealedAsset(filmID: reel.id, sequenceNumber: sequence, kind: .clip).url
            try await assertEveryFrameIsGray(developed, "Developed Clip \(sequence)")
        }
        let movie = try repository.revealedAsset(filmID: reel.id, sequenceNumber: 0, kind: .movie).url
        try await assertEveryFrameIsGray(movie, "Developed Movie")

        // Discarding a clip reassembles from the surviving black-and-white clip, never redeveloping it in color.
        try await processor.discard(filmID: reel.id, sequence: 1)
        let rebuilt = try repository.revealedAsset(filmID: reel.id, sequenceNumber: 0, kind: .movie).url
        try await assertEveryFrameIsGray(rebuilt, "Reassembled Developed Movie")

        let writer = CollectingWriter()
        try await processor.export(filmID: reel.id, sequences: [2], originals: false,
                                   coordinator: PhotoExportCoordinator(authorizer: Authorized(), writer: writer))
        let exported = root.appendingPathComponent("exported.mov")
        let savedMovies = await writer.saved
        try XCTUnwrap(savedMovies.first).write(to: exported)
        try await assertEveryFrameIsGray(exported, "Saved Developed Movie")
    }

    /// A 6×6 Film loaded before Film Stock existed, developing when the app was updated: its captures were assigned the
    /// version 1 treatment, which this build still renders, so it finishes, in color, with no Film Stock.
    func testAnEarlierFilmDevelopingWhenTheAppUpdatedFinishesInColor() async throws {
        let repository = try FilmRepository(rootURL: root)
        let film = try repository.createFilm(camera: CameraCatalog.mediumFormat6x6, title: "Earlier", filmStock: .color)
        // Store it as the previous build did: no Film Stock in its record.
        let stored = try XCTUnwrap(repository.database.filmData(id: film.id.uuidString))
        var record = try XCTUnwrap(JSONSerialization.jsonObject(with: stored) as? [String: Any])
        record["filmStock"] = nil
        try repository.database.upsertFilm(id: film.id.uuidString, data: JSONSerialization.data(withJSONObject: record))
        XCTAssertNil(try repository.film(id: film.id).filmStock)
        for _ in 0..<2 { try repository.savePhotoCapture(filmID: film.id, sourceData: photo) }
        try repository.completeEarly(filmID: film.id)
        // Development began under version 1, recording the color print process the previous build stored.
        _ = try repository.beginDevelopment(filmID: film.id)
        let run = try XCTUnwrap(repository.database.value(filmID: film.id, key: "development"))
        let earlier = String(decoding: run, as: UTF8.self)
            .replacingOccurrences(of: NativePhotoRenderer.treatmentVersion, with: "film-look-1-provisional")
            .replacingOccurrences(of: "\"isComplete\":false", with: "\"isComplete\":false,\"printProcess\":\"color\"")
        try repository.database.setValue(filmID: film.id, key: "development", data: Data(earlier.utf8))

        try await FilmProcessor(root: root).develop(filmID: film.id)
        let finished = try repository.film(id: film.id)
        XCTAssertEqual(finished.developmentState, .developed)
        XCTAssertNil(finished.filmStock)
        XCTAssertEqual(try repository.developmentRun(filmID: film.id)?.treatmentVersion, "film-look-1-provisional")
        let master = try Data(contentsOf: repository.revealedAsset(filmID: film.id, sequenceNumber: 1, kind: .master).url)
        XCTAssertEqual(master, try NativePhotoRenderer.develop(source: fixtures.appendingPathComponent("synthetic-developed-photo.jpg"),
            camera: CameraCatalog.mediumFormat6x6, seed: XCTUnwrap(repository.developmentRun(filmID: film.id)?.assignments[1]?.seed)),
            "The color master, byte for byte")
        XCTAssertEqual(try repository.photoPrintProcess(filmID: film.id), .color)
    }

    private func channelSpread(_ data: Data) throws -> Int {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return spread(bytes, red: 0, blue: 2)
    }

    /// The largest difference between two channels of any pixel; 0 for perfectly neutral gray.
    private func spread(_ bytes: [UInt8], red: Int, blue: Int) -> Int {
        bytes.withUnsafeBufferPointer { pixels in
            var largest = 0
            for index in stride(from: 0, to: pixels.count, by: 4) {
                let r = Int(pixels[index + red]), g = Int(pixels[index + 1]), b = Int(pixels[index + blue])
                largest = max(largest, max(r, g, b) - min(r, g, b))
            }
            return largest
        }
    }

    private func assertEveryFrameIsGray(_ url: URL, _ name: String, file: StaticString = #filePath, line: UInt = #line) async throws {
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let track = try XCTUnwrap(tracks.first, file: file, line: line)
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        reader.add(output)
        XCTAssertTrue(reader.startReading(), file: file, line: line)
        var frames = 0
        while let sample = output.copyNextSampleBuffer() {
            let buffer = try XCTUnwrap(CMSampleBufferGetImageBuffer(sample), file: file, line: line)
            CVPixelBufferLockBaseAddress(buffer, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
            let base = try XCTUnwrap(CVPixelBufferGetBaseAddress(buffer), file: file, line: line)
            let width = CVPixelBufferGetWidth(buffer), stride = CVPixelBufferGetBytesPerRow(buffer)
            var bytes = [UInt8]()
            bytes.reserveCapacity(width * 4 * CVPixelBufferGetHeight(buffer))
            for row in 0..<CVPixelBufferGetHeight(buffer) {
                bytes.append(contentsOf: UnsafeBufferPointer(start: base.advanced(by: row * stride).assumingMemoryBound(to: UInt8.self), count: width * 4))
            }
            XCTAssertLessThanOrEqual(spread(bytes, red: 2, blue: 0), 4, "\(name) frame \(frames) is gray", file: file, line: line)
            frames += 1
        }
        XCTAssertEqual(reader.status, .completed, file: file, line: line)
        XCTAssertGreaterThan(frames, 1, "\(name) has frames", file: file, line: line)
    }
}

private struct Authorized: PhotoLibraryAuthorizing {
    func authorizationStatus(for accessLevel: PhotoLibraryAccessLevel) -> PhotoLibraryAuthorizationStatus { .authorized }
    func requestAuthorization(for accessLevel: PhotoLibraryAccessLevel) async -> PhotoLibraryAuthorizationStatus { .authorized }
}

private actor CollectingWriter: PhotoLibraryWriting {
    var saved: [Data] = []
    func write(_ request: PhotoExportRequest) async throws -> PhotoExportReceipt {
        saved.append(try Data(contentsOf: request.fileURL))
        return PhotoExportReceipt(localIdentifier: "synthetic-\(saved.count)")
    }
}
