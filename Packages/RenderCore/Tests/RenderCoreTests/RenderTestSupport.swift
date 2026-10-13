@preconcurrency import AVFoundation
import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import RenderCore
import XCTest

extension XCTestCase {
    /// A test that needs the 16mm Cinema's or the 6×6 Medium Format's color Film Stock developed is skipped where
    /// Core Image cannot run the tetrahedral reader: there those two Film Stocks do not develop.
    func requireTetrahedralReader() throws {
        try XCTSkipUnless(NativePhotoRenderer.readsFilmTables, "Core Image cannot run the tetrahedral reader here")
    }
}

/// Decoded RGBA pixels and the measures these tests compare.
struct DecodedPixels {
    let width: Int
    let height: Int
    let bytes: [UInt8]

    init(width: Int, height: Int, bytes: [UInt8]) {
        self.width = width
        self.height = height
        self.bytes = bytes
    }

    init(_ data: Data) throws {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        self.init(width: image.width, height: image.height, bytes: bytes)
    }

    /// The largest difference between any two channels of any pixel: 0 for perfectly neutral gray.
    var largestChannelSpread: Int {
        bytes.withUnsafeBufferPointer { pixels in
            var largest = 0
            for index in stride(from: 0, to: pixels.count, by: 4) {
                let r = Int(pixels[index]), g = Int(pixels[index + 1]), b = Int(pixels[index + 2])
                largest = max(largest, max(r, g, b) - min(r, g, b))
            }
            return largest
        }
    }

    private func luminance(_ index: Int) -> Double {
        0.2126 * Double(bytes[index]) + 0.7152 * Double(bytes[index + 1]) + 0.0722 * Double(bytes[index + 2])
    }

    /// The standard deviation of luminance over the whole picture, in 8-bit levels.
    var luminanceDeviation: Double { deviation(in: 0..<height, 0..<width) }

    /// The standard deviation of luminance in the middle quarter, away from the vignette's falloff.
    var centerDeviation: Double { deviation(in: height / 4..<height * 3 / 4, width / 4..<width * 3 / 4) }

    private func deviation(in rows: Range<Int>, _ columns: Range<Int>) -> Double {
        var sum = 0.0, squares = 0.0, count = 0.0
        for y in rows { for x in columns {
            let value = luminance((y * width + x) * 4)
            sum += value; squares += value * value; count += 1
        } }
        let mean = sum / count
        return (squares / count - mean * mean).squareRoot()
    }

    /// The mean absolute difference in luminance from another picture of the same size, in 8-bit levels.
    func meanLuminanceDifference(from other: DecodedPixels) -> Double {
        precondition(width == other.width && height == other.height)
        var total = 0.0
        for index in stride(from: 0, to: bytes.count, by: 4) { total += abs(luminance(index) - other.luminance(index)) }
        return total / Double(width * height)
    }
}

extension DecodedPixels {
    /// The mean red, green and blue of each cell of a `grid` x `grid` division, row by row from the top left, rounded
    /// to whole levels.
    func blockMeans(grid: Int = 8) -> [Int] {
        var result: [Int] = []
        for row in 0..<grid { for column in 0..<grid {
            let x0 = column * width / grid, x1 = (column + 1) * width / grid
            let y0 = row * height / grid, y1 = (row + 1) * height / grid
            var sums = [0.0, 0.0, 0.0]
            for y in y0..<y1 { for x in x0..<x1 {
                let index = (y * width + x) * 4
                for channel in 0..<3 { sums[channel] += Double(bytes[index + channel]) }
            } }
            let count = Double((x1 - x0) * (y1 - y0))
            result += sums.map { Int(($0 / count).rounded()) }
        } }
        return result
    }
}

/// Every frame of a movie's video track, as RGBA.
func decodedFrames(_ url: URL) async throws -> [DecodedPixels] {
    let asset = AVURLAsset(url: url)
    let tracks = try await asset.loadTracks(withMediaType: .video)
    let track = try XCTUnwrap(tracks.first)
    let reader = try AVAssetReader(asset: asset)
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ])
    reader.add(output)
    XCTAssertTrue(reader.startReading())
    var result: [DecodedPixels] = []
    while let sample = output.copyNextSampleBuffer() {
        let buffer = try XCTUnwrap(CMSampleBufferGetImageBuffer(sample))
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let base = try XCTUnwrap(CVPixelBufferGetBaseAddress(buffer))
        let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer)
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for row in 0..<height {
            let line = base.advanced(by: row * CVPixelBufferGetBytesPerRow(buffer)).assumingMemoryBound(to: UInt8.self)
            // BGRA to RGBA, so every frame is read in the same channel order as a decoded photo.
            for x in 0..<width {
                let to = (row * width + x) * 4
                bytes[to] = line[x * 4 + 2]; bytes[to + 1] = line[x * 4 + 1]; bytes[to + 2] = line[x * 4]; bytes[to + 3] = line[x * 4 + 3]
            }
        }
        result.append(DecodedPixels(width: width, height: height, bytes: bytes))
    }
    XCTAssertEqual(reader.status, .completed)
    return result
}

/// Twelve frames at 30 fps of a still, drifting one pixel a frame, as a 320 x 240 H.264 movie: a moving scene whose
/// every frame is known.
func writeStillMovie(from photo: URL, to url: URL, frames: Int = 12) async throws {
    let still = try XCTUnwrap(CIImage(contentsOf: photo))
    let width = 320, height = 240
    let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width, AVVideoHeightKey: height])
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height])
    writer.add(input)
    XCTAssertTrue(writer.startWriting())
    writer.startSession(atSourceTime: .zero)
    let context = CIContext()
    let scale = CGFloat(width + 24) / still.extent.width
    for frame in 0..<frames {
        while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(2)) }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, try XCTUnwrap(adaptor.pixelBufferPool), &buffer)
        let image = still.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(translationX: -CGFloat(frame), y: 0))
        context.render(image, to: try XCTUnwrap(buffer), bounds: CGRect(x: 0, y: 0, width: width, height: height),
                       colorSpace: CGColorSpaceCreateDeviceRGB())
        XCTAssertTrue(adaptor.append(try XCTUnwrap(buffer), withPresentationTime: CMTime(value: Int64(frame), timescale: 30)))
    }
    input.markAsFinished()
    await writer.finishWriting()
    XCTAssertEqual(writer.status, .completed)
}
