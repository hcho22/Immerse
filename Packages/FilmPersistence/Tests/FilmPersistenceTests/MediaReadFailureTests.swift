@preconcurrency import AVFoundation
import CoreImage
import FilmPersistence
import Foundation
import XCTest

/// A stored 16mm clip twice failed to read back on CI, once inside `VerifiedMedia`, which then said only `invalidMedia`
/// (`Evidence/NativeApp/developed-clip-reader-failure-070.md`). These tests hold a read that does not finish, of a movie's
/// pictures or of a soundtrack, to naming what AVFoundation said, and every other refusal to `invalidMedia` as before.
final class MediaReadFailureTests: XCTestCase {
    func testAClipThatStopsReadingPartwayNamesTheErrorAVFoundationGave() async throws {
        let root = try Self.root(); defer { try? FileManager.default.removeItem(at: root) }
        let clip = root.appendingPathComponent("clip.mov")
        try await Self.writeClip(to: clip)
        try Self.cutOff(clip, keeping: 0.75)
        do {
            _ = try await VerifiedMedia.movie(at: clip)
            XCTFail("A clip cut off partway was verified")
        } catch let PersistenceError.unreadableMedia(failure) {
            XCTAssertEqual(failure.stage, .picture, "\(failure)")
            XCTAssertEqual(failure.status, AVAssetReader.Status.failed.rawValue, "\(failure)")
            Self.assertNamesAVFoundationsError(failure)
            let message = String(reflecting: PersistenceError.unreadableMedia(failure))
            XCTAssertTrue(message.contains("unreadableMedia(picture read did not finish: reader status failed (3) after "),
                          message)
            XCTAssertTrue(message.contains("; error: AVFoundationErrorDomain "), message)
            XCTAssertTrue(message.contains("; underlying error: "), message)
        }
    }

    func testASoundtrackThatStopsReadingPartwayNamesTheErrorAVFoundationGave() async throws {
        let root = try Self.root(); defer { try? FileManager.default.removeItem(at: root) }
        let sound = root.appendingPathComponent("sound.m4a")
        try await Self.writeSoundtrack(to: sound)
        try Self.cutOff(sound, keeping: 0.5)
        do {
            _ = try await VerifiedMedia.audio(at: sound)
            XCTFail("A soundtrack cut off partway was verified")
        } catch let PersistenceError.unreadableMedia(failure) {
            XCTAssertEqual(failure.stage, .sound, "\(failure)")
            XCTAssertEqual(failure.status, AVAssetReader.Status.failed.rawValue, "\(failure)")
            Self.assertNamesAVFoundationsError(failure)
            XCTAssertTrue(failure.description.hasPrefix("sound read did not finish: reader status failed (3) after "),
                          failure.description)
        }
    }

    func testMediaOfTheWrongShapeIsStillInvalid() async throws {
        let root = try Self.root(); defer { try? FileManager.default.removeItem(at: root) }
        let clip = root.appendingPathComponent("clip.mov"), sound = root.appendingPathComponent("sound.m4a")
        try await Self.writeClip(to: clip)
        try await Self.writeSoundtrack(to: sound)
        do { _ = try await VerifiedMedia.movie(at: sound); XCTFail("Sound alone was verified as a movie") }
        catch { XCTAssertEqual(error as? PersistenceError, .invalidMedia, "\(error)") }
        do { _ = try await VerifiedMedia.audio(at: clip); XCTFail("Pictures alone were verified as a soundtrack") }
        catch { XCTAssertEqual(error as? PersistenceError, .invalidMedia, "\(error)") }
    }

    func testWholeMediaStillVerifies() async throws {
        let root = try Self.root(); defer { try? FileManager.default.removeItem(at: root) }
        let clip = root.appendingPathComponent("clip.mov"), sound = root.appendingPathComponent("sound.m4a")
        try await Self.writeClip(to: clip)
        try await Self.writeSoundtrack(to: sound)
        let movie = try await VerifiedMedia.movie(at: clip)
        XCTAssertEqual(movie.decodedFrameCount, 60)
        let audio = try await VerifiedMedia.audio(at: sound)
        XCTAssertGreaterThan(audio.decodedFrameCount, 0)
    }

    private static func assertNamesAVFoundationsError(_ failure: MediaReadFailure, file: StaticString = #filePath,
                                                      line: UInt = #line) {
        XCTAssertEqual(failure.errors.first?.domain, AVFoundationErrorDomain, "\(failure)", file: file, line: line)
        XCTAssertGreaterThanOrEqual(failure.errors.count, 2, "AVFoundation's error and the one underneath: \(failure)",
                                    file: file, line: line)
    }

    private static func root() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("MediaReadFailureTests-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    /// Keeps the first `fraction` of a file. Its index leads the file, so the cut file opens and then fails to read.
    private static func cutOff(_ url: URL, keeping fraction: Double) throws {
        let size = try XCTUnwrap(FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int)
        let handle = try FileHandle(forUpdating: url)
        try handle.truncate(atOffset: UInt64(Double(size) * fraction))
        try handle.close()
    }

    /// Two seconds of H.264 at 30 fps, a different color each frame so a cut cannot miss the picture data.
    private static func writeClip(to url: URL) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        writer.shouldOptimizeForNetworkUse = true
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 320, AVVideoHeightKey: 240])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 320, kCVPixelBufferHeightKey as String: 240])
        writer.add(input)
        XCTAssertTrue(writer.startWriting())
        writer.startSession(atSourceTime: .zero)
        let context = CIContext()
        let bounds = CGRect(x: 0, y: 0, width: 320, height: 240)
        for frame in 0..<60 {
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(2)) }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, try XCTUnwrap(adaptor.pixelBufferPool), &buffer)
            let gray = CGFloat(frame % 10) / 10
            context.render(CIImage(color: CIColor(red: gray, green: 1 - gray, blue: gray / 2)).cropped(to: bounds),
                           to: try XCTUnwrap(buffer), bounds: bounds, colorSpace: CGColorSpaceCreateDeviceRGB())
            XCTAssertTrue(adaptor.append(try XCTUnwrap(buffer), withPresentationTime: CMTime(value: Int64(frame), timescale: 30)))
        }
        input.markAsFinished()
        await writer.finishWriting()
        XCTAssertEqual(writer.status, .completed, "\(String(describing: writer.error))")
    }

    /// Two seconds of a 440 Hz tone as AAC in an `.m4a`, as a Soundtrack is kept.
    private static func writeSoundtrack(to url: URL) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .m4a)
        writer.shouldOptimizeForNetworkUse = true
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 1
        ])
        input.expectsMediaDataInRealTime = false
        writer.add(input)
        XCTAssertTrue(writer.startWriting())
        writer.startSession(atSourceTime: .zero)
        var pcm = AudioStreamBasicDescription(
            mSampleRate: 44_100, mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked,
            mBytesPerPacket: 2, mFramesPerPacket: 1, mBytesPerFrame: 2, mChannelsPerFrame: 1, mBitsPerChannel: 16,
            mReserved: 0)
        var format: CMAudioFormatDescription?
        CMAudioFormatDescriptionCreate(allocator: nil, asbd: &pcm, layoutSize: 0, layout: nil, magicCookieSize: 0,
                                       magicCookie: nil, extensions: nil, formatDescriptionOut: &format)
        let samples = 88_200
        var written = 0
        while written < samples {
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(2)) }
            let count = min(1_024, samples - written)
            var bytes = Data(count: count * 2)
            bytes.withUnsafeMutableBytes { raw in
                let values = raw.bindMemory(to: Int16.self)
                for index in 0..<count {
                    values[index] = Int16(sin(Double(written + index) * 2 * Double.pi * 440 / 44_100) * 8_000)
                }
            }
            var block: CMBlockBuffer?
            CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: nil, blockLength: bytes.count,
                                               blockAllocator: nil, customBlockSource: nil, offsetToData: 0,
                                               dataLength: bytes.count, flags: 0, blockBufferOut: &block)
            let blockBuffer = try XCTUnwrap(block)
            _ = bytes.withUnsafeBytes { CMBlockBufferReplaceDataBytes(with: $0.baseAddress!, blockBuffer: blockBuffer,
                                                                      offsetIntoDestination: 0, dataLength: bytes.count) }
            var sample: CMSampleBuffer?
            CMAudioSampleBufferCreateReadyWithPacketDescriptions(
                allocator: nil, dataBuffer: blockBuffer, formatDescription: try XCTUnwrap(format), sampleCount: count,
                presentationTimeStamp: CMTime(value: Int64(written), timescale: 44_100), packetDescriptions: nil,
                sampleBufferOut: &sample)
            XCTAssertTrue(input.append(try XCTUnwrap(sample)))
            written += count
        }
        input.markAsFinished()
        await writer.finishWriting()
        XCTAssertEqual(writer.status, .completed, "\(String(describing: writer.error))")
    }
}
