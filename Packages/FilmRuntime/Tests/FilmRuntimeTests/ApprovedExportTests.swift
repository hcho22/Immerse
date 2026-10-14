@preconcurrency import AVFoundation
import CoreGraphics
import FilmDomain
import FilmPersistence
import FilmRuntime
import Foundation
import ImageIO
import NativeAdapters
import RenderCore
import RenderFixtures
import UniformTypeIdentifiers
import XCTest

/// What Save Developed to Photos writes, read back from the file handed to Photos, against the sizes and formats the
/// captain approved on 2026-10-13 (DEC-04): JPEG photos, the Disposable at no more than 12,000,000 pixels in its
/// borderless 3:2 shape and the 6×6 at 3072 x 3072; Movies as H.264 in a `.mov` at 1920 x 1440, or 1440 x 1920 for a
/// portrait Movie, the Super 8 at 18 frames a second and the 16mm at 24, silent. An Instant print is saved exactly as
/// it was developed, 2282 x 2774, the 2048 x 2048 picture on its white card, with no resampling (his answer the same
/// day: "instant export size: A").
final class ApprovedExportTests: XCTestCase {
    private var root: URL!

    override func setUp() {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("ApprovedExportTests-\(UUID())")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
    }

    func testADisposableExportIsAJPEGOfAtMostTwelveMillionPixelsInItsThreeByTwoShape() async throws {
        // The phone's 12 megapixel 4:3 capture, upright and turned, and a capture larger than the limit.
        for (width, height, expected) in [(4032, 3024, (4032, 2688)), (3024, 4032, (2688, 4032)), (6000, 4500, (4242, 2828))] {
            let exported = try await exportedPhotos(camera: CameraCatalog.disposable1990s, sourceWidth: width, sourceHeight: height)
            XCTAssertEqual(exported.count, 2)
            for file in exported {
                let photo = try ExportedPhoto(file)
                XCTAssertEqual(photo.type, UTType.jpeg.identifier, "\(width)x\(height)")
                XCTAssertEqual([photo.width, photo.height], [expected.0, expected.1], "\(width)x\(height)")
                XCTAssertLessThanOrEqual(photo.width * photo.height, 12_000_000, "\(width)x\(height)")
                XCTAssertEqual(max(photo.width, photo.height) * 2, min(photo.width, photo.height) * 3, "\(width)x\(height) is 3:2")
                XCTAssertEqual(photo.colorSpace, CGColorSpace.sRGB as String, "\(width)x\(height)")
            }
        }
    }

    func testASixBySixExportIsAJPEGOf3072By3072OnEitherFilmStock() async throws {
        for stock in [FilmStock.blackAndWhite, .color] {
            if stock == .color, !NativePhotoRenderer.readsFilmTables { continue }
            let exported = try await exportedPhotos(camera: CameraCatalog.mediumFormat6x6, filmStock: stock, sourceWidth: 1600, sourceHeight: 1200)
            XCTAssertEqual(exported.count, 2)
            for file in exported {
                let photo = try ExportedPhoto(file)
                XCTAssertEqual(photo.type, UTType.jpeg.identifier, "\(stock)")
                XCTAssertEqual([photo.width, photo.height], [3072, 3072], "\(stock)")
                XCTAssertEqual(photo.colorSpace, CGColorSpace.sRGB as String, "\(stock)")
            }
        }
    }

    /// An Instant print is saved exactly as it was developed (DEC-04, the captain, 2026-10-13): a JPEG of 2282 x 2774,
    /// the 2048 x 2048 picture on its white card. Unedited, the file handed to Photos is the developed print byte for
    /// byte, so nothing is resampled or encoded again; an edited print keeps the size.
    func testAnInstantExportIsTheDevelopedPrintByteForByteAt2282By2774() async throws {
        XCTAssertEqual([InstantPrintCard.width, InstantPrintCard.height], [2282, 2774])
        XCTAssertEqual(InstantPrintCard.pictureSide, 2048)
        // A phone's capture, larger than the print, and a smaller one: neither changes the print's size.
        for (width, height) in [(4032, 3024), (1600, 1200)] {
            let (repository, film, processor) = try await developedPhotos(camera: CameraCatalog.instant1970s, filmStock: nil,
                                                                        sourceWidth: width, sourceHeight: height, completesEarly: false)
            let exported = try await export(processor, repository, film)
            XCTAssertEqual(exported.count, 2)
            for (index, file) in exported.enumerated() {
                let photo = try ExportedPhoto(file)
                XCTAssertEqual(photo.type, UTType.jpeg.identifier)
                XCTAssertEqual([photo.width, photo.height], [2282, 2774], "\(width)x\(height)")
                XCTAssertEqual(photo.colorSpace, CGColorSpace.sRGB as String)
                let master = try repository.revealedAsset(filmID: film.id, sequenceNumber: index + 1, kind: .master)
                XCTAssertEqual(try Data(contentsOf: file), try Data(contentsOf: master.url),
                               "\(width)x\(height): print \(index + 1) is saved as developed, byte for byte")
            }
            // An edit prints the picture again and keeps the card and the size.
            let edited = try await processor.saveRecipe(filmID: film.id, sequence: 1, recipe: DarkroomRecipe(printExposureStops: -3, contrastGrade: 5))
            let again = try await export(processor, repository, film)
            XCTAssertEqual(try Data(contentsOf: again[0]), edited)
            let print = try ExportedPhoto(again[0])
            XCTAssertEqual([print.width, print.height], [2282, 2774])
            let master = try repository.revealedAsset(filmID: film.id, sequenceNumber: 2, kind: .master)
            XCTAssertEqual(try Data(contentsOf: again[1]), try Data(contentsOf: master.url), "The other print is untouched")
        }
    }

    /// A Darkroom edit is saved in the same format, and only a crop changes its size.
    func testAnEditedPrintExportsInTheSameFormatAndSize() async throws {
        let (repository, film, processor) = try await developedPhotos(camera: CameraCatalog.disposable1990s, filmStock: nil,
                                                                    sourceWidth: 4032, sourceHeight: 3024, completesEarly: true)
        _ = try await processor.saveRecipe(filmID: film.id, sequence: 1, recipe: DarkroomRecipe(
            printExposureStops: 3, contrastGrade: 5, colorFiltration: ColorFiltration(cyan: 30, magenta: -30, yellow: 30),
            dodgeBurnMasks: [LocalMask(kind: .burn, points: [MaskPoint(x: 0.5, y: 0.5)], exposureStops: 3)]))
        _ = try await processor.saveRecipe(filmID: film.id, sequence: 2, recipe: DarkroomRecipe(
            printExposureStops: -3, crop: Crop(x: 0.25, y: 0.25, width: 0.5, height: 0.5)))
        let exported = try await export(processor, repository, film)
        let edited = try ExportedPhoto(exported[0]), cropped = try ExportedPhoto(exported[1])
        XCTAssertEqual([edited.type, cropped.type], [UTType.jpeg.identifier, UTType.jpeg.identifier])
        XCTAssertEqual([edited.width, edited.height], [4032, 2688])
        XCTAssertEqual([cropped.width, cropped.height], [2016, 1344])
        XCTAssertEqual([edited.colorSpace, cropped.colorSpace], [CGColorSpace.sRGB as String, CGColorSpace.sRGB as String])
    }

    func testAMovieExportIsSilentH264InAMovAtTheApprovedSizeAndTheCamerasFrameRate() async throws {
        let fixtures = root.appendingPathComponent("Fixtures")
        var settings = RenderFixtureSettings.defaultExperimental
        settings.movieWidth = 160; settings.movieHeight = 120; settings.movieDurationSeconds = 0.5
        let manifest = try await RenderFixtureGenerator.writeFixtures(outputDirectory: fixtures, settings: settings)
        let clip = try Data(contentsOf: fixtures.appendingPathComponent("synthetic-developed-movie.mov"))
        // The 16mm's black-and-white Film Stock develops on every renderer; its color one needs the table reader.
        let cameras: [(CameraPackage, FilmStock?, Int)] = [
            (CameraCatalog.super8HomeMovie, nil, 18), (CameraCatalog.cinema16mm, .blackAndWhite, 24)
        ] + (NativePhotoRenderer.readsFilmTables ? [(CameraCatalog.cinema16mm, .color, 24)] : [])
        for (camera, stock, framesPerSecond) in cameras {
            for (orientation, size) in [(MovieOrientation.landscape, (1920, 1440)), (.portrait, (1440, 1920))] {
                let name = "\(camera.id) \(String(describing: stock)) \(orientation)"
                let home = root.appendingPathComponent(UUID().uuidString)
                let repository = try FilmRepository(rootURL: home)
                let film = try repository.createFilm(camera: camera, title: "Reel", movieOrientation: orientation, filmStock: stock)
                // One clip in the Movie's orientation and one turned the other way, which is fitted with borders.
                for clipOrientation in [ClipOrientation.landscape, .portrait] {
                    try repository.saveMovieClip(filmID: film.id, sourceData: clip, durationSeconds: manifest.movie.durationSeconds,
                                                 orientation: clipOrientation)
                }
                try repository.completeEarly(filmID: film.id)
                let processor = try FilmProcessor(root: home)
                try await processor.develop(filmID: film.id)
                let exported = try await export(processor, repository, film)
                XCTAssertEqual(exported.count, 1, "\(name): one Developed Movie")
                XCTAssertEqual(exported[0].pathExtension, "mov", name)
                // A QuickTime movie file names its brand in its first box.
                let head = try FileHandle(forReadingFrom: exported[0]).read(upToCount: 12) ?? Data()
                XCTAssertEqual(String(decoding: head.dropFirst(4), as: UTF8.self), "ftypqt  ", name)
                let asset = AVURLAsset(url: exported[0])
                let tracks = try await asset.loadTracks(withMediaType: .video)
                XCTAssertEqual(tracks.count, 1, name)
                let audio = try await asset.loadTracks(withMediaType: .audio)
                XCTAssertTrue(audio.isEmpty, "\(name) is silent")
                let track = try XCTUnwrap(tracks.first)
                let dimensions = try await track.load(.naturalSize)
                let transform = try await track.load(.preferredTransform)
                XCTAssertEqual([Int(dimensions.width), Int(dimensions.height)], [size.0, size.1], name)
                XCTAssertEqual(transform, .identity, "\(name): the frame is stored upright")
                let formats = try await track.load(.formatDescriptions)
                XCTAssertEqual(formats.map { CMFormatDescriptionGetMediaSubType($0) }, [kCMVideoCodecType_H264], name)
                // Movies carry no color tags. Shown the question on 2026-10-13, the captain chose to leave them as they are.
                for key in [kCMFormatDescriptionExtension_ColorPrimaries, kCMFormatDescriptionExtension_TransferFunction,
                            kCMFormatDescriptionExtension_YCbCrMatrix] {
                    XCTAssertNil(CMFormatDescriptionGetExtension(formats[0], extensionKey: key), "\(name): \(key)")
                }
                // Each clip is its whole frames, the last held to the cut, so no frame is a sliver and the file's own
                // frame rate never reads above the Camera's. The file's clock ticks 600 times a second, so a frame lands
                // within a tick of its place.
                let perClip = DevelopedMovieFormat.frameCount(seconds: manifest.movie.durationSeconds, camera: camera.id)
                let frames = try await frameTimes(exported[0])
                XCTAssertEqual(frames.count, 2 * perClip, name)
                let rate = try await track.load(.nominalFrameRate)
                XCTAssertLessThanOrEqual(Double(rate), Double(framesPerSecond) + 0.01, name)
                XCTAssertGreaterThan(Double(rate), Double(framesPerSecond) - 2, name)
                for clip in 0..<2 {
                    let start = Double(clip) * manifest.movie.durationSeconds
                    for frame in 0..<perClip {
                        XCTAssertEqual(frames[clip * perClip + frame].seconds, start + Double(frame) / Double(framesPerSecond),
                                       accuracy: 1.0 / 600 + 0.0001, "\(name): clip \(clip + 1) frame \(frame)")
                    }
                }
                let duration = try await asset.load(.duration)
                XCTAssertEqual(duration.seconds, 2 * manifest.movie.durationSeconds, accuracy: 1.0 / 600 + 0.0001,
                               "\(name): the Movie lasts as long as was recorded")
            }
        }
    }

    private func exportedPhotos(camera: CameraPackage, filmStock: FilmStock? = nil, sourceWidth: Int, sourceHeight: Int,
                                completesEarly: Bool = true) async throws -> [URL] {
        let (repository, film, processor) = try await developedPhotos(camera: camera, filmStock: filmStock, sourceWidth: sourceWidth,
                                                                    sourceHeight: sourceHeight, completesEarly: completesEarly)
        return try await export(processor, repository, film)
    }

    private func developedPhotos(camera: CameraPackage, filmStock: FilmStock?, sourceWidth: Int, sourceHeight: Int,
                                 completesEarly: Bool) async throws -> (FilmRepository, Film, FilmProcessor) {
        let home = root.appendingPathComponent(UUID().uuidString)
        let fixtures = home.appendingPathComponent("Fixtures")
        var settings = RenderFixtureSettings.defaultExperimental
        settings.photoWidth = sourceWidth; settings.photoHeight = sourceHeight
        _ = try await RenderFixtureGenerator.writeFixtures(outputDirectory: fixtures, settings: settings)
        let source = try Data(contentsOf: fixtures.appendingPathComponent("synthetic-developed-photo.jpg"))
        let repository = try FilmRepository(rootURL: home)
        let film = try repository.createFilm(camera: camera, title: "Roll", filmStock: filmStock ?? camera.defaultFilmStock)
        for _ in 0..<2 { try repository.savePhotoCapture(filmID: film.id, sourceData: source) }
        if completesEarly { try repository.completeEarly(filmID: film.id) }
        let processor = try FilmProcessor(root: home)
        try await processor.develop(filmID: film.id)
        return (repository, film, processor)
    }

    /// Saves the Film's developed results as Save Developed to Photos does, keeping each file handed to Photos.
    private func export(_ processor: FilmProcessor, _ repository: FilmRepository, _ film: Film) async throws -> [URL] {
        let kept = root.appendingPathComponent("Saved-\(UUID())")
        try FileManager.default.createDirectory(at: kept, withIntermediateDirectories: true)
        let writer = KeepingWriter(directory: kept)
        let sequences = try repository.film(id: film.id).captures.map(\.sequenceNumber)
        try await processor.export(filmID: film.id, sequences: sequences, originals: false,
                                   coordinator: PhotoExportCoordinator(authorizer: Authorized(), writer: writer))
        return await writer.saved
    }

    /// When each frame of the movie is presented, from decoding every frame.
    private func frameTimes(_ url: URL) async throws -> [CMTime] {
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let track = try XCTUnwrap(tracks.first)
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        reader.add(output)
        XCTAssertTrue(reader.startReading())
        var times: [CMTime] = []
        while let sample = output.copyNextSampleBuffer() {
            guard CMSampleBufferGetImageBuffer(sample) != nil else { continue }
            times.append(CMSampleBufferGetPresentationTimeStamp(sample))
        }
        XCTAssertEqual(reader.status, .completed)
        return times.sorted()
    }
}

/// A saved photograph as its file describes it.
private struct ExportedPhoto {
    let type: String
    let width: Int
    let height: Int
    let colorSpace: String?

    init(_ url: URL) throws {
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        type = try XCTUnwrap(CGImageSourceGetType(source)) as String
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        width = image.width
        height = image.height
        colorSpace = image.colorSpace?.name as String?
        let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        XCTAssertEqual((properties[kCGImagePropertyOrientation] as? Int) ?? 1, 1, "The picture is stored upright")
    }
}

private struct Authorized: PhotoLibraryAuthorizing {
    func authorizationStatus(for accessLevel: PhotoLibraryAccessLevel) -> PhotoLibraryAuthorizationStatus { .authorized }
    func requestAuthorization(for accessLevel: PhotoLibraryAccessLevel) async -> PhotoLibraryAuthorizationStatus { .authorized }
}

/// Stands in for Photos and keeps a copy of each file it is handed, under the name it was handed with.
private actor KeepingWriter: PhotoLibraryWriting {
    let directory: URL
    private(set) var saved: [URL] = []

    init(directory: URL) { self.directory = directory }

    func write(_ request: PhotoExportRequest) async throws -> PhotoExportReceipt {
        let copy = directory.appendingPathComponent(request.fileURL.lastPathComponent)
        try FileManager.default.copyItem(at: request.fileURL, to: copy)
        saved.append(copy)
        return PhotoExportReceipt(localIdentifier: "synthetic-\(saved.count)")
    }
}
