import CoreImage
import Foundation

/// Reading a negative film's color table between its tones tetrahedrally: the cell around a tone is cut into six
/// tetrahedra along its diagonal from black to white, and the reading is the straight blend of the four corners of
/// the one the tone is in. It is how the captain's spec reads his table, and it keeps a gray exactly gray's own
/// reading, a straight line between the table's grays, where a film's color changes begin sharply at gray.
///
/// Core Image's own color cube reads along each axis instead, which lets the colors beside a gray into its reading:
/// up to 0.009 off the table's on grays, with a faint tint. So the table is read here by a small kernel of Core
/// Image's, written in Metal and made when Development first needs it, and by nothing else: where Core Image cannot
/// make or run it, a renderer without Metal, a film with a table does not develop
/// (`NativeRenderError.tableReaderUnavailable`).
///
/// A kernel is kept, for the life of the process, only once it has proved itself. One that could not be made or did
/// not prove is not remembered, so the next read makes and proves again: a proof is a render, and a render that
/// failed once must not stop every later Development. A renderer that has no kernel fails every time.
final class TableReading: @unchecked Sendable {
    /// The reader every Development reads with.
    static let shared = TableReading()

    private let lock = NSLock()
    private var proved: CIKernel?
    private let make: () -> CIKernel?

    /// - Parameter make: a kernel that has proved itself, or nil. Tests give one that fails.
    init(make: @escaping () -> CIKernel? = TableReading.provedKernel) {
        self.make = make
    }

    /// The kernel, proved against the same reading done in Swift, or nil where it cannot be made or does not prove.
    /// Readers asking at once make one between them.
    var kernel: CIKernel? {
        lock.lock()
        defer { lock.unlock() }
        if proved == nil { proved = make() }
        return proved
    }

    /// A kernel made now and proved, or nil.
    static func provedKernel() -> CIKernel? {
        guard let made = try? CIKernel.kernels(withMetalString: source).first(where: { $0.name == "readTetrahedrally" }),
              proves(made) else { return nil }
        return made
    }

    /// A table as an image for the kernel: `side` squares in a row, red across each square, green up it and blue
    /// from square to square, read at exactly one of its tones at a time.
    static func image(of table: [FilmLook.RGB], side: Int) -> CIImage {
        let width = side * side
        var values = [Float](repeating: 1, count: width * side * 4)
        for blue in 0..<side { for green in 0..<side { for red in 0..<side {
            let color = table[(blue * side + green) * side + red]
            // The image's rows run from its top, and the kernel counts up from its bottom.
            let index = ((side - 1 - green) * width + blue * side + red) * 4
            values[index] = Float(color.red); values[index + 1] = Float(color.green); values[index + 2] = Float(color.blue)
        } } }
        return CIImage(bitmapData: values.withUnsafeBufferPointer { Data(buffer: $0) }, bytesPerRow: width * 16,
                       size: CGSize(width: width, height: side), format: .RGBAf, colorSpace: nil).samplingNearest()
    }

    /// The picture read through a table, each of whose tones is asked for by a value from 0 to 1. Throws where there
    /// is no kernel to read it.
    func read(_ image: CIImage, table: CIImage, side: Int) throws -> CIImage {
        guard let kernel, let read = Self.apply(kernel, to: image, table: table, side: side) else {
            throw NativeRenderError.tableReaderUnavailable
        }
        return read
    }

    private static func apply(_ kernel: CIKernel, to image: CIImage, table: CIImage, side: Int) -> CIImage? {
        kernel.apply(extent: image.extent, roiCallback: { index, rectangle in index == 1 ? table.extent : rectangle },
                     arguments: [image, table, Float(side)])
    }

    /// Whether the kernel reads a small table as the same reading in Swift does: at its tones, between them in each
    /// of the six tetrahedra, and beyond its ends. A renderer that cannot run the kernel gives nothing like it.
    private static func proves(_ kernel: CIKernel) -> Bool {
        let side = 3
        var table: [FilmLook.RGB] = []
        for blue in 0..<side { for green in 0..<side { for red in 0..<side {
            // No two tones alike, and nothing a straight line along one axis would give.
            let mix = Double(red * 7 + green * 3 + blue * 5 + red * green * blue)
            table.append(FilmLook.RGB(0.05 + mix / 60, 0.9 - Double(red * red + blue) / 12, 0.2 + Double(green * blue + red) / 9))
        } } }
        let asked: [FilmLook.RGB] = [
            .init(0, 0, 0), .init(1, 1, 1), .init(0.5, 0.5, 0.5), .init(1, 0, 0.5), .init(0.3, 0.2, 0.1), .init(0.3, 0.1, 0.2),
            .init(0.1, 0.3, 0.2), .init(0.2, 0.3, 0.1), .init(0.1, 0.2, 0.3), .init(0.2, 0.1, 0.3), .init(0.9, 0.6, 0.75),
            .init(0.26, 0.26, 0.26), .init(-0.2, 1.4, 0.5)
        ]
        var pixels: [Float] = []
        for tone in asked { pixels += [Float(tone.red), Float(tone.green), Float(tone.blue), 1] }
        let picture = CIImage(bitmapData: pixels.withUnsafeBufferPointer { Data(buffer: $0) }, bytesPerRow: asked.count * 16,
                              size: CGSize(width: asked.count, height: 1), format: .RGBAf, colorSpace: nil)
        guard let read = apply(kernel, to: picture, table: image(of: table, side: side), side: side) else { return false }
        var result = [Float](repeating: 0, count: asked.count * 4)
        CIContext(options: [.cacheIntermediates: false]).render(
            read, toBitmap: &result, rowBytes: asked.count * 16, bounds: CGRect(x: 0, y: 0, width: asked.count, height: 1),
            format: .RGBAf, colorSpace: nil)
        for (index, tone) in asked.enumerated() {
            let want = FilmLook.NegativeFilm.tetrahedral(table, side: side, at: tone)
            for (channel, value) in [want.red, want.green, want.blue].enumerated() {
                guard abs(Double(result[index * 4 + channel]) - value) < 0.002 else { return false }
            }
        }
        return true
    }

    private static let source = """
    #include <CoreImage/CoreImage.h>
    using namespace metal;

    // One tone of the table, which is laid out as `side` squares in a row: red across each square, green up it and
    // blue from square to square.
    static inline float3 tone(coreimage::sampler table, float3 cell, float side) {
        float2 place = float2(cell.r + cell.b * side + 0.5, cell.g + 0.5);
        return table.sample(table.transform(place)).rgb;
    }

    [[stitchable]] float4 readTetrahedrally(coreimage::sampler image, coreimage::sampler table, float side,
                                            coreimage::destination destination) {
        float4 pixel = image.sample(image.coord());
        float3 position = clamp(pixel.rgb, 0.0, 1.0) * (side - 1.0);
        float3 cell = min(floor(position), side - 2.0);
        float3 part = position - cell;
        // From black, the largest part is stepped along first, then the next, then the smallest, to white.
        float3 first, second;
        float4 weights;
        if (part.r > part.g) {
            if (part.g > part.b) {
                first = float3(1.0, 0.0, 0.0); second = float3(1.0, 1.0, 0.0);
                weights = float4(1.0 - part.r, part.r - part.g, part.g - part.b, part.b);
            } else if (part.r > part.b) {
                first = float3(1.0, 0.0, 0.0); second = float3(1.0, 0.0, 1.0);
                weights = float4(1.0 - part.r, part.r - part.b, part.b - part.g, part.g);
            } else {
                first = float3(0.0, 0.0, 1.0); second = float3(1.0, 0.0, 1.0);
                weights = float4(1.0 - part.b, part.b - part.r, part.r - part.g, part.g);
            }
        } else {
            if (part.b > part.g) {
                first = float3(0.0, 0.0, 1.0); second = float3(0.0, 1.0, 1.0);
                weights = float4(1.0 - part.b, part.b - part.g, part.g - part.r, part.r);
            } else if (part.b > part.r) {
                first = float3(0.0, 1.0, 0.0); second = float3(0.0, 1.0, 1.0);
                weights = float4(1.0 - part.g, part.g - part.b, part.b - part.r, part.r);
            } else {
                first = float3(0.0, 1.0, 0.0); second = float3(1.0, 1.0, 0.0);
                weights = float4(1.0 - part.g, part.g - part.r, part.r - part.b, part.b);
            }
        }
        float3 read = weights.x * tone(table, cell, side) + weights.y * tone(table, cell + first, side)
            + weights.z * tone(table, cell + second, side) + weights.w * tone(table, cell + float3(1.0), side);
        return float4(read, 1.0);
    }
    """
}
