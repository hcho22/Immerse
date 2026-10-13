import Accelerate
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

/// Film grain as tiles of noise, made once for a kind of grain and reused: white noise with a normal spread, softened
/// to the grain's size, joined for a negative film by a second, coarser octave, with a share of every layer's noise
/// common to all three, and each layer brought to a deviation of exactly 1. A frame or a photograph takes one tile at
/// an offset of its own. Eight tiles of 512 pixels a side is the captain's number for both negative Film Stocks. The
/// tiles of the two kinds of grain asked for last are kept, so two Films developing at once do not remake each
/// other's.
///
/// The noise is made here, in plain arithmetic, and laid out one tile pixel to one picture pixel (`tiled`), so that
/// it is the same on every renderer. Core Image's tiling filter, left to its own default, lays a tile out 1 to 1 on
/// iOS and shrunk to two fifths on a Mac, which once left grain measured on the Mac finer there and 1.6 times as
/// strong on iOS.
final class GrainField: @unchecked Sendable {
    static let shared = GrainField()
    static let side = 512
    static let count = 8

    /// What makes one kind of grain: the blur radius of its clumps in pixels, its second octave, and the share of
    /// every layer's noise that all three have in common.
    struct Make: Equatable {
        var size: Double
        var secondOctaveSize = 1.0
        var secondOctaveWeight = 0.0
        var shared = 0.0
    }

    private struct Kind: Hashable {
        let size: Int
        let secondOctaveSize: Double
        let secondOctaveWeight: Double
        let shared: Double
    }

    /// A tile repeated over the whole plane, one tile pixel to one picture pixel, and moved by whole pixels so that
    /// each frame or photograph starts somewhere of its own in it.
    static func tiled(_ tile: CIImage, movedBy offset: CGPoint = .zero) -> CIImage {
        let filter = CIFilter.affineTile()
        filter.inputImage = tile.samplingNearest()
        // Never the filter's own default, which is not the same on every platform.
        filter.transform = .identity
        return filter.outputImage!.transformed(by: CGAffineTransform(translationX: -offset.x.rounded(.down), y: -offset.y.rounded(.down)))
    }

    private let lock = NSLock()
    /// The kinds kept, the one asked for last first.
    private var kept: [(kind: Kind, tiles: [Int: CIImage])] = []

    /// A negative film's grain; `size` is its blur radius in pixels of the frame.
    func tile(size: Double, grain: FilmLook.ScenePasses.Grain, index: Int) -> CIImage {
        tile(Make(size: size, secondOctaveSize: grain.secondOctaveSize, secondOctaveWeight: grain.secondOctaveWeight,
                  shared: grain.shared), index: index)
    }

    /// One tile of a kind of grain: red, green and blue each with a mean of 0 and a deviation of 1.
    func tile(_ grain: Make, index: Int) -> CIImage {
        let asked = Kind(size: Int((grain.size * 1000).rounded()), secondOctaveSize: grain.secondOctaveSize,
                         secondOctaveWeight: grain.secondOctaveWeight, shared: grain.shared)
        let index = min(max(index, 0), Self.count - 1)
        lock.lock()
        defer { lock.unlock() }
        if let position = kept.firstIndex(where: { $0.kind == asked }) {
            kept.insert(kept.remove(at: position), at: 0)
        } else {
            kept.insert((asked, [:]), at: 0)
            kept = Array(kept.prefix(2))
        }
        if let tile = kept[0].tiles[index] { return tile }
        let values = Self.field(grain, seed: UInt64(index) &* 0x9e37_79b9_7f4a_7c15 &+ 0x1234_5678)
        let tile = CIImage(bitmapData: values.withUnsafeBufferPointer { Data(buffer: $0) }, bytesPerRow: Self.side * 16,
                           size: CGSize(width: Self.side, height: Self.side), format: .RGBAf, colorSpace: nil)
        kept[0].tiles[index] = tile
        return tile
    }

    static func field(size: Double, grain: FilmLook.ScenePasses.Grain, seed: UInt64) -> [Float] {
        field(Make(size: size, secondOctaveSize: grain.secondOctaveSize, secondOctaveWeight: grain.secondOctaveWeight,
                   shared: grain.shared), seed: seed)
    }

    /// One tile's values, red, green, blue and an alpha of 1 for each cell, row by row. It repeats seamlessly.
    static func field(_ grain: Make, seed: UInt64) -> [Float] {
        let cells = side * side
        var state = seed
        func octave(_ radius: Double) -> [[Double]] {
            (0..<3).map { _ in normalized(blurred(whiteNoise(cells, &state), radius: radius)) }
        }
        let fine = octave(grain.size)
        // A grain with no second octave draws none, so its first is the same whatever the second's size.
        let coarse = grain.secondOctaveWeight > 0 ? octave(grain.size * grain.secondOctaveSize) : fine
        func mixed(_ first: [Double], _ firstShare: Double, _ second: [Double], _ secondShare: Double) -> [Double] {
            var result = [Double](repeating: 0, count: cells)
            var firstShare = firstShare, secondShare = secondShare
            vDSP_vsmsmaD(first, 1, &firstShare, second, 1, &secondShare, &result, 1, vDSP_Length(cells))
            return result
        }
        var layers = (0..<3).map { normalized(mixed(fine[$0], 1, coarse[$0], grain.secondOctaveWeight)) }
        let common = layers[1]
        layers = layers.map { normalized(mixed($0, 1 - grain.shared, common, grain.shared)) }
        var values = [Float](repeating: 1, count: cells * 4)
        for cell in 0..<cells {
            values[cell * 4] = Float(layers[0][cell]); values[cell * 4 + 1] = Float(layers[1][cell])
            values[cell * 4 + 2] = Float(layers[2][cell])
        }
        return values
    }

    private static func whiteNoise(_ count: Int, _ state: inout UInt64) -> [Double] {
        func uniform() -> Double {
            state = state &+ 0x9e37_79b9_7f4a_7c15
            var value = (state ^ (state >> 30)) &* 0xbf58_476d_1ce4_e5b9
            value = (value ^ (value >> 27)) &* 0x94d0_49bb_1331_11eb
            value ^= value >> 31
            return (Double(value >> 11) + 0.5) / Double(UInt64(1) << 53)
        }
        var noise = [Double](repeating: 0, count: count)
        var index = 0
        while index < count {
            // Two normal draws from two uniform ones.
            let radius = (-2 * log(uniform())).squareRoot(), angle = 2 * Double.pi * uniform()
            noise[index] = radius * cos(angle)
            if index + 1 < count { noise[index + 1] = radius * sin(angle) }
            index += 2
        }
        return noise
    }

    /// A Gaussian blur of the tile that wraps around its edges, so the tile still repeats seamlessly.
    private static func blurred(_ values: [Double], radius: Double) -> [Double] {
        guard radius > 0.01 else { return values }
        let reach = max(1, Int((4 * radius).rounded(.up)))
        var kernel = (-reach...reach).map { exp(-0.5 * Double($0 * $0) / (radius * radius)) }
        let total = kernel.reduce(0, +)
        kernel = kernel.map { $0 / total }
        // Each row, with its far end ahead of it and its near end after it, against the kernel.
        func across(_ source: [Double]) -> [Double] {
            var result = [Double](repeating: 0, count: source.count)
            var padded = [Double](repeating: 0, count: side + 2 * reach)
            source.withUnsafeBufferPointer { input in
                result.withUnsafeMutableBufferPointer { output in
                    padded.withUnsafeMutableBufferPointer { row in
                        for index in 0..<side {
                            let start = input.baseAddress! + index * side
                            row.baseAddress!.update(from: start + side - reach, count: reach)
                            (row.baseAddress! + reach).update(from: start, count: side)
                            (row.baseAddress! + reach + side).update(from: start, count: reach)
                            vDSP_convD(row.baseAddress!, 1, kernel, 1, output.baseAddress! + index * side, 1,
                                       vDSP_Length(side), vDSP_Length(kernel.count))
                        }
                    }
                }
            }
            return result
        }
        func turned(_ source: [Double]) -> [Double] {
            var result = [Double](repeating: 0, count: source.count)
            vDSP_mtransD(source, 1, &result, 1, vDSP_Length(side), vDSP_Length(side))
            return result
        }
        return turned(across(turned(across(values))))
    }

    private static func normalized(_ values: [Double]) -> [Double] {
        var result = [Double](repeating: 0, count: values.count)
        var mean = 0.0, deviation = 0.0
        vDSP_normalizeD(values, 1, &result, 1, &mean, &deviation, vDSP_Length(values.count))
        return result
    }
}
