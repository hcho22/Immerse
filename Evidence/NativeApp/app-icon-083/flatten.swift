// Redraws a PNG into an opaque RGB bitmap, so the icon file carries no alpha channel.
// Usage: xcrun swift flatten.swift <input.png> <output.png>
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: flatten.swift <input.png> <output.png>\n".utf8))
    exit(2)
}
let input = URL(fileURLWithPath: arguments[1])
let output = URL(fileURLWithPath: arguments[2])

guard let source = CGImageSourceCreateWithURL(input as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
      let space = CGColorSpace(name: CGColorSpace.sRGB),
      let context = CGContext(
          data: nil,
          width: image.width,
          height: image.height,
          bitsPerComponent: 8,
          bytesPerRow: 0,
          space: space,
          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
      )
else {
    FileHandle.standardError.write(Data("cannot read \(input.path)\n".utf8))
    exit(1)
}
let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
context.fill(bounds)
context.draw(image, in: bounds)

guard let flattened = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)
else {
    FileHandle.standardError.write(Data("cannot write \(output.path)\n".utf8))
    exit(1)
}
CGImageDestinationAddImage(destination, flattened, nil)
guard CGImageDestinationFinalize(destination) else {
    FileHandle.standardError.write(Data("cannot write \(output.path)\n".utf8))
    exit(1)
}
