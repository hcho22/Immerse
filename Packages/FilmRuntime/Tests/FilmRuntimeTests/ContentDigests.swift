@preconcurrency import AVFoundation
import CryptoKit
import Foundation
import XCTest

/// The SHA-256 of `data`, in hex: equal only for equal bytes, every one of them.
func sha256Hex(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

/// The SHA-256 of each decoded frame's pixels, row by row and without the padding a row may carry, so two encodes of
/// the same frames compare equal and a frame that differs in any pixel differs. Only frames read back in the same run
/// are compared (AGENTS.md: a Developed Clip has no color tags).
func frameDigests(_ url: URL) async throws -> [String] {
    let asset = AVURLAsset(url: url)
    let tracks = try await asset.loadTracks(withMediaType: .video)
    let reader = try AVAssetReader(asset: asset)
    let output = AVAssetReaderTrackOutput(track: try XCTUnwrap(tracks.first), outputSettings: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ])
    reader.add(output)
    XCTAssertTrue(reader.startReading(), reader.failureDescription(framesRead: 0))
    var digests: [String] = []
    while let sample = output.copyNextSampleBuffer() {
        let buffer = try XCTUnwrap(CMSampleBufferGetImageBuffer(sample))
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let base = try XCTUnwrap(CVPixelBufferGetBaseAddress(buffer))
        let (stride, visible) = (CVPixelBufferGetBytesPerRow(buffer), CVPixelBufferGetWidth(buffer) * 4)
        var hash = SHA256()
        for row in 0..<CVPixelBufferGetHeight(buffer) {
            hash.update(bufferPointer: UnsafeRawBufferPointer(start: base + row * stride, count: visible))
        }
        digests.append(hash.finalize().map { String(format: "%02x", $0) }.joined())
    }
    XCTAssertEqual(reader.status, .completed, reader.failureDescription(framesRead: digests.count))
    XCTAssertFalse(digests.isEmpty)
    return digests
}
