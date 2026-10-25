import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision

guard CommandLine.arguments.count == 3 else {
    fatalError("Usage: swift extract-garment-materials.swift INPUT_FILE_OR_DIRECTORY OUTPUT_DIRECTORY")
}
let input = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let files = try input.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
    ? FileManager.default.contentsOfDirectory(at: input, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    : [input]
guard !files.isEmpty else { fatalError("The input directory contains no material images.") }
let imageDirectory = output.appending(path: "images")
try FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
let context = CIContext()
var results: [[String: Any]] = []

for file in files {
    try autoreleasepool {
        FileHandle.standardOutput.write(Data("Extracting: \(file.lastPathComponent)\n".utf8))
        guard let source = CGImageSourceCreateWithURL(file as CFURL, nil),
              let decoded = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            fatalError("Unreadable image: \(file.lastPathComponent)")
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let orientation = (properties?[kCGImagePropertyOrientation] as? NSNumber)?.int32Value ?? 1
        let oriented = CIImage(cgImage: decoded).oriented(forExifOrientation: orientation)
        guard let image = context.createCGImage(oriented, from: oriented.extent) else {
            fatalError("Orientation normalization failed: \(file.lastPathComponent)")
        }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        guard let observation = request.results?.first, !observation.allInstances.isEmpty else {
            fatalError("No foreground instance: \(file.lastPathComponent)")
        }
        let buffer = try observation.generateMaskedImage(ofInstances: observation.allInstances,
            from: handler, croppedToInstancesExtent: true)
        let masked = CIImage(cvPixelBuffer: buffer)
        guard let cutout = context.createCGImage(masked, from: masked.extent) else {
            fatalError("Mask application failed: \(file.lastPathComponent)")
        }
        var pixels = [UInt8](repeating: 0, count: cutout.width * cutout.height * 4)
        pixels.withUnsafeMutableBytes { bytes in
            let bitmap = CGContext(data: bytes.baseAddress, width: cutout.width, height: cutout.height,
                bitsPerComponent: 8, bytesPerRow: cutout.width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)!
            bitmap.draw(cutout, in: CGRect(x: 0, y: 0, width: cutout.width, height: cutout.height))
        }
        let transparent = stride(from: 3, to: pixels.count, by: 4).count { pixels[$0] < 32 }
        let opaque = stride(from: 3, to: pixels.count, by: 4).count { pixels[$0] > 224 }
        guard transparent > 0, opaque > 0 else {
            fatalError("Cutout must contain transparent background and visible foreground: \(file.lastPathComponent)")
        }
        let target = imageDirectory.appending(path: file.deletingPathExtension().lastPathComponent + ".png")
        let destination = CGImageDestinationCreateWithURL(target as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, cutout, nil)
        guard CGImageDestinationFinalize(destination) else { fatalError("PNG write failed: \(target.path)") }
        results.append(["source": file.lastPathComponent, "file": target.lastPathComponent,
            "width": cutout.width, "height": cutout.height, "instances": observation.allInstances.count,
            "transparentPixels": transparent, "opaquePixels": opaque])
        try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appending(path: "extraction.json"), options: .atomic)
    }
}
print("Extracted \(results.count) images using macOS Vision. Review subject boundaries visually before acceptance.")
