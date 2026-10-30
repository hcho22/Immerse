@preconcurrency import AVFoundation
import CoreGraphics
import CryptoKit
import EntitlementCore
import FilmDomain
@testable import FilmPersistence
import Foundation
import ImageIO
import Observation
import RenderCore
import RenderFixtures

private enum WorkflowError: Error { case invalidArguments, cannotReseedHistory, missingHistory, unexpectedTrialWrite, configuredBilling }

private struct FixtureTrialStore: DeviceTrialStoring {
    let record = DeviceTrialRecord()
    func read() throws -> DeviceTrialRecord? { record }
    func ensureDeviceRecord() throws -> DeviceTrialRecord { throw WorkflowError.unexpectedTrialWrite }
    func consume(filmID: UUID, captureID: String?, savedAt: Date) throws { throw WorkflowError.unexpectedTrialWrite }
}

@MainActor @Observable final class WorkflowScenario {
    let model: JournalModel
    let directory: URL
    private(set) var inspectionCount: Int
    private(set) var inspecting = false

    private struct Seed: Codable { let mode: String; let filmID: UUID }
    private struct Snapshot: Codable {
        let reason: String
        let utc: String
        let process: Int32
        let films: [FilmState]
        let privateFiles: [String]
    }
    private struct FilmState: Codable {
        let film: Film
        let development: DevelopmentRun?
        let captures: [CaptureState]
        let movieSHA256: String?
    }
    private struct CaptureState: Codable {
        let sequence: Int
        let originalDisposition: OriginalDisposition?
        let sourceSHA256: String?
        let masterSHA256: String?
        let clipSHA256: String?
        let printSHA256: String?
        let recipe: DarkroomRecipe?
    }

    private init(directory: URL) throws {
        self.directory = directory
        let evidence = directory.appendingPathComponent("Evidence")
        try FileManager.default.createDirectory(at: evidence, withIntermediateDirectories: true)
        inspectionCount = try FileManager.default.contentsOfDirectory(atPath: evidence.path).filter { $0.hasSuffix(".json") }.count
        #if DEBUG
        // `-ImmerseDebugFreeSpace <bytes>` sets the free-space reading, as in the app's own Debug build.
        model = try JournalModel(root: directory.appendingPathComponent("App"), trialStore: FixtureTrialStore(),
                                 freeSpace: DebugFreeSpace(defaults: .standard))
        #else
        model = try JournalModel(root: directory.appendingPathComponent("App"), trialStore: FixtureTrialStore())
        #endif
        guard !model.billing.configured else { throw WorkflowError.configuredBilling }
    }

    static func prepare(arguments: [String]) async throws -> WorkflowScenario {
        let run: UUID
        if let index = arguments.firstIndex(of: "--workflow-run") {
            guard arguments.indices.contains(index + 1), let id = UUID(uuidString: arguments[index + 1]) else {
                throw WorkflowError.invalidArguments
            }
            run = id
        } else { run = UUID() }
        // `--scratch-history` seeds in the temporary directory instead, outside the histories `run-retained.sh` collects,
        // for the launches a test class makes before its tests.
        let histories = arguments.contains("--scratch-history") ? URL.temporaryDirectory.appendingPathComponent("ScratchHistories")
            : URL.documentsDirectory.appendingPathComponent("WorkflowHistories")
        let directory = histories.appendingPathComponent("\(run)")
        let seedURL = directory.appendingPathComponent("seed.json")
        let reopening = arguments.contains("--reopen")
        guard FileManager.default.fileExists(atPath: seedURL.path) == reopening else {
            throw reopening ? WorkflowError.missingHistory : WorkflowError.cannotReseedHistory
        }
        let scenario = try WorkflowScenario(directory: directory)
        await scenario.model.recoverAtLaunch()
        if reopening {
            _ = try JSONDecoder().decode(Seed.self, from: Data(contentsOf: seedURL))
        } else {
            let mode = arguments.contains("--movie") ? "movie" : arguments.contains("--instant-final") ? "instant-final"
                : arguments.contains("--instant-mixed") ? "instant-mixed"
                : arguments.contains("--instant") ? "instant" : arguments.contains("--empty") ? "empty"
                : arguments.contains("--developed-photo") ? "developed-photo"
                : arguments.contains("--medium-format") ? "medium-format" : "early-photo"
            let movie = mode == "movie", instant = mode.hasPrefix("instant")
            // `--super8` films the Movie on the Super 8 instead of the 16mm.
            let catalogCamera = movie ? (arguments.contains("--super8") ? CameraCatalog.super8HomeMovie : CameraCatalog.cinema16mm)
                : instant ? CameraCatalog.instant1970s
                : mode == "medium-format" ? CameraCatalog.mediumFormat6x6 : CameraCatalog.disposable1990s
            // `--earlier-package` loads the 16mm Film on the package a build before live sound locked, which records no
            // sound.
            let camera = movie && arguments.contains("--earlier-package")
                ? CameraPackage(id: .cinema16mm, displayName: "16mm Cinema", medium: .movie, capacity: .seconds(165),
                                revealRule: .movieDevelopment, supportsBuiltInSoundtrack: true)
                : catalogCamera
            let model = scenario.model
            // `--black-and-white` loads the 6×6 or 16mm Film on the black-and-white Film Stock; otherwise a Camera with a
            // Film Stock gets Load Film's default, color.
            let filmStock = arguments.contains("--black-and-white") ? FilmStock.blackAndWhite : camera.defaultFilmStock
            // `--landscape-movie` locks the Movie landscape, as its clips are; otherwise it is portrait.
            let orientation: MovieOrientation = arguments.contains("--landscape-movie") ? .landscape : .portrait
            let film = try model.repository.createFilm(camera: camera, title: "Private synthetic Film",
                movieOrientation: movie ? orientation : nil, filmStock: filmStock, access: .subscription)
            if mode != "empty" {
                let fixtures = directory.appendingPathComponent("Fixtures")
                var settings = RenderFixtureSettings.defaultExperimental
                settings.photoWidth = 320; settings.photoHeight = 240
                settings.movieWidth = 160; settings.movieHeight = 120; settings.movieDurationSeconds = 0.16
                let manifest = try await RenderFixtureGenerator.writeFixtures(outputDirectory: fixtures, settings: settings)
                // `--photo-source PATH` and `--movie-source PATH` capture a still or a silent movie already on disk instead
                // of the generated fixtures, so screenshots can show a natural scene. Both are harness-only evidence aids.
                let source = { (flag: String) -> URL? in
                    arguments.firstIndex(of: flag).flatMap { arguments.indices.contains($0 + 1) ? URL(fileURLWithPath: arguments[$0 + 1]) : nil }
                }
                if movie, arguments.contains("--recorded-sound") {
                    // `--recorded-sound` saves one ten-second Recorded Clip with Live Audio in place of the two silent
                    // clips, as a 16mm or Super 8 records with the microphone allowed.
                    let clip = fixtures.appendingPathComponent("recorded-clip-with-sound.mov")
                    try await Self.writeClipWithSound(to: clip, seconds: 10)
                    let recorded = try await VerifiedMedia.movie(at: clip, allowsAudio: true)
                    try model.repository.saveMovieClip(filmID: film.id, sourceData: Data(contentsOf: clip),
                        durationSeconds: recorded.durationSeconds ?? 0, orientation: .landscape)
                } else if movie {
                    let clip = source("--movie-source") ?? fixtures.appendingPathComponent("synthetic-developed-movie.mov")
                    let data = try Data(contentsOf: clip)
                    let seconds = source("--movie-source") == nil ? manifest.movie.durationSeconds
                        : try await VerifiedMedia.movie(at: clip).durationSeconds ?? 0
                    for _ in 0..<2 {
                        try model.repository.saveMovieClip(filmID: film.id, sourceData: data,
                            durationSeconds: seconds, orientation: .landscape)
                    }
                } else {
                    let data = try Data(contentsOf: source("--photo-source") ?? fixtures.appendingPathComponent("synthetic-developed-photo.jpg"))
                    if mode == "instant-final" {
                        for _ in 0..<9 { try model.repository.savePhotoCapture(filmID: film.id, sourceData: data) }
                        model.refresh()
                        try await model.develop(film.id)
                    } else {
                    // `--two-sealed`, with `--instant-mixed`, leaves two sealed Instant prints where there is otherwise one,
                    // so one Development reveals both.
                    // `--three-distinct-prints` takes three photos of three plainly different scenes, red, green and blue,
                    // so a test can tell the prints apart by their pictures.
                    let distinct = arguments.contains("--three-distinct-prints")
                    let captures = distinct ? 3 : mode == "instant-mixed" && arguments.contains("--two-sealed") ? 3 : 2
                    for index in 1...captures {
                        let picture = distinct ? try Self.plainScene(index) : data
                        try model.repository.savePhotoCapture(filmID: film.id, sourceData: picture)
                        if mode == "instant-mixed", index == 1 { model.refresh(); try await model.develop(film.id) }
                    }
                    }
                }
                // `--open-film` leaves the `--medium-format` or `--movie` Film open with its saved captures, where it is
                // otherwise finished early and developed.
                let finishes = !arguments.contains("--open-film") && (movie || mode == "developed-photo" || mode == "medium-format")
                if finishes { try model.repository.completeEarly(filmID: film.id) }
                if finishes || mode == "instant" {
                    model.refresh(); try await model.develop(film.id)
                }
            }
            try persist(Seed(mode: mode, filmID: film.id), to: seedURL)
            // `--reveal-at-camera` saves and develops an Instant print once the shooting screen is open, as the app does
            // when a save lands there. `--instant-final` leaves its tenth exposure for this moment to test the one pack-end
            // Originals question.
            // The simulator has no camera, so nothing is captured.
            if arguments.contains("--reveal-at-camera") {
                Task {
                    while !model.capture.presented { try? await Task.sleep(for: .milliseconds(100)) }
                    try? await Task.sleep(for: .seconds(1))
                    if mode == "instant-final",
                       let source = try? Data(contentsOf: directory.appendingPathComponent("Fixtures/synthetic-developed-photo.jpg")) {
                        _ = try? model.repository.savePhotoCapture(filmID: film.id, sourceData: source)
                        model.refresh()
                    }
                    model.developSavedPrint(film.id) { _ in }
                }
            }
        }
        scenario.model.refresh()
        try await scenario.inspect(reason: reopening ? "reopen" : "seeded")
        // `--recipe-outside-limits` leaves print 1 a stored print exposure of 3.5 stops, which only a build with wider
        // limits or a damaged store can: the app's own writers refuse it, so it goes to the store beside them. It is
        // written after the inspection above, which prints every photo, so such a history is never inspected or reopened.
        if !reopening, arguments.contains("--recipe-outside-limits"), let film = scenario.model.films.first {
            try scenario.model.repository.database.setValue(filmID: film.id, key: "recipe-1",
                data: Data(#"{"printExposureStops":3.5,"dodgeBurnMasks":[]}"#.utf8))
        }
        // `--recipe-unreadable` leaves print 1 a stored recipe no build can read, as a damaged store might, so the
        // Darkroom fails to load it; it goes to the store the same way, after the inspection.
        if !reopening, arguments.contains("--recipe-unreadable"), let film = scenario.model.films.first {
            try scenario.model.repository.database.setValue(filmID: film.id, key: "recipe-1", data: Data("unreadable".utf8))
        }
        // A pre-change Film can still have a Dodge/Burn recipe. Seed one after the initial inspection so the harness UI
        // opens that exact stored recipe, while the retained-history check can compare it with the reset result.
        if !reopening, arguments.contains("--recipe-with-strokes"), let film = scenario.model.films.first {
            let stroke = LocalMask(kind: .burn, points: [MaskPoint(x: 0.5, y: 0.5)], exposureStops: 1)
            let recipe = DarkroomRecipe(dodgeBurnMasks: [stroke])
            try scenario.model.repository.database.setValue(filmID: film.id, key: "recipe-1",
                data: JSONEncoder().encode(recipe))
        }
        return scenario
    }

    func inspect(reason: String) async throws {
        guard !inspecting else { return }
        inspecting = true
        defer { inspecting = false }
        var films: [FilmState] = []
        for film in try model.repository.allFilms() {
            var captures: [CaptureState] = []
            for capture in film.captures {
                let sequence = capture.sequenceNumber
                var printHash: String?, recipe: DarkroomRecipe?
                if film.camera.medium == .photo, capture.revealState == .revealed {
                    recipe = try model.repository.darkroomRecipe(filmID: film.id, sequence: sequence)
                    printHash = Self.hash(try await model.processor.photo(filmID: film.id, sequence: sequence))
                }
                captures.append(CaptureState(sequence: sequence,
                    originalDisposition: try model.repository.originalDisposition(filmID: film.id, sequenceNumber: sequence),
                    sourceSHA256: try await assetHash(film: film, sequence: sequence, kind: .source),
                    masterSHA256: try await assetHash(film: film, sequence: sequence, kind: .master),
                    clipSHA256: try await assetHash(film: film, sequence: sequence, kind: .clip),
                    printSHA256: printHash, recipe: recipe))
            }
            films.append(FilmState(film: film, development: try model.repository.developmentRun(filmID: film.id),
                captures: captures, movieSHA256: try await assetHash(film: film, sequence: 0, kind: .movie)))
        }
        let next = inspectionCount + 1
        try Self.persist(Snapshot(reason: reason, utc: ISO8601DateFormatter().string(from: Date()),
            process: ProcessInfo.processInfo.processIdentifier, films: films, privateFiles: privateFiles()),
            to: directory.appendingPathComponent(String(format: "Evidence/%03d.json", next)))
        inspectionCount = next
    }

    private func privateFiles() throws -> [String] {
        let root = directory.appendingPathComponent("App")
        let entries = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey])!
        var paths: [String] = []
        for case let url as URL in entries where try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
            paths.append(String(url.path.dropFirst(root.path.count + 1)))
        }
        return paths.sorted()
    }

    private func assetHash(film: Film, sequence: Int, kind: StoredAsset.Kind) async throws -> String? {
        guard let asset = try model.repository.mediaAsset(filmID: film.id, sequenceNumber: sequence, kind: kind) else { return nil }
        // A clip, and the Movie made from it, can carry the Live Audio a sound-recording Camera records.
        let verified = film.camera.medium == .photo ? try VerifiedMedia.photo(at: asset.url)
            : try await VerifiedMedia.movie(at: asset.url, allowsAudio: film.camera.recordsLiveSound == true)
        guard verified.sha256 == asset.record.sha256 else { throw PersistenceError.mediaChangedDuringVerification }
        return verified.sha256
    }

    private static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private static func persist<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(value).write(to: url, options: .withoutOverwriting)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.synchronize()
    }
}

extension WorkflowScenario {
    /// A clip as a movie Camera writes one with the microphone allowed: a 320 by 240 H.264 picture at 30 frames a second
    /// that brightens as it plays, with a stereo 440 Hz tone in AAC at 48 kHz beside it.
    static func writeClipWithSound(to url: URL, seconds: Double) async throws {
        let (width, height, rate, packet) = (320, 240, 48_000.0, 1024)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let picture = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: picture, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height
        ])
        let sound = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: rate, AVNumberOfChannelsKey: 2
        ])
        // Real-time inputs, as the camera's movie output writes: neither waits for the other to interleave.
        picture.expectsMediaDataInRealTime = true
        sound.expectsMediaDataInRealTime = true
        writer.add(picture)
        writer.add(sound)
        guard writer.startWriting() else { throw WorkflowError.cannotReseedHistory }
        writer.startSession(atSourceTime: .zero)
        var format = AudioStreamBasicDescription(mSampleRate: rate, mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked, mBytesPerPacket: 4,
            mFramesPerPacket: 1, mBytesPerFrame: 4, mChannelsPerFrame: 2, mBitsPerChannel: 16, mReserved: 0)
        var description: CMAudioFormatDescription?
        CMAudioFormatDescriptionCreate(allocator: nil, asbd: &format, layoutSize: 0, layout: nil, magicCookieSize: 0,
                                       magicCookie: nil, extensions: nil, formatDescriptionOut: &description)
        guard let description else { throw WorkflowError.cannotReseedHistory }
        let frames = Int(seconds * 30)
        var soundTime = 0
        for frame in 0..<frames {
            // The sound up to the end of this picture frame, then the frame.
            while Double(soundTime) / rate < Double(frame + 1) / 30 {
                while !sound.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(2)) }
                var samples = [Int16](repeating: 0, count: packet * 2)
                for index in 0..<packet {
                    let value = Int16(sin(Double(soundTime + index) * 2 * .pi * 440 / rate) * 4_000)
                    samples[2 * index] = value; samples[2 * index + 1] = value
                }
                var block: CMBlockBuffer?
                CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: nil, blockLength: packet * 4,
                    blockAllocator: nil, customBlockSource: nil, offsetToData: 0, dataLength: packet * 4, flags: 0,
                    blockBufferOut: &block)
                guard let block else { throw WorkflowError.cannotReseedHistory }
                samples.withUnsafeBytes { _ = CMBlockBufferReplaceDataBytes(with: $0.baseAddress!, blockBuffer: block,
                                                                            offsetIntoDestination: 0, dataLength: packet * 4) }
                var buffer: CMSampleBuffer?
                CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: nil, dataBuffer: block,
                    formatDescription: description, sampleCount: packet,
                    presentationTimeStamp: CMTime(value: CMTimeValue(soundTime), timescale: CMTimeScale(rate)),
                    packetDescriptions: nil, sampleBufferOut: &buffer)
                guard let buffer, sound.append(buffer) else { throw WorkflowError.cannotReseedHistory }
                soundTime += packet
            }
            while !picture.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(2)) }
            var buffer: CVPixelBuffer?
            guard let pool = adaptor.pixelBufferPool else { throw WorkflowError.cannotReseedHistory }
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
            guard let pixels = buffer else { throw WorkflowError.cannotReseedHistory }
            CVPixelBufferLockBaseAddress(pixels, [])
            let base = CVPixelBufferGetBaseAddress(pixels)!.assumingMemoryBound(to: UInt8.self)
            let row = CVPixelBufferGetBytesPerRow(pixels)
            for y in 0..<height {
                for x in 0..<width {
                    // Blue, green, red and alpha: a warm half and a cool half.
                    let pixel = base + y * row + x * 4
                    pixel[0] = x < width / 2 ? 60 : 170
                    pixel[1] = UInt8(60 + frame % 120)
                    pixel[2] = x < width / 2 ? 190 : 70
                    pixel[3] = 255
                }
            }
            CVPixelBufferUnlockBaseAddress(pixels, [])
            guard adaptor.append(pixels, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: 30)) else {
                throw WorkflowError.cannotReseedHistory
            }
        }
        picture.markAsFinished()
        sound.markAsFinished()
        writer.endSession(atSourceTime: CMTime(value: CMTimeValue(frames), timescale: 30))
        await writer.finishWriting()
        guard writer.status == .completed else { throw WorkflowError.cannotReseedHistory }
    }

    /// A 320 by 240 JPEG of one plain color, the `index`th of red, green and blue.
    static func plainScene(_ index: Int) throws -> Data {
        let colors: [(CGFloat, CGFloat, CGFloat)] = [(0.85, 0.15, 0.12), (0.15, 0.7, 0.2), (0.12, 0.25, 0.85)]
        let color = colors[(index - 1) % colors.count]
        guard let context = CGContext(data: nil, width: 320, height: 240, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw WorkflowError.cannotReseedHistory
        }
        context.setFillColor(red: color.0, green: color.1, blue: color.2, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 320, height: 240))
        let data = NSMutableData()
        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil) else {
            throw WorkflowError.cannotReseedHistory
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw WorkflowError.cannotReseedHistory }
        return data as Data
    }
}
