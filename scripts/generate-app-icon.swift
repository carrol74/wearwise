import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else { fatalError("Usage: swift scripts/generate-app-icon.swift <output.png>") }
let output = URL(fileURLWithPath: CommandLine.arguments[1])
guard let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
    bytesPerRow: 4096, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fatalError("Could not create the app icon graphics context.")
}
let graphics = NSGraphicsContext(cgContext: context, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphics
NSColor(srgbRed: 255 / 255, green: 255 / 255, blue: 255 / 255, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: 1024, height: 1024).fill()
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
guard let font = NSFont(name: "Georgia-Italic", size: 800) else { fatalError("Georgia Italic is required for the Wearwise wordmark.") }
("w" as NSString).draw(in: NSRect(x: 0, y: 80, width: 1024, height: 970), withAttributes: [
    .font: font, .paragraphStyle: paragraph,
    .foregroundColor: NSColor(srgbRed: 53 / 255, green: 88 / 255, blue: 114 / 255, alpha: 1)
])
NSGraphicsContext.restoreGraphicsState()
guard let image = context.makeImage(), let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
    fatalError("App icon PNG rendering failed.")
}
try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
try png.write(to: output, options: .atomic)
