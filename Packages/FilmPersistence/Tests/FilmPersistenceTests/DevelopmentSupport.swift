import CoreGraphics
import FilmDomain
import FilmPersistence
import Foundation
import ImageIO
import RenderCore
import RenderFixtures

func testPhotoData() throws -> Data {
    let context = CGContext(data: nil, width: 32, height: 24, bitsPerComponent: 8, bytesPerRow: 128,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.setFillColor(CGColor(red: 0.3, green: 0.6, blue: 0.8, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 32, height: 24))
    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    guard CGImageDestinationFinalize(destination) else { throw PersistenceError.invalidMedia }
    return data as Data
}

func revealTestInstant(_ repository: FilmRepository, filmID: UUID, sequence: Int = 1) throws {
    _ = try repository.beginDevelopment(filmID: filmID)
    if try repository.mediaAsset(filmID: filmID, sequenceNumber: sequence, kind: .master) == nil {
        try repository.writeDevelopedMaster(filmID: filmID, sequenceNumber: sequence, data: testPhotoData())
    }
    let master = try repository.mediaAsset(filmID: filmID, sequenceNumber: sequence, kind: .master)!
    try repository.finishVerifiedDevelopment(filmID: filmID, verifiedMedia: [VerifiedMedia.photo(at: master.url)], instantSequence: sequence)
}

func developTestFilm(_ repository: FilmRepository, filmID: UUID) async throws {
    _ = try repository.beginDevelopment(filmID: filmID)
    let film = try repository.film(id: filmID)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("DevelopmentSupport-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    var evidence: [VerifiedMedia] = []
    var clips: [URL] = []
    for capture in film.captures {
        switch capture.kind {
        case .photo:
            try repository.writeDevelopedMaster(filmID: filmID, sequenceNumber: capture.sequenceNumber, data: testPhotoData())
            let master = try repository.mediaAsset(filmID: filmID, sequenceNumber: capture.sequenceNumber, kind: .master)!
            evidence.append(try VerifiedMedia.photo(at: master.url))
        case let .movieClip(seconds, _):
            var settings = RenderFixtureSettings.defaultExperimental
            settings.photoWidth = 32; settings.photoHeight = 24
            settings.movieWidth = 64; settings.movieHeight = 48
            settings.movieDurationSeconds = seconds
            let directory = root.appendingPathComponent(String(capture.sequenceNumber))
            _ = try await RenderFixtureGenerator.writeFixtures(outputDirectory: directory, settings: settings)
            let data = try Data(contentsOf: directory.appendingPathComponent("synthetic-developed-movie.mov"))
            try repository.writeDevelopedClip(filmID: filmID, sequenceNumber: capture.sequenceNumber, data: data)
            let clip = try repository.mediaAsset(filmID: filmID, sequenceNumber: capture.sequenceNumber, kind: .clip)!
            evidence.append(try await VerifiedMedia.movie(at: clip.url))
            clips.append(clip.url)
        }
    }
    if !clips.isEmpty {
        let output = root.appendingPathComponent("movie.mov")
        try await NativeMovieRenderer.assemble(clips: clips, destination: output)
        let verified = try await VerifiedMedia.movie(at: output)
        try repository.writeAssembledMovie(filmID: filmID, data: Data(contentsOf: output), clipSequenceNumbers: film.captures.map(\.sequenceNumber), verification: verified)
        evidence.append(verified)
    }
    try repository.finishVerifiedDevelopment(filmID: filmID, verifiedMedia: evidence)
}
