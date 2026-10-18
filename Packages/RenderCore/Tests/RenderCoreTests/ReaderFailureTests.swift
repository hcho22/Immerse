@preconcurrency import AVFoundation
import CoreImage
import FilmDomain
import Foundation
import RenderCore
import XCTest

/// `decodedFrames` once finished a developed clip's read with status failed and nothing else, so the cause was never
/// known. These tests hold a failed read, in the tests' helper and in Development, to naming the error AVFoundation gave.
final class ReaderFailureTests: XCTestCase {
    /// On the main thread, so the expected failure matches the assertion `decodedFrames` makes on another.
    @MainActor
    func testAFailedReadNamesTheErrorAVFoundationGave() async throws {
        let (url, cleanUp) = try await Self.clip(cutShort: true)
        defer { cleanUp() }
        let options = XCTExpectedFailure.Options()
        options.issueMatcher = { issue in
            let message = issue.compactDescription
            return issue.type == .assertionFailure && message.contains("reader status failed (3) after ")
                && message.contains("; error: AVFoundationErrorDomain ") && message.contains("; underlying error: ")
        }
        XCTExpectFailure("A clip cut off halfway cannot be read to its end", options: options)
        _ = try await decodedFrames(url)
    }

    func testDevelopingAClipThatCannotBeReadCarriesTheErrorAVFoundationGave() async throws {
        let (url, cleanUp) = try await Self.clip(cutShort: true)
        defer { cleanUp() }
        do {
            try await NativeMovieRenderer.developClip(source: url, destination: url.deletingLastPathComponent()
                .appendingPathComponent("developed.mov"), camera: CameraCatalog.super8HomeMovie, seed: 1,
                orientation: .landscape, longEdge: 320)
            XCTFail("A clip cut off halfway developed")
        } catch NativeRenderError.invalidMovie(let underlying) {
            let error = try XCTUnwrap(underlying, "The reader's error")
            XCTAssertEqual(error.domain, AVFoundationErrorDomain, "\(error)")
            XCTAssertNotNil(error.userInfo[NSUnderlyingErrorKey] as? NSError, "\(error)")
        }
    }

    func testAWholeClipReadsToTheEndWithNoError() async throws {
        let (url, cleanUp) = try await Self.clip(cutShort: false)
        defer { cleanUp() }
        let frames = try await decodedFrames(url)
        XCTAssertEqual(frames.count, 30)
    }

    /// A clip, whole or with its pictures cut off halfway. Its index leads the file, so a cut one opens and then fails to read.
    private static func clip(cutShort: Bool) async throws -> (URL, () -> Void) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderFailureTests-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("clip.mov")
        try await writeClip(to: url)
        if cutShort {
            let size = try XCTUnwrap(FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int)
            let handle = try FileHandle(forUpdating: url)
            try handle.truncate(atOffset: UInt64(size / 2))
            try handle.close()
        }
        return (url, { try? FileManager.default.removeItem(at: root) })
    }

    private static func writeClip(to url: URL) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        writer.shouldOptimizeForNetworkUse = true
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 320, AVVideoHeightKey: 240])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 320, kCVPixelBufferHeightKey as String: 240])
        writer.add(input)
        XCTAssertTrue(writer.startWriting())
        writer.startSession(atSourceTime: .zero)
        let context = CIContext()
        for frame in 0..<30 {
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(2)) }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, try XCTUnwrap(adaptor.pixelBufferPool), &buffer)
            // A different gray each frame, so the picture data is not a few bytes the cut could miss.
            let gray = CGFloat(frame % 10) / 10
            context.render(CIImage(color: CIColor(red: gray, green: 1 - gray, blue: gray / 2)).cropped(to: CGRect(x: 0, y: 0, width: 320, height: 240)),
                           to: try XCTUnwrap(buffer), bounds: CGRect(x: 0, y: 0, width: 320, height: 240),
                           colorSpace: CGColorSpaceCreateDeviceRGB())
            XCTAssertTrue(adaptor.append(try XCTUnwrap(buffer), withPresentationTime: CMTime(value: Int64(frame), timescale: 30)))
        }
        input.markAsFinished()
        await writer.finishWriting()
        XCTAssertEqual(writer.status, .completed)
    }
}
