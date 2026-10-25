import CoreGraphics
import CoreImage
import CoreML
import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision
import UIKit

struct ImportCandidate: Sendable {
    let originalPNG: Data
    let pixelWidth: Int
    let pixelHeight: Int
}

struct ProcessedImport: Sendable {
    let original: ImportCandidate
    let cutoutPNG: Data
    let cutoutWidth: Int
    let cutoutHeight: Int
    let suggestedColors: [String]
}

enum ImageImportError: LocalizedError, Equatable {
    case undecodable
    case noSubjectFound
    case maskApplicationFailed
    case colorAnalysisFailed
    case unsupportedComputeDevice

    var errorDescription: String? {
        switch self {
        case .undecodable: "The selected file is not a readable PNG, JPEG, or WebP image."
        case .noSubjectFound: "No subject was detected in the image. Try a photo with the garment clearly visible."
        case .maskApplicationFailed: "The cutout could not be produced. Please retry."
        case .colorAnalysisFailed: "Colors could not be read from the cutout. Please retry."
        case .unsupportedComputeDevice: "This simulator cannot execute the image model on a supported CPU device. Use a physical iPhone."
        }
    }
}

enum ImageImportService {
    static func process(_ data: Data) async throws -> ProcessedImport {
        let work = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            return try processImage(data)
        }
        return try await withTaskCancellationHandler {
            try await work.value
        } onCancel: {
            work.cancel()
        }
    }

    static func normalizedPNG(from data: Data) throws -> Data {
        try pngData(from: decodedImage(data))
    }

    private static func decodedImage(_ data: Data) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw ImageImportError.undecodable
        }

        return try normalizedOrientation(cgImage, source: source)
    }

    private static func processImage(_ data: Data) throws -> ProcessedImport {
        let oriented = try decodedImage(data)
        let originalPNG = try pngData(from: oriented)

        let cutout = try generateCutout(from: oriented)
        try Task.checkCancellation()
        let cutoutPNG = try pngData(from: cutout)

        let colors = try dominantColors(in: cutout)

        return ProcessedImport(
            original: ImportCandidate(
                originalPNG: originalPNG,
                pixelWidth: oriented.width,
                pixelHeight: oriented.height
            ),
            cutoutPNG: cutoutPNG,
            cutoutWidth: cutout.width,
            cutoutHeight: cutout.height,
            suggestedColors: colors
        )
    }

    static func pngData(from image: CGImage) throws -> Data {
        let output = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil)
        else { throw ImageImportError.maskApplicationFailed }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw ImageImportError.maskApplicationFailed }
        return output as Data
    }

    private static func normalizedOrientation(_ image: CGImage, source: CGImageSource) throws -> CGImage {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let orientation = (properties?[kCGImagePropertyOrientation] as? NSNumber)?.int32Value ?? 1
        let oriented = CIImage(cgImage: image).oriented(forExifOrientation: orientation)
        guard let output = CIContext().createCGImage(oriented, from: oriented.extent) else {
            throw ImageImportError.undecodable
        }
        return output
    }

    private static func generateCutout(from image: CGImage) throws -> CGImage {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try configureComputeDevice(request)
            try handler.perform([request])
        } catch {
            throw ImageAnalysisFailure(stage: "Foreground extraction", error: error)
        }

        guard let observation = request.results?.first,
              observation.allInstances.count > 0
        else { throw ImageImportError.noSubjectFound }

        let maskedBuffer: CVPixelBuffer
        do {
            maskedBuffer = try observation.generateMaskedImage(
                ofInstances: observation.allInstances,
                from: handler,
                croppedToInstancesExtent: true
            )
        } catch {
            throw ImageImportError.maskApplicationFailed
        }

        let ciImage = CIImage(cvPixelBuffer: maskedBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            throw ImageImportError.maskApplicationFailed
        }
        return cgImage
    }

    private static func configureComputeDevice(_ request: VNRequest) throws {
        #if targetEnvironment(simulator)
        for (stage, devices) in try request.supportedComputeStageDevices {
            guard let cpu = devices.first(where: { if case .cpu = $0 { return true }; return false }) else {
                throw ImageImportError.unsupportedComputeDevice
            }
            request.setComputeDevice(cpu, for: stage)
        }
        #endif
    }

    private static func dominantColors(in image: CGImage) throws -> [String] {
        let pixels = try colorHistogram(from: image)
        var frequencies: [String: Int] = [:]
        for pixel in pixels where pixel.alpha > 128 {
            let alpha = Double(pixel.alpha) / 255
            let color = UIColor(
                red: CGFloat(min(1, Double(pixel.red) / 255 / alpha)),
                green: CGFloat(min(1, Double(pixel.green) / 255 / alpha)),
                blue: CGFloat(min(1, Double(pixel.blue) / 255 / alpha)),
                alpha: 1
            )
            var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, opacity: CGFloat = 0
            color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &opacity)
            let name: String
            if brightness < 0.22 { name = "black" }
            else if saturation < 0.16 { name = brightness > 0.85 ? "white" : "gray" }
            else if hue < 0.05 || hue >= 0.95 { name = "red" }
            else if hue < 0.11 { name = brightness < 0.6 ? "brown" : "orange" }
            else if hue < 0.18 { name = "yellow" }
            else if hue < 0.45 { name = "green" }
            else if hue < 0.70 { name = "blue" }
            else if hue < 0.89 { name = "purple" }
            else { name = "pink" }
            frequencies[name, default: 0] += 1
        }
        let visible = frequencies.values.reduce(0, +)
        guard visible > 0 else { throw ImageImportError.colorAnalysisFailed }
        return frequencies.filter { $0.value * 20 >= visible }
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .prefix(3).map(\.key)
    }

    private struct Pixel {
        var red: UInt8
        var green: UInt8
        var blue: UInt8
        var alpha: UInt8
    }

    private static func colorHistogram(from image: CGImage) throws -> [Pixel] {
        let width = 96, height = 96
        var pixels = [Pixel](repeating: Pixel(red: 0, green: 0, blue: 0, alpha: 0), count: width * height)
        try pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            ) else { throw ImageImportError.colorAnalysisFailed }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return pixels
    }
}

struct ImageAnalysisFailure: LocalizedError {
    let stage: String
    let domain: String
    let code: Int
    let reason: String

    init(stage: String, error: Error) {
        let underlying = error as NSError
        self.stage = stage
        domain = underlying.domain
        code = underlying.code
        reason = underlying.localizedDescription
    }

    var errorDescription: String? {
        "\(stage) failed: \(reason) (\(domain), \(code))."
    }
}
