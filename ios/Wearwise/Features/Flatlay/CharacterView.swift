import CryptoKit
import ImageIO
import OSLog
import SwiftData
import SwiftUI
import UIKit

enum FaceShape: String, Codable, CaseIterable, Sendable { case oval, round, square, heart, diamond, long, rectangular, triangle }
enum EyeShape: String, Codable, CaseIterable, Sendable {
    case round, almond, sleepy, wide, monolid, hooded, upturned, downturned, deepSet, doubleFold, longFissure, softOval
    var title: String {
        switch self {
        case .deepSet: "Deep set"
        case .doubleFold: "Double fold"
        case .longFissure: "Elongated"
        case .softOval: "Soft oval"
        default: rawValue.capitalized
        }
    }
}
enum NoseShape: String, Codable, CaseIterable, Sendable { case soft, defined, broad, button, straight, aquiline, rounded, wideBridge }
enum BodyBuild: String, Codable, CaseIterable, Sendable { case slender, medium, full }
enum LimbBuild: String, Codable, CaseIterable, Sendable { case slender, medium, full, lean, athletic, muscular }
enum CharacterHeight: String, Codable, CaseIterable, Sendable { case petite, medium, tall }
enum PartLength: String, Codable, CaseIterable, Sendable { case short, medium, long }
enum ShoulderWidth: String, Codable, CaseIterable, Sendable { case narrow, medium, broad }
enum CharacterGender: String, Codable, CaseIterable, Sendable { case female, male }
enum BodySilhouette: String, Codable, CaseIterable, Sendable {
    case straight, balanced, curved, pear, broad, athletic, muscular
    var proportions: (CGFloat, CGFloat, CGFloat) {
        switch self {
        case .straight: (25, 21, 21)
        case .balanced: (24, 17, 23)
        case .curved: (24, 12, 26)
        case .pear: (21, 17, 29)
        case .broad: (31, 19, 21)
        case .athletic: (34, 22, 20)
        case .muscular: (38, 26, 22)
        }
    }
}
enum FacialStructure: String, Codable, CaseIterable, Sendable { case soft, balanced, defined }
enum EyeSize: String, Codable, CaseIterable, Sendable { case small, medium, large }
enum HairTreatment: String, Codable, CaseIterable, Sendable { case solid, ombre }
enum MouthShape: String, Codable, CaseIterable, Sendable { case neutral, smile, grin, openSmile, pout, frown, smirk, open }
enum HairLengthGroup: String, CaseIterable, Sendable { case short = "Short", medium = "Medium", long = "Long" }
enum HairStyle: String, Codable, CaseIterable, Sendable {
    case texturedCrop, texturedSlickBack, slickUndercut
    case cropped, pixie, sidePart, quiff, curls, afro, fade, buzzCut, shaved, bald
    case mediumCurls, curtains, broFlow
    case bob, bluntBob, lob, shag, curlyBob
    case longSlickBack, lowManBun
    case long, wavy, curlyLong, straightFringe, ponytail, lowPonytail, bun, braids, locs, sideBraid, twinPuffs
    var group: HairLengthGroup {
        switch self {
        case .texturedCrop, .texturedSlickBack, .slickUndercut, .cropped, .pixie, .sidePart, .quiff, .curls, .afro, .fade, .buzzCut, .shaved, .bald: .short
        case .mediumCurls, .curtains, .broFlow, .bob, .bluntBob, .lob, .shag, .curlyBob: .medium
        default: .long
        }
    }
    static let additions: [Self] = [.texturedCrop, .texturedSlickBack, .slickUndercut, .mediumCurls, .curtains, .broFlow, .longSlickBack, .lowManBun]
    var end: CGFloat {
        switch self {
        case .bob: 62
        case .bluntBob: 63
        case .lob: 79
        case .shag: 72
        case .curlyBob: 70
        case .long, .straightFringe: 91
        case .wavy: 94
        case .curlyLong, .locs: 99
        case .ponytail: 90
        case .lowPonytail: 97
        case .braids: 92
        case .sideBraid: 98
        case .twinPuffs: 63
        default: 43
        }
    }
    var title: String {
        rawValue.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).capitalized
    }
}
enum BeardStyle: String, Codable, CaseIterable, Sendable {
    case none, stubble, moustache, handlebar, goatee, shortBeard, fullBeard, longBeard
    var title: String {
        switch self {
        case .shortBeard: "Short beard"
        case .fullBeard: "Full beard"
        case .longBeard: "Long beard"
        default: rawValue.capitalized
        }
    }
}
enum EyebrowShape: String, Codable, CaseIterable, Sendable { case soft, straight, arched, bushy }
enum LipShape: String, Codable, CaseIterable, Sendable { case natural, full, thin }
enum Earrings: String, Codable, CaseIterable, Sendable { case none, studs, hoops }

enum CharacterFraming: String, Codable, Hashable, Sendable {
    case body, arms, legs, hair, face
    var bounds: CGRect {
        switch self {
        case .body: CGRect(x: 0, y: -18, width: 160, height: 240)
        case .arms: CGRect(x: 8, y: 50, width: 144, height: 116)
        case .legs: CGRect(x: 26, y: 90, width: 108, height: 144)
        case .hair: CGRect(x: 28, y: -18, width: 104, height: 130)
        case .face: CGRect(x: 48, y: 3, width: 64, height: 82)
        }
    }
}

enum FaceFeature: String, CaseIterable, Sendable {
    case shape = "Shape", eyes = "Eyes", brows = "Brows", nose = "Nose", mouth = "Mouth"
    var symbol: String {
        switch self {
        case .shape: "person.crop.square"
        case .eyes: "eye"
        case .brows: "eyebrow"
        case .nose: "nose"
        case .mouth: "mouth"
        }
    }
}

enum CharacterSection: String, CaseIterable, Sendable {
    case body = "Body", arms = "Arms", legs = "Legs", hairstyle = "Hair"
    case face = "Face", beard = "Beard"

    var framing: CharacterFraming {
        switch self {
        case .body: .body
        case .arms: .arms
        case .legs: .legs
        case .hairstyle: .hair
        default: .face
        }
    }

    var symbol: String {
        switch self {
        case .body: "figure.stand"
        case .arms: "hand.raised"
        case .legs: "figure.walk"
        case .hairstyle: "scissors"
        case .face: "face.smiling"
        case .beard: "mustache"
        }
    }
}

struct CharacterColor: Identifiable {
    let name: String
    let value: UInt32
    var id: UInt32 { value }

    static let skin: [Self] = [
        .init(name: "Porcelain", value: 0xF7DFD0), .init(name: "Light peach", value: 0xF1D2BE),
        .init(name: "Warm beige", value: 0xE9AE80), .init(name: "Golden tan", value: 0xC58E6B),
        .init(name: "Warm brown", value: 0xA76F4C), .init(name: "Deep brown", value: 0x87573E),
        .init(name: "Dark brown", value: 0x6F4835), .init(name: "Rich brown", value: 0x493328)
    ]
    static let hair: [Self] = [
        .init(name: "Black", value: 0x252526), .init(name: "Brown", value: 0x493B30),
        .init(name: "Auburn", value: 0xA27550), .init(name: "Blonde", value: 0xCBA464),
        .init(name: "Copper", value: 0xAF633F), .init(name: "Silver", value: 0xB7B8BE),
        .init(name: "Blue black", value: 0x303D59)
    ]
}

struct CharacterAppearance: Codable, Hashable, Sendable {
    var skin: UInt32 = 0xE9AE80
    var hair: UInt32 = 0x493226
    var hairAccent: UInt32 = 0xCBA464
    var hairTreatment: HairTreatment = .solid
    var iris: UInt32 = 0x684B36
    var silhouette: BodySilhouette = .balanced
    var facialStructure: FacialStructure = .soft
    var eyeSize: EyeSize = .medium
    var mouth: MouthShape = .smile
    var gender: CharacterGender = .female
    var hairstyle: HairStyle = .long
    var beard: BeardStyle = .none
    var beardColor: UInt32 = 0x493226
    var eyebrows: EyebrowShape = .soft
    var lips: LipShape = .natural
    var earrings: Earrings = .none
    var necklace = false
    var longHair: Bool {
        get { hairstyle.group == .long }
        set { hairstyle = newValue ? .long : .cropped }
    }
    var glasses = false
    var smiling = true
    var faceShape: FaceShape = .oval
    var eyes: EyeShape = .round
    var nose: NoseShape = .soft
    var build: BodyBuild = .medium
    var height: CharacterHeight = .medium
    var shoulders: ShoulderWidth = .medium
    var torsoLength: PartLength = .medium
    var armLength: PartLength = .medium
    var armBuild: LimbBuild = .medium
    var legBuild: LimbBuild = .medium

    init() {}

    enum CodingKeys: String, CodingKey {
        case skin, hair, gender, hairstyle, eyebrows, lips, earrings, necklace
        case hairAccent, hairTreatment, iris, silhouette, facialStructure, eyeSize, mouth
        case glasses, smiling, faceShape, eyes, nose, build, height, shoulders
        case beard, beardColor, torsoLength, armLength, armBuild, legBuild
    }
    private enum LegacyKeys: String, CodingKey { case longHair }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        skin = try values.decodeIfPresent(UInt32.self, forKey: .skin) ?? skin
        hair = try values.decodeIfPresent(UInt32.self, forKey: .hair) ?? hair
        gender = try values.decodeIfPresent(CharacterGender.self, forKey: .gender) ?? gender
        hairAccent = try values.decodeIfPresent(UInt32.self, forKey: .hairAccent) ?? hairAccent
        if let treatment = try values.decodeIfPresent(String.self, forKey: .hairTreatment) {
            if treatment == "highlights" { hairTreatment = .solid }
            else if let value = HairTreatment(rawValue: treatment) { hairTreatment = value }
            else { throw DecodingError.dataCorruptedError(forKey: .hairTreatment, in: values, debugDescription: "Unsupported hair treatment.") }
        }
        iris = try values.decodeIfPresent(UInt32.self, forKey: .iris) ?? iris
        silhouette = try values.decodeIfPresent(BodySilhouette.self, forKey: .silhouette) ?? (gender == .male ? .straight : .balanced)
        facialStructure = try values.decodeIfPresent(FacialStructure.self, forKey: .facialStructure) ?? (gender == .male ? .defined : .soft)
        eyeSize = try values.decodeIfPresent(EyeSize.self, forKey: .eyeSize) ?? eyeSize
        if let style = try values.decodeIfPresent(HairStyle.self, forKey: .hairstyle) { hairstyle = style }
        else {
            let legacy = try decoder.container(keyedBy: LegacyKeys.self)
            longHair = try legacy.decodeIfPresent(Bool.self, forKey: .longHair) ?? true
        }
        eyebrows = try values.decodeIfPresent(EyebrowShape.self, forKey: .eyebrows) ?? eyebrows
        lips = try values.decodeIfPresent(LipShape.self, forKey: .lips) ?? lips
        earrings = try values.decodeIfPresent(Earrings.self, forKey: .earrings) ?? earrings
        necklace = try values.decodeIfPresent(Bool.self, forKey: .necklace) ?? necklace
        glasses = try values.decodeIfPresent(Bool.self, forKey: .glasses) ?? glasses
        smiling = try values.decodeIfPresent(Bool.self, forKey: .smiling) ?? smiling
        mouth = try values.decodeIfPresent(MouthShape.self, forKey: .mouth) ?? (smiling ? .smile : .neutral)
        faceShape = try values.decodeIfPresent(FaceShape.self, forKey: .faceShape) ?? faceShape
        eyes = try values.decodeIfPresent(EyeShape.self, forKey: .eyes) ?? eyes
        nose = try values.decodeIfPresent(NoseShape.self, forKey: .nose) ?? nose
        build = try values.decodeIfPresent(BodyBuild.self, forKey: .build) ?? build
        height = try values.decodeIfPresent(CharacterHeight.self, forKey: .height) ?? height
        shoulders = try values.decodeIfPresent(ShoulderWidth.self, forKey: .shoulders) ?? shoulders
        beard = try values.decodeIfPresent(BeardStyle.self, forKey: .beard) ?? beard
        beardColor = try values.decodeIfPresent(UInt32.self, forKey: .beardColor) ?? hair
        torsoLength = try values.decodeIfPresent(PartLength.self, forKey: .torsoLength) ?? torsoLength
        armLength = try values.decodeIfPresent(PartLength.self, forKey: .armLength) ?? armLength
        armBuild = try values.decodeIfPresent(LimbBuild.self, forKey: .armBuild) ?? armBuild
        legBuild = try values.decodeIfPresent(LimbBuild.self, forKey: .legBuild) ?? legBuild
    }
}

struct CharacterPreferences {
    var fileURL = URL.applicationSupportDirectory.appending(path: "WearwiseCharacter.json")
    var legacyDefaults: UserDefaults = .standard

    func load() throws -> CharacterAppearance {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return try JSONDecoder().decode(CharacterAppearance.self, from: Data(contentsOf: fileURL))
        }
        if let data = legacyDefaults.data(forKey: "wearwise.character") {
            return try JSONDecoder().decode(CharacterAppearance.self, from: data)
        }
        return CharacterAppearance()
    }

    func save(_ appearance: CharacterAppearance) throws {
        let data = try JSONEncoder().encode(appearance)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
        legacyDefaults.removeObject(forKey: "wearwise.character")
    }
}

struct IllustrationSprite: Decodable {
    let atlas: String
    let rect: [Int]
    let luminance: Double
    let anchor: [Double]?
    let placement: [Double]?
    let neck: [Double]?
    let shoulders: [[Double]]?
    let hips: [[Double]]?
    let hem: [Int]?
    let mouth: [Double]?
    let cuffs: [[Double]]?
    let section: [Double]?
    let densityReference: Double?
    let densityOpacity: Double?
    let faceOpening: [Double]?
    let layers: IllustrationHairRecipe?
    let mouthOpening: [[Double]?]?
}

private struct IllustrationManifest: Decodable {
    let sprites: [String: IllustrationSprite]
}

private final class IllustrationPixels: NSObject {
    let width: Int
    let height: Int
    let bytes: [UInt8]
    init(width: Int, height: Int, bytes: [UInt8]) {
        self.width = width; self.height = height; self.bytes = bytes
    }
}

struct IllustrationWarp {
    let pivot: Double
    let stops: [[Double]]
    var preserveOuter = false
    var outerGuard: Int?
}

struct IllustrationLayer {
    let id: String
    let frame: CGRect
    let color: UInt32
    var mode = "solid"
    var treatment: HairTreatment = .solid
    var accent: UInt32 = 0
    var legMasks: [IllustrationLayer] = []
    var scalpMask = false
    var thighSeam: Double?
    var warp: IllustrationWarp?
    var hairPart: String?
    var headAttachment: IllustrationAttachment?
    var mouthAttachment: IllustrationAttachment?
    var rearHair = false
    var templeCut = false
    var drawingFrame: CGRect { warp == nil || warp!.preserveOuter ? frame : frame.insetBy(dx: -frame.width / 2, dy: 0) }
}

struct IllustrationHairRecipe: Decodable {
    let rear: String
    let nape: Double
    let templeEnd: Double
    let rearInset: Double?
    let tailSide: String?
    let faceContour: Bool?
    let fitOpening: Bool?
    let outerGuard: Double?
    let templeCut: Bool?
    let sideburnEnd: Double?
}

struct IllustrationAttachment {
    let id: String
    let frame: CGRect
}

private final class IllustrationHairFit: NSObject {
    let warp: IllustrationWarp?
    init(_ warp: IllustrationWarp?) { self.warp = warp }
}

final class CharacterIllustrations: @unchecked Sendable {
    static let shared = CharacterIllustrations()
    let sprites: [String: IllustrationSprite]
    private let atlases: [String: CGImage]
    private let pixels = NSCache<NSString, IllustrationPixels>()
    private let painted = NSCache<NSString, UIImage>()
    private let hairFits = NSCache<NSString, IllustrationHairFit>()

    private init() {
        guard let asset = NSDataAsset(name: "CharacterParts") else { preconditionFailure("Missing character illustration manifest.") }
        do { sprites = try JSONDecoder().decode(IllustrationManifest.self, from: asset.data).sprites }
        catch { preconditionFailure("Invalid character illustration manifest: \(error)") }
        var images: [String: CGImage] = [:]
        for name in Set(sprites.values.map(\.atlas)) {
            guard let image = UIImage(named: "CharacterAtlas-" + name)?.cgImage else { preconditionFailure("Missing character atlas: \(name)") }
            images[name] = image
        }
        atlases = images
        hairFits.countLimit = 256
        pixels.countLimit = 128
        painted.countLimit = 256
        painted.totalCostLimit = 64 * 1024 * 1024
    }

    private func sourcePixels(_ id: String) -> IllustrationPixels {
        guard let sprite = sprites[id] else { preconditionFailure("Missing character component: \(id)") }
        if let cached = pixels.object(forKey: id as NSString) { return cached }
        else {
            let r = sprite.rect
            guard let crop = atlases[sprite.atlas]?.cropping(to: CGRect(x: r[0], y: r[1], width: r[2], height: r[3])) else { preconditionFailure("Invalid component crop: \(id)") }
            // Hair is drawn below 200 pixels in the editor and 640-pixel sticker exports.
            let scale = id.hasPrefix("hair/") ? min(1, 512 / Double(crop.width)) : 1
            let w = Int((Double(crop.width) * scale).rounded()), h = Int((Double(crop.height) * scale).rounded())
            var bytes = [UInt8](repeating: 0, count: w * h * 4)
            bytes.withUnsafeMutableBytes { storage in
                guard let context = CGContext(data: storage.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { preconditionFailure("Cannot decode character illustration.") }
                context.interpolationQuality = .high
                context.draw(crop, in: CGRect(x: 0, y: 0, width: w, height: h))
            }
            let raw = IllustrationPixels(width: w, height: h, bytes: bytes)
            pixels.setObject(raw, forKey: id as NSString)
            return raw
        }
    }

    private func bounds(_ pixels: IllustrationPixels, row: Int, threshold: UInt8 = 128) -> (Int, Int) {
        guard row >= 0 && row < pixels.height else { return (pixels.width, -1) }
        var left = pixels.width, right = -1
        for x in 0..<pixels.width where pixels.bytes[(row * pixels.width + x) * 4 + 3] >= threshold {
            left = min(left, x); right = x
        }
        return (left, right)
    }

    private func edges(_ bytes: [UInt8], width: Int, row: Int, split: Int, outer: UInt8, inner: UInt8) -> (Int, Int, Int, Int) {
        var left = -1, right = width, outerLeft = width, outerRight = -1
        for x in 0..<width {
            let alpha = bytes[(row * width + x) * 4 + 3]
            if alpha >= outer { outerLeft = min(outerLeft, x); outerRight = x }
            if alpha >= inner { if x < split { left = x } else { right = min(right, x) } }
        }
        return (left, right, outerLeft, outerRight)
    }

    private func fittedHair(head: IllustrationLayer, hair: IllustrationLayer) -> IllustrationWarp? {
        let key = "\(head.id)/\(head.frame)/\(hair.id)/\(hair.frame)" as NSString
        if let cached = hairFits.object(forKey: key) { return cached.warp }
        let scalp = sourcePixels(head.id), painted = sourcePixels(hair.id), recipe = sprites[hair.id]!.layers!
        let h = head.frame, f = hair.frame, axis = h.minX + h.width * sprites[head.id]!.neck![0]
        let pivot = (axis - f.minX) / f.width, split = Int(pivot * Double(painted.width))
        let guardWidth = recipe.outerGuard.map { Int(ceil($0 * Double(painted.width) / f.width)) }
        var result: IllustrationWarp?
        if recipe.faceContour == true {
            let fit = recipe.fitOpening == true, start = fit ? 0.25 : 0.35
            var rows: [(t: Double, left: Double?, right: Double?, targetLeft: Double?, targetRight: Double?)] = []
            for row in 0...painted.height {
                let t = Double(row) / Double(painted.height), y = f.minY + t * f.height
                let hy = Int(floor((y - h.minY) / h.height * Double(scalp.height)))
                var sample: (Double, Double?, Double?, Double?, Double?) = (t, nil, nil, nil, nil)
                if y >= h.minY + h.height * start, hy >= 0, hy < scalp.height, row < painted.height {
                    let (minX, maxX) = bounds(scalp, row: hy)
                    let (left, right, _, _) = edges(painted.bytes, width: painted.width, row: row, split: split, outer: 128, inner: 128)
                    if maxX >= minX && right - left - 1 > painted.width / 5 {
                        let inset = (fit ? 1.1 : 1.2) - min(1, max(0, (y - h.minY - h.height * 0.58) / (h.height * 0.16)))
                        let headLeft = max(h.minX + Double(minX) / Double(scalp.width) * h.width + inset, h.minX + h.width * 0.12)
                        let headRight = min(h.minX + Double(maxX + 1) / Double(scalp.width) * h.width - inset, h.minX + h.width * 0.88)
                        let hairLeft = f.minX + Double(left + 1) / Double(painted.width) * f.width
                        let hairRight = f.minX + Double(right) / Double(painted.width) * f.width
                        let blend = min(1, (y - h.minY - h.height * start) / 1.5)
                        sample = (t, hairLeft, hairRight, hairLeft + (fit ? headLeft - hairLeft : min(0, headLeft - hairLeft)) * blend, hairRight + (fit ? headRight - hairRight : max(0, headRight - hairRight)) * blend)
                    }
                }
                rows.append(sample)
            }
            let stops = rows.enumerated().map { index, row -> [Double] in
                guard let left = row.left, let right = row.right else { return [row.t, 1, 1] }
                let neighbors = rows[max(0, index - 4)..<min(rows.count, index + 5)].filter { $0.left != nil }
                let targetLeft = neighbors.reduce(0) { $0 + $1.targetLeft! } / Double(neighbors.count)
                let targetRight = neighbors.reduce(0) { $0 + $1.targetRight! } / Double(neighbors.count)
                return [row.t, max(fit ? 0 : 1, (axis - targetLeft) / (axis - left)), max(fit ? 0 : 1, (targetRight - axis) / (right - axis))]
            }
            result = IllustrationWarp(pivot: pivot, stops: stops, preserveOuter: true, outerGuard: guardWidth)
        } else {
            var left = 1.0, right = 1.0
            for y in stride(from: h.minY + h.height * 0.3, to: h.minY + h.height * 0.47, by: 0.25) {
                let hy = Int(floor((y - h.minY) / h.height * Double(scalp.height)))
                let py = Int(floor((y - f.minY) / f.height * Double(painted.height)))
                if py < 0 || py >= painted.height { continue }
                let (minX, maxX) = bounds(scalp, row: hy)
                let headLeft = h.minX + Double(minX) / Double(scalp.width) * h.width
                let headRight = h.minX + Double(maxX + 1) / Double(scalp.width) * h.width
                let (nearLeft, nearRight, _, _) = edges(painted.bytes, width: painted.width, row: py, split: split, outer: 128, inner: 128)
                if nearLeft >= 0 {
                    let edge = f.minX + Double(nearLeft + 1) / Double(painted.width) * f.width
                    if headLeft - edge > 0.35 { left = min(left, (axis - headLeft - 0.35) / (axis - edge)) }
                }
                if nearRight < painted.width {
                    let edge = f.minX + Double(nearRight) / Double(painted.width) * f.width
                    if edge - headRight > 0.35 { right = min(right, (headRight - axis - 0.35) / (edge - axis)) }
                }
            }
            func t(_ fraction: Double) -> Double { (h.minY + h.height * fraction - f.minY) / f.height }
            if left < 1 || right < 1 {
                result = IllustrationWarp(pivot: pivot, stops: [[0, 1, 1], [max(0, t(0.2)), 1, 1], [t(0.3), left, right], [t(0.47), left, right], [min(1, t(0.65)), 1, 1], [1, 1, 1]], preserveOuter: true, outerGuard: guardWidth)
            }
        }
        hairFits.setObject(IllustrationHairFit(result), forKey: key)
        return result
    }

    private func warpPreservingOuter(_ bytes: [UInt8], into output: inout [UInt8], raw: IllustrationPixels, row: Int, pivot: Double, left: Double, right: Double, guardWidth: Int?) {
        let split = Int(pivot), guardSize = Double(guardWidth ?? 3), width = raw.width
        let (leftIndex, innerRightIndex, first, last) = edges(raw.bytes, width: width, row: row, split: split, outer: guardWidth == nil ? 128 : 32, inner: 128)
        let innerLeft = Double(leftIndex + 1), innerRight = Double(innerRightIndex)
        let outerLeft = Double(min(split, first)), outerRight = Double(max(split, last + 1))
        func strip(_ start: Double, _ end: Double, _ destStart: Double, _ destEnd: Double, _ output: inout [UInt8]) {
            guard end > start, destEnd > destStart else { return }
            let minX = max(0, Int(ceil(destStart - 0.5))), maxX = min(width, Int(ceil(destEnd - 0.5)))
            guard maxX > minX else { return }
            for x in minX..<maxX {
                let source = start + (Double(x) + 0.5 - destStart) / (destEnd - destStart) * (end - start) - 0.5
                let low = Int(floor(source)), blend = source - floor(source)
                for c in 0..<4 {
                    let a = low >= 0 && low < width ? Double(bytes[(row * width + low) * 4 + c]) : 0
                    let b = low + 1 >= 0 && low + 1 < width ? Double(bytes[(row * width + low + 1) * 4 + c]) : 0
                    output[(row * width + x) * 4 + c] = UInt8(max(0, min(255, (a * (1 - blend) + b * blend).rounded())))
                }
            }
        }
        if left == 1 && right == 1 { strip(0, Double(width), 0, Double(width), &output); return }
        if innerLeft - outerLeft <= guardSize { strip(0, Double(split), 0, Double(split), &output) }
        else {
            let anchor = outerLeft + guardSize, fitted = max(anchor, Double(split) - (Double(split) - innerLeft) * left)
            strip(0, anchor, 0, anchor, &output); strip(anchor, innerLeft, anchor, fitted, &output); strip(innerLeft, Double(split), fitted, Double(split), &output)
        }
        if outerRight - innerRight <= guardSize { strip(Double(split), Double(width), Double(split), Double(width), &output) }
        else {
            let anchor = outerRight - guardSize, fitted = min(anchor, Double(split) + (innerRight - Double(split)) * right)
            strip(Double(split), innerRight, Double(split), fitted, &output); strip(innerRight, anchor, fitted, anchor, &output); strip(anchor, Double(width), anchor, Double(width), &output)
        }
    }

    private func rearPixels(_ bytes: [UInt8], raw: IllustrationPixels, layer: IllustrationLayer) -> [UInt8] {
        let head = layer.headAttachment!, h = head.frame, f = layer.frame, recipe = sprites[layer.id]!.layers!
        let split = Int(((80 - f.minX) / f.width * Double(raw.width)).rounded())
        let rows = (0..<raw.height).map { edges(bytes, width: raw.width, row: $0, split: split, outer: 64, inner: 220) }
        let scalp = recipe.rear == "scalp" ? sourcePixels(head.id) : nil
        let tail = recipe.tailSide == "right"
        var result = [UInt8](repeating: 0, count: bytes.count)
        func connected(_ edge: (Int, Int, Int, Int)) -> Bool { edge.1 < raw.width && (edge.0 >= 0 || tail) }
        for y in 0..<raw.height {
            let worldY = f.minY + (Double(y) + 0.5) / Double(raw.height) * f.height
            if worldY < h.minY + h.height * 0.15 || worldY >= h.minY + h.height * recipe.nape || rows[y].2 > rows[y].3 { continue }
            let start = max(0, y - 2), end = min(raw.height, y + 3)
            let neighbors = rows[start..<end].filter(connected)
            guard !neighbors.isEmpty else { continue }
            let left = neighbors.map { $0.0 >= 0 ? $0.0 : split }.min()!, right = neighbors.map(\.1).max()!
            let row = connected(rows[y]) ? y : (start..<end).first { connected(rows[$0]) }!
            let a = (row * raw.width + (rows[row].0 >= 0 ? rows[row].0 : rows[row].1)) * 4, b = (row * raw.width + rows[row].1) * 4
            var minX = Double(left - 3), maxX = Double(right + 3)
            if let inset = recipe.rearInset, inset != 0 {
                let outerLeft = neighbors.map(\.2).min()!, outerRight = neighbors.map(\.3).max()!
                let amount = Double(outerRight - outerLeft) * inset
                minX = min(minX, Double(outerLeft) + amount); maxX = max(maxX, Double(outerRight) - amount)
            }
            if tail { maxX = max(maxX, Double(neighbors.map(\.3).max()!)) }
            else { minX = max(minX, Double(rows[y].2)) }
            maxX = min(maxX, Double(rows[y].3))
            if let scalp {
                let hy = Int(floor((worldY - h.minY) / h.height * Double(scalp.height)))
                if hy < 0 || hy >= scalp.height {
                    if !tail || hy < 0 { continue }
                    minX = max(minX, Double(split))
                } else {
                    let (start, end) = bounds(scalp, row: hy)
                    minX = max(minX, tail && worldY >= h.minY + h.height * recipe.templeEnd ? Double(split) : (h.minX + Double(start) / Double(scalp.width) * h.width - 1.5 - f.minX) / f.width * Double(raw.width))
                    if !tail { maxX = min(maxX, (h.minX + Double(end + 1) / Double(scalp.width) * h.width + 1.5 - f.minX) / f.width * Double(raw.width)) }
                }
            }
            let first = max(0, Int(ceil(minX))), last = min(raw.width - 1, Int(floor(maxX)))
            guard first <= last else { continue }
            for x in first...last {
                let i = (y * raw.width + x) * 4, t = max(0, min(1, Double(x - left) / Double(right - left)))
                for c in 0..<3 {
                    let alphaA = max(1, Double(bytes[a + 3])), alphaB = max(1, Double(bytes[b + 3]))
                    let color = (Double(bytes[a + c]) * 255 / alphaA * (1 - t) + Double(bytes[b + c]) * 255 / alphaB * t) * 0.88
                    result[i + c] = UInt8(max(0, min(255, color.rounded())))
                }
                result[i + 3] = 255
            }
        }
        return result
    }

    private func trimTemples(_ bytes: inout [UInt8], raw: IllustrationPixels, layer: IllustrationLayer) {
        let head = layer.headAttachment!, h = head.frame, f = layer.frame, scalp = sourcePixels(head.id), recipe = sprites[layer.id]!.layers!
        func edge(_ fraction: Double) -> (Double, Double) {
            let (left, right) = bounds(scalp, row: Int(Double(scalp.height) * fraction))
            return (h.minX + Double(left) / Double(scalp.width) * h.width, h.minX + Double(right + 1) / Double(scalp.width) * h.width)
        }
        let upper = edge(0.39), lower = edge(0.76), axis = h.minX + h.width * sprites[head.id]!.neck![0]
        for y in 0..<raw.height {
            let worldY = f.minY + (Double(y) + 0.5) / Double(raw.height) * f.height, t = (worldY - h.minY) / h.height
            if t <= 0.34 { continue }
            let blend = max(0, min(1, (t - 0.39) / 0.37)), margin = max(0, (0.44 - t) / 0.10) * h.width * 0.15
            let left = upper.0 + (lower.0 - upper.0) * blend - margin, right = upper.1 + (lower.1 - upper.1) * blend + margin
            for x in 0..<raw.width {
                let worldX = f.minX + (Double(x) + 0.5) / Double(raw.width) * f.width
                var mask = max(0, min(1, min(worldX - left, right - worldX) / 0.25))
                if let end = recipe.sideburnEnd, t > end - 0.1 {
                    let taper = max(0, min(1, (t - end + 0.1) / 0.1)), inner = (0.32 + 0.08 * taper) * h.width
                    mask *= max(0, min(1, (abs(worldX - axis) - inner) / 0.25))
                }
                let i = (y * raw.width + x) * 4
                for c in 0..<4 { bytes[i + c] = UInt8((Double(bytes[i + c]) * mask).rounded()) }
            }
        }
    }

    private func fitMouth(_ bytes: [UInt8], raw: IllustrationPixels, layer: IllustrationLayer) -> [UInt8] {
        let mouth = layer.mouthAttachment!, source = sourcePixels(mouth.id), m = mouth.frame, f = layer.frame
        let opening = sprites[layer.id]!.mouthOpening!, sx = Double(raw.width) / f.width, sy = Double(raw.height) / f.height
        var mask = [UInt8](repeating: 0, count: raw.width * raw.height)
        for y in 0..<raw.height {
            let worldY = f.minY + (Double(y) + 0.5) / sy
            if worldY < m.minY - 0.45 || worldY > m.maxY + 0.45 { continue }
            for x in 0..<raw.width {
                let worldX = f.minX + (Double(x) + 0.5) / sx
                if worldX < m.minX - 0.45 || worldX > m.maxX + 0.45 { continue }
                var alpha = 0.0
                for step in 0...8 {
                    let dx = step == 8 ? 0 : cos(Double(step) * .pi / 4) * 0.45
                    let dy = step == 8 ? 0 : sin(Double(step) * .pi / 4) * 0.45
                    let xx = Int(floor((worldX - m.minX - dx) / m.width * Double(source.width))), yy = Int(floor((worldY - m.minY - dy) / m.height * Double(source.height)))
                    if xx >= 0 && xx < source.width && yy >= 0 && yy < source.height {
                        alpha = 1 - (1 - alpha) * (1 - Double(source.bytes[(yy * source.width + xx) * 4 + 3]) / 255)
                    }
                }
                mask[y * raw.width + x] = UInt8((alpha * 255).rounded())
            }
        }
        var result = [UInt8](repeating: 0, count: bytes.count)
        let center = (m.midY - f.minY) * sy
        for x in 0..<raw.width {
            guard let gap = opening[x] else {
                for y in 0..<raw.height { for c in 0..<4 { result[(y * raw.width + x) * 4 + c] = bytes[(y * raw.width + x) * 4 + c] } }
                continue
            }
            var top = Double(raw.height), bottom = -1.0
            for y in 0..<raw.height where mask[y * raw.width + x] >= 80 { top = min(top, Double(y)); bottom = Double(y + 1) }
            let closed = bottom < 0, overlap = closed ? 0.5 : 0
            if closed { top = center; bottom = center }
            for y in 0..<raw.height {
                let yy = Double(y) + 0.5, sourceY: Double
                if yy < top + overlap { sourceY = yy / (top + overlap) * gap[0] - 0.5 }
                else if yy >= bottom - overlap { sourceY = gap[1] + (yy - bottom + overlap) / (Double(raw.height) - bottom + overlap) * (Double(raw.height) - gap[1]) - 0.5 }
                else { continue }
                let low = Int(floor(sourceY)), blend = sourceY - floor(sourceY), coverage = 1 - Double(mask[y * raw.width + x]) / 255
                for c in 0..<4 {
                    let a = low >= 0 && low < raw.height ? Double(bytes[(low * raw.width + x) * 4 + c]) : 0
                    let b = low + 1 >= 0 && low + 1 < raw.height ? Double(bytes[((low + 1) * raw.width + x) * 4 + c]) : 0
                    result[(y * raw.width + x) * 4 + c] = UInt8(max(0, min(255, ((a * (1 - blend) + b * blend) * coverage).rounded())))
                }
            }
        }
        return result
    }

    func image(_ layer: IllustrationLayer) -> UIImage {
        let key = "\(String(describing: layer.headAttachment))/\(String(describing: layer.mouthAttachment))/\(layer.rearHair)/\(layer.templeCut)/\(layer.id)/\(layer.color)/\(layer.mode)/\(layer.scalpMask)/\(String(describing: layer.thighSeam))/\(layer.treatment.rawValue)/\(layer.accent)/\(String(describing: layer.warp))/\(layer.legMasks.map { "\($0.id):\($0.frame)" }.joined(separator: ";"))" as NSString
        if let image = painted.object(forKey: key) { return image }
        guard let sprite = sprites[layer.id] else { preconditionFailure("Missing character component: \(layer.id)") }
        let raw = sourcePixels(layer.id)
        var bytes = raw.bytes
        func channels(_ value: UInt32) -> [Double] { [16, 8, 0].map { Double((value >> $0) & 255) } }
        let base = channels(layer.color), accent = channels(layer.accent)
        if layer.mode != "original" {
            for i in stride(from: 0, to: bytes.count, by: 4) {
                if let hem = sprite.hem, i / 4 / raw.width >= hem[i / 4 % raw.width] {
                    bytes.replaceSubrange(i..<(i + 4), with: [0, 0, 0, 0])
                    continue
                }
                let rawAlpha = Double(raw.bytes[i + 3]) / 255
                if rawAlpha == 0 { continue }
                let rgb = (0..<3).map { Double(raw.bytes[i + $0]) / rawAlpha }
                let luminance = (rgb[0] * 0.2126 + rgb[1] * 0.7152 + rgb[2] * 0.0722) / 255
                let density = sprite.densityReference.map { max(0, 1 - luminance / $0) * sprite.densityOpacity! } ?? 1
                let alpha = rawAlpha * density
                bytes[i + 3] = UInt8((alpha * 255).rounded())
                var mask = layer.mode == "skin" || layer.mode == "mouth" ? max(0, min(1, (rgb[0] - rgb[2]) / 255 * 8 - 0.8)) : 1
                if layer.mode == "mouth", luminance > 0.56, rgb[1] > rgb[0] * 0.70, rgb[2] > rgb[0] * 0.53 { mask = 0 }
                let x = Double(i / 4 % raw.width), y = Double(i / 4 / raw.width)
                if layer.mode == "iris" {
                    let nx = x / Double(raw.width), ny = y / Double(raw.height)
                    let distance = min(abs(nx - 0.235), abs(nx - 0.765)) / 0.09
                    let oval = distance * distance + pow((ny - 0.58) / 0.31, 2)
                    mask = layer.id == "eyes/sleepy" || rgb[0] > 145 || luminance > 0.45 ? 0 : max(0, min(1, (1 - oval) * 6)) * max(0, min(1, (ny - 0.35) * 8))
                }
                var mix: Double = 0
                if layer.treatment == .ombre { mix = max(0, min(1, (y / Double(raw.height) - 0.35) / 0.55)) }

                for channel in 0..<3 {
                    let original = layer.mode == "iris" && rgb[0] > 145 && rgb[0] - rgb[2] > 35 && rgb[0] - rgb[1] > 18 ? min(255, accent[channel] * luminance / 0.66) : rgb[channel]
                    let paint = (base[channel] * (1 - mix) + accent[channel] * mix) * luminance / sprite.luminance
                    bytes[i + channel] = UInt8(max(0, min(255, ((original * (1 - mask) + min(255, paint) * mask) * alpha).rounded())))
                }
            }
        }
        var outputWidth = raw.width
        if let warp = layer.warp {
            if !warp.preserveOuter { outputWidth *= 2 }
            var warped = [UInt8](repeating: 0, count: outputWidth * raw.height * 4)
            let pivot = warp.pivot * Double(raw.width)
            for y in 0..<raw.height {
                let t = Double(y) / Double(raw.height)
                let next = warp.stops.firstIndex { $0[0] >= t }!
                let a = warp.stops[max(0, next - 1)], b = warp.stops[next]
                let mix = b[0] == a[0] ? 0 : (t - a[0]) / (b[0] - a[0])
                let left = a[1] + (b[1] - a[1]) * mix, right = a[2] + (b[2] - a[2]) * mix
                if warp.preserveOuter {
                    warpPreservingOuter(bytes, into: &warped, raw: raw, row: y, pivot: pivot, left: left, right: right, guardWidth: warp.outerGuard)
                    continue
                }
                for x in 0..<outputWidth {
                    let relative = Double(x) + 0.5 - Double(raw.width) / 2 - pivot
                    let source = relative / (relative < 0 ? left : right) + pivot - 0.5
                    let lo = Int(floor(source)), blend = source - floor(source)
                    for channel in 0..<4 {
                        let v0 = lo >= 0 && lo < raw.width ? Double(bytes[(y * raw.width + lo) * 4 + channel]) : 0
                        let v1 = lo + 1 >= 0 && lo + 1 < raw.width ? Double(bytes[(y * raw.width + lo + 1) * 4 + channel]) : 0
                        warped[(y * outputWidth + x) * 4 + channel] = UInt8((v0 * (1 - blend) + v1 * blend).rounded())
                    }
                }
            }
            bytes = warped
        }
        if layer.rearHair { bytes = rearPixels(bytes, raw: raw, layer: layer) }
        if layer.templeCut { trimTemples(&bytes, raw: raw, layer: layer) }
        if layer.mouthAttachment != nil { bytes = fitMouth(bytes, raw: raw, layer: layer) }
        if !layer.legMasks.isEmpty {
            let legs = layer.legMasks.map { leg -> (IllustrationLayer, IllustrationPixels) in
                return (leg, sourcePixels(leg.id))
            }
            for y in 0..<raw.height {
                let worldY = layer.frame.minY + (Double(y) + 0.5) / Double(raw.height) * layer.frame.height
                let weight: Double
                if layer.scalpMask { weight = 1 }
                else if let seam = layer.thighSeam { weight = 1 - max(0, min(1, (worldY - seam) / 1.5)) }
                else { weight = legs.map { leg, _ in max(0, min(1, ((worldY - leg.frame.minY) / leg.frame.height - 0.02) / 0.08)) }.min()! }
                if weight == 0 { continue }
                for x in 0..<outputWidth {
                    let i = (y * outputWidth + x) * 4
                    if bytes[i + 3] == 0 { continue }
                    let worldX = layer.drawingFrame.minX + (Double(x) + 0.5) / Double(outputWidth) * layer.drawingFrame.width
                    var alpha: Double = 0
                    for (leg, source) in legs {
                        let t = (worldY - leg.frame.minY) / leg.frame.height
                        var sourceX = (worldX - leg.frame.minX) / leg.frame.width
                        if let warp = leg.warp, t >= 0, t <= 1 {
                            let next = warp.stops.firstIndex { $0[0] >= t }!
                            let a = warp.stops[max(0, next - 1)], b = warp.stops[next]
                            let mix = a[0] == b[0] ? 0 : (t - a[0]) / (b[0] - a[0])
                            let side = sourceX < warp.pivot ? 1 : 2
                            let scale = a[side] + (b[side] - a[side]) * mix
                            sourceX = warp.pivot + (sourceX - warp.pivot) / scale
                        }
                        let xx = Int(floor(sourceX * Double(source.width)))
                        let yy = Int(floor(t * Double(source.height)))
                        if xx >= 0 && xx < source.width && yy >= 0 && yy < source.height {
                            alpha = max(alpha, Double(source.bytes[(yy * source.width + xx) * 4 + 3]) / 255)
                        }
                    }
                    let coverage = 1 - weight * (1 - alpha)
                    for channel in 0..<4 { bytes[i + channel] = UInt8((Double(bytes[i + channel]) * coverage).rounded()) }
                }
            }
        }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        guard let image = CGImage(width: outputWidth, height: raw.height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: outputWidth * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue), provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { preconditionFailure("Cannot render character component: \(layer.id)") }
        let result = UIImage(cgImage: image)
        painted.setObject(result, forKey: key, cost: bytes.count)
        return result
    }

    func layers(_ a: CharacterAppearance) -> [IllustrationLayer] {
        var result: [IllustrationLayer] = []
        func add(_ id: String, _ x: Double, _ y: Double, _ w: Double, _ h: Double, _ color: UInt32, _ mode: String = "solid", _ treatment: HairTreatment = .solid, _ accent: UInt32 = 0, _ warp: IllustrationWarp? = nil) {
            result.append(IllustrationLayer(id: id, frame: CGRect(x: x, y: y, width: w, height: h), color: color, mode: mode, treatment: treatment, accent: accent, warp: warp))
        }
        func aspect(_ id: String) -> Double {
            guard let item = sprites[id] else { preconditionFailure("Missing component: \(id)") }
            return Double(item.rect[2]) / Double(item.rect[3])
        }
        func centered(_ id: String, _ y: Double, _ w: Double, _ color: UInt32, _ mode: String = "solid", _ heightScale: Double = 1) {
            let h = w / aspect(id) * heightScale
            add(id, 80 - w / 2, y - h / 2, w, h, color, mode)
        }
        func buildKey(_ value: LimbBuild) -> String { value == .slender ? "slim" : value == .medium ? "regular" : value.rawValue }
        let build: Double = a.build == .slender ? 0.91 : a.build == .full ? 1.17 : 1
        let shoulders: Double = a.shoulders == .narrow ? 0.92 : a.shoulders == .broad ? 1.12 : 1
        let torsoLength: Double = a.torsoLength == .short ? -10 : a.torsoLength == .long ? 10 : 0
        let hipY = 112 + torsoLength
        let end: Double = a.height == .petite ? 182 : a.height == .tall ? 210 : 198
        let torsoBase: Double = switch a.silhouette { case .straight, .balanced: 55; case .curved: 57; case .pear: 60; case .broad, .athletic: 64; case .muscular: 70 }
        let torsoWidth = torsoBase * build, torsoHeight = hipY + 8 - 44
        let torsoID = "torso/" + a.silhouette.rawValue, torso = sprites[torsoID]!
        let torsoX = 80 - torsoWidth * torso.neck![0]
        let face = a.faceShape == .square ? "angular" : a.faceShape.rawValue
        let headID = "head/" + a.facialStructure.rawValue + "/" + face
        let headHeight: Double = 38, headWidth = headHeight * aspect(headID), headY: Double = 12
        let eyeY = headY + headHeight * 0.49
        var cuffScales: [Double] = []
        for (index, side) in ["left", "right"].enumerated() {
            let id = "leg/" + buildKey(a.legBuild) + "/" + side
            let cuff = torso.cuffs![index], section = sprites[id]!.section!
            let w = 87 * aspect(id) * torsoWidth / 55
            let scale = w * (section[1] - section[0]) / ((cuff[1] - cuff[0]) * torsoWidth)
            cuffScales.append(scale)
            // Bind the opaque thigh cross-section to the fitted shorts opening.
            let seam = 44 + torsoHeight * cuff[2] - 1.5, h = (end - seam) / 0.9
            let edge = 80 + (cuff[0] - torso.neck![0]) * torsoWidth * scale
            add(id, edge - w * section[0], seam - h * 0.1, w, h, a.skin, "skin")
        }
        let armLength: Double = a.armLength == .short ? -6 : a.armLength == .long ? 7 : 0
        for (index, side) in ["left", "right"].enumerated() {
            let id = "arm/" + buildKey(a.armBuild) + "/" + side
            let socket = torso.shoulders![index], top = 44 + torsoHeight * socket[1]
            let h = hipY + 12 + armLength - top, w = 64.5 * aspect(id) * torsoWidth / 55
            let anchor = sprites[id]!.anchor!, root = 80 + (socket[0] - torso.neck![0]) * torsoWidth * shoulders
            add(id, root - w * anchor[0], top, w, h, a.skin)
        }
        let warp = IllustrationWarp(pivot: torso.neck![0], stops: [
            [0, 1, 1], [0.16, shoulders, shoulders], [0.5, 1, 1], [0.7, 1, 1],
            [0.88, cuffScales[0], cuffScales[1]], [1, cuffScales[0], cuffScales[1]]
        ])
        add(torsoID, torsoX, 44, torsoWidth, torsoHeight, a.skin, "skin", .solid, a.skin, warp)
        result[result.count - 1].legMasks = result.filter { $0.id.hasPrefix("leg/") }
        var baseTorso = result[result.count - 1]
        baseTorso.legMasks = []
        for index in result.indices where result[index].id.hasPrefix("leg/") {
            result[index].legMasks = [baseTorso]
            result[index].thighSeam = result[index].frame.minY + result[index].frame.height * 0.1
        }
        add(headID, 80 - headWidth * sprites[headID]!.neck![0], headY, headWidth, headHeight, a.skin)
        if a.hairstyle != .bald {
            let id = "hair/" + a.hairstyle.rawValue, box = sprites[id]!.placement!, scale = headWidth / 36
            add(id, 80 + box[0] * scale, box[1], box[2] * scale, box[3], a.hair, "solid", a.hairTreatment, a.hairAccent)
            if a.hairstyle != .buzzCut && a.hairstyle != .shaved {
                result[result.count - 1].warp = fittedHair(head: result.first { $0.id.hasPrefix("head/") }!, hair: result.last!)
            }
            if a.hairstyle == .buzzCut || a.hairstyle == .shaved {
                result[result.count - 1].legMasks = result.filter { $0.id.hasPrefix("head/") }
                result[result.count - 1].scalpMask = true
            }
        }
        if a.beard != .none {
            let width: Double = switch a.beard { case .stubble: 0.83; case .moustache: 0.48; case .handlebar: 0.67; case .goatee: 0.46; case .shortBeard: 0.86; default: 0.92 }
            let y: Double = switch a.beard { case .stubble: 0.79; case .moustache: 0.715; case .handlebar: 0.72; case .goatee: 0.86; case .shortBeard: 0.84; case .fullBeard: 0.91; case .longBeard: 1.02; case .none: 0 }
            let id = "beard/" + a.beard.rawValue, w = headWidth * width
            if let anchor = sprites[id]!.mouth {
                let h = w / aspect(id)
                add(id, 80 - w * anchor[0], headY + headHeight * 0.79 - h * anchor[1], w, h, a.beardColor)
            } else { centered(id, headY + headHeight * y, w, a.beardColor) }
        }
        let eyeSize: Double = a.eyeSize == .small ? 0.84 : a.eyeSize == .large ? 1.17 : 1
        let eyeWidth: Double = switch a.eyes { case .wide: 0.64; case .almond: 0.60; case .monolid: 0.58; case .longFissure: 0.63; case .softOval: 0.53; default: 0.56 }
        let eyeHeight: Double = switch a.eyes { case .wide: 0.84; case .almond: 0.94; case .monolid: 0.88; case .longFissure: 0.76; case .softOval: 1.08; default: 1 }
        centered("eyes/" + a.eyes.rawValue, eyeY, headWidth * eyeWidth * eyeSize, a.iris, "iris", eyeHeight)
        result[result.count - 1].accent = a.skin
        centered("brows/" + a.eyebrows.rawValue, eyeY - 4.4, headWidth * 0.56, a.hair)
        let noseWidth: Double = switch a.nose { case .soft: 0.13; case .defined: 0.125; case .broad: 0.18; case .button: 0.105; case .straight: 0.115; case .aquiline: 0.12; case .rounded: 0.15; case .wideBridge: 0.19 }
        centered("nose/" + a.nose.rawValue, headY + headHeight * 0.655, headWidth * noseWidth, a.skin)
        let lipChannels = zip([16, 8, 0].map { Double((a.skin >> $0) & 255) }, [152.0, 77.0, 56.0]).map { skin, lip in UInt32((skin * 0.3 + lip * 0.7).rounded()) }
        let lipColor = lipChannels[0] << 16 | lipChannels[1] << 8 | lipChannels[2]
        let mouthWidth: Double = switch a.mouth { case .neutral: 0.25; case .smile: 0.28; case .grin: 0.32; case .openSmile: 0.29; case .pout: 0.21; case .frown: 0.26; case .smirk: 0.28; case .open: 0.17 }
        let fullness: Double = a.lips == .thin ? 0.72 : a.lips == .full ? 1.25 : 1
        centered("mouth/" + a.mouth.rawValue, headY + headHeight * 0.79, headWidth * mouthWidth, lipColor, "mouth", fullness)
        if let index = result.firstIndex(where: { sprites[$0.id]?.mouthOpening != nil }) {
            let mouth = result.last!
            result[index].mouthAttachment = IllustrationAttachment(id: mouth.id, frame: mouth.frame)
        }
        if let index = result.firstIndex(where: { $0.id.hasPrefix("hair/") }) {
            var hair = result.remove(at: index)
            let recipe = sprites[hair.id]!.layers!, head = result.first { $0.id.hasPrefix("head/") }!
            if recipe.rear == "none" { hair.hairPart = "scalp"; result.append(hair) }
            else {
                var rear = hair
                rear.hairPart = "rear"; rear.rearHair = true
                rear.headAttachment = IllustrationAttachment(id: head.id, frame: head.frame)
                result.insert(rear, at: 0)
                hair.hairPart = "front"
                if recipe.templeCut == true {
                    hair.templeCut = true
                    hair.headAttachment = IllustrationAttachment(id: head.id, frame: head.frame)
                }
                result.append(hair)
            }
        }
        return result
    }
}

struct CharacterSticker: View {
    let appearance: CharacterAppearance
    var framing: CharacterFraming = .body

    var body: some View {
        Canvas { context, size in
            let bounds = framing.bounds
            let scale = min(size.width / bounds.width, size.height / bounds.height)
            context.translateBy(x: (size.width - bounds.width * scale) / 2 - bounds.minX * scale,
                                y: (size.height - bounds.height * scale) / 2 - bounds.minY * scale)
            context.scaleBy(x: scale, y: scale)
            let art = CharacterIllustrations.shared
            for layer in art.layers(appearance) {
                context.draw(Image(uiImage: art.image(layer)), in: layer.drawingFrame)
            }
        }.clipped().accessibilityLabel("Your character sticker")
    }
}


struct CharacterPreviewRequest: Codable, Hashable, Sendable {
    let appearance: CharacterAppearance
    let framing: CharacterFraming
    let width: Int
    let height: Int
}

final class CharacterPreviewImage: @unchecked Sendable {
    let image: UIImage
    init(_ image: UIImage) { self.image = image }
}

private final class CharacterPreviewKey: NSObject {
    let request: CharacterPreviewRequest
    init(_ request: CharacterPreviewRequest) { self.request = request }
    override var hash: Int { request.hashValue }
    override func isEqual(_ object: Any?) -> Bool {
        (object as? CharacterPreviewKey)?.request == request
    }
}

struct CharacterPreviewDiskCache: Sendable {
    static let logger = Logger(subsystem: "io.github.carrol74.wearwise", category: "CharacterPreviewCache")
    let rootURL: URL
    let generation: String
    let byteLimit: Int
    private var prepared = false
    var directory: URL { rootURL.appending(path: generation, directoryHint: .isDirectory) }

    init(rootURL: URL = URL.cachesDirectory.appending(path: "WearwiseCharacterPreviews", directoryHint: .isDirectory),
         generation: String = CharacterPreviewDiskCache.currentGeneration(), byteLimit: Int = 32 * 1024 * 1024) {
        self.rootURL = rootURL
        self.generation = generation
        self.byteLimit = byteLimit
    }

    static func currentGeneration() -> String {
        let bundle = Bundle.main
        var identity = "renderer-v1/\(bundle.infoDictionary?["CFBundleShortVersionString"] ?? "")/\(bundle.infoDictionary?["CFBundleVersion"] ?? "")"
        var files = [bundle.url(forResource: "Assets", withExtension: "car"), bundle.executableURL].compactMap { $0 }
        if let executable = bundle.executableURL {
            let debugLibrary = executable.deletingLastPathComponent().appending(path: executable.lastPathComponent + ".debug.dylib")
            if FileManager.default.fileExists(atPath: debugLibrary.path) { files.append(debugLibrary) }
        }
        for file in files {
            if let values = try? file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]) {
                identity += "/\(file.lastPathComponent):\(values.fileSize ?? 0):\(values.contentModificationDate?.timeIntervalSince1970 ?? 0)"
            }
        }
        return SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    func fileURL(for request: CharacterPreviewRequest) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let digest = SHA256.hash(data: try encoder.encode(request)).map { String(format: "%02x", $0) }.joined()
        return directory.appending(path: digest + ".png")
    }

    mutating func load(_ request: CharacterPreviewRequest) throws -> UIImage? {
        try prepare()
        let file = try fileURL(for: request)
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        let data = try Data(contentsOf: file)
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary),
              image.width == request.width, image.height == request.height else {
            try FileManager.default.removeItem(at: file)
            Self.logger.notice("Removed an unreadable character preview cache entry.")
            return nil
        }
        try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: file.path)
        return UIImage(cgImage: image)
    }

    mutating func store(_ image: UIImage, for request: CharacterPreviewRequest) throws {
        guard let data = image.pngData() else { throw CocoaError(.fileWriteUnknown) }
        guard data.count <= byteLimit else { return }
        try prepare()
        let file = try fileURL(for: request)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try trim(reserving: data.count, replacing: file)
        try data.write(to: file, options: .atomic)
    }

    private mutating func prepare() throws {
        guard !prepared else { return }
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        for file in try manager.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil) where file.lastPathComponent != generation {
            try manager.removeItem(at: file)
        }
        try trim(reserving: 0)
        prepared = true
    }

    private func trim(reserving bytes: Int, replacing replacement: URL? = nil) throws {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]
        let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(keys))
        let files = try urls.filter { $0 != replacement }.compactMap { url -> (url: URL, size: Int, date: Date)? in
            let values = try url.resourceValues(forKeys: keys)
            guard values.isRegularFile == true else { return nil }
            return (url, values.fileSize ?? 0, values.contentModificationDate ?? .distantPast)
        }.sorted { $0.date < $1.date }
        var total = files.reduce(bytes) { $0 + $1.size }
        for file in files where total > byteLimit {
            try FileManager.default.removeItem(at: file.url)
            total -= file.size
        }
    }
}

actor CharacterPreviewRenderer {
    static let shared = CharacterPreviewRenderer()
    private let cache = NSCache<CharacterPreviewKey, CharacterPreviewImage>()

    private var diskCache: CharacterPreviewDiskCache

    init(diskCache: CharacterPreviewDiskCache = CharacterPreviewDiskCache()) {
        self.diskCache = diskCache
        cache.countLimit = 128
        cache.totalCostLimit = 24 * 1024 * 1024
    }

    func image(for request: CharacterPreviewRequest) throws -> CharacterPreviewImage {
        try Task.checkCancellation()
        let key = CharacterPreviewKey(request)
        if let image = cache.object(forKey: key) { return image }
        do {
            if let image = try diskCache.load(request) {
                try Task.checkCancellation()
                let result = CharacterPreviewImage(image)
                cache.setObject(result, forKey: key, cost: request.width * request.height * 4)
                return result
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            CharacterPreviewDiskCache.logger.error("Could not read character preview cache: \(error.localizedDescription, privacy: .public)")
        }
        let bounds = request.framing.bounds
        let size = CGSize(width: request.width, height: request.height)
        let scale = min(size.width / bounds.width, size.height / bounds.height)
        let art = CharacterIllustrations.shared
        let layers = art.layers(request.appearance)
        var images: [(IllustrationLayer, UIImage)] = []
        for layer in layers {
            try Task.checkCancellation()
            images.append((layer, art.image(layer)))
        }
        try Task.checkCancellation()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            context.cgContext.translateBy(x: (size.width - bounds.width * scale) / 2 - bounds.minX * scale,
                                         y: (size.height - bounds.height * scale) / 2 - bounds.minY * scale)
            context.cgContext.scaleBy(x: scale, y: scale)
            for (layer, image) in images { image.draw(in: layer.drawingFrame) }
        }
        try Task.checkCancellation()
        let result = CharacterPreviewImage(image)
        cache.setObject(result, forKey: key, cost: request.width * request.height * 4)
        do { try diskCache.store(image, for: request) }
        catch { CharacterPreviewDiskCache.logger.error("Could not write character preview cache: \(error.localizedDescription, privacy: .public)") }
        try Task.checkCancellation()
        return result
    }
}

private struct CharacterPreview: View {
    @Environment(\.displayScale) private var displayScale
    let appearance: CharacterAppearance
    var framing: CharacterFraming = .body
    var priority: TaskPriority = .utility
    @State private var rendered: CharacterPreviewImage?
    @State private var renderedRequest: CharacterPreviewRequest?

    var body: some View {
        GeometryReader { geometry in
            let request = CharacterPreviewRequest(appearance: appearance, framing: framing,
                width: max(1, Int((geometry.size.width * displayScale).rounded())),
                height: max(1, Int((geometry.size.height * displayScale).rounded())))
            ZStack {
                if let rendered {
                    Image(uiImage: rendered.image).resizable().interpolation(.high)
                }
                if renderedRequest != request {
                    ProgressView().controlSize(.small)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .task(id: request, priority: priority) {
                guard request.width > 1, request.height > 1 else { return }
                do {
                    let result = try await CharacterPreviewRenderer.shared.image(for: request)
                    try Task.checkCancellation()
                    rendered = result
                    renderedRequest = request
                } catch is CancellationError {
                } catch {
                    preconditionFailure("Unexpected character preview error: \(error)")
                }
            }
        }.clipped().accessibilityLabel("Your character sticker")
    }
}


struct CharacterView: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.dismiss) private var dismiss
    @State private var appearance = CharacterAppearance()
    @State private var baseline = CharacterAppearance()
    @State private var section: CharacterSection = .body
    @State private var faceFeature: FaceFeature = .shape
    @State private var hairGroup: HairLengthGroup = .long
    @State private var loaded = false
    @State private var errorText: String?
    @State private var discarding = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 12) {
                    Group {
                        if loaded { CharacterPreview(appearance: appearance, framing: section.framing, priority: .userInitiated) }
                        else { ProgressView() }
                    }
                        .aspectRatio(section.framing.bounds.width / section.framing.bounds.height, contentMode: .fit)
                        .padding(10).frame(height: min(typeSize.isAccessibilitySize ? 135 : 230, geometry.size.height * 0.34))
                        .frame(maxWidth: .infinity)
                        .background {
                            RoundedRectangle(cornerRadius: WearwiseRadius.large, style: .continuous)
                                .fill(Color.imageMount)
                        }
                        .padding(.horizontal, 20)
                    ScrollView(.horizontal) {
                      HStack(spacing: 4) {
                        ForEach(CharacterSection.allCases, id: \.self) { tab in
                            Button { section = tab } label: {
                                VStack(spacing: 5) {
                                    Image(systemName: tab.symbol).font(.system(size: 21, weight: .regular))
                                    Text(tab.rawValue).font(.caption2.weight(.medium))
                                }.frame(minWidth: 44, minHeight: 58)
                                    .foregroundStyle(section == tab ? Color.onAccent : Color.accentText)
                                    .background(section == tab ? Color.wearwiseBlue : Color.clear, in: RoundedRectangle(cornerRadius: WearwiseRadius.small))
                            }.buttonStyle(WearwisePressStyle())
                                .accessibilityLabel(tab.rawValue)
                                .accessibilityIdentifier("character.tab.\(tab.rawValue)")
                                .accessibilityAddTraits(section == tab ? [.isSelected] : [])
                        }
                      }.frame(minWidth: geometry.size.width - 40)
                    }.scrollIndicators(.hidden).accessibilityIdentifier("character.tabs").padding(.horizontal, 20)
                    if section == .face {
                        ScrollView(.horizontal) {
                          HStack(spacing: 4) {
                            ForEach(FaceFeature.allCases, id: \.self) { feature in
                                Button { faceFeature = feature } label: {
                                    Text(feature.rawValue).font(.caption.weight(.medium)).padding(.horizontal, 10).frame(minHeight: 36)
                                        .foregroundStyle(faceFeature == feature ? Color.onAccent : Color.accentText)
                                        .background(faceFeature == feature ? Color.wearwiseBlue : Color.clear, in: RoundedRectangle(cornerRadius: WearwiseRadius.small))
                                }.buttonStyle(WearwisePressStyle()).accessibilityLabel(feature.rawValue)
                                    .accessibilityIdentifier("character.face.\(feature.rawValue)")
                                    .accessibilityAddTraits(faceFeature == feature ? [.isSelected] : [])
                            }
                          }.padding(.horizontal, 20)
                        }.scrollIndicators(.hidden).accessibilityIdentifier("character.face-tabs")
                    }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            Text(section == .face ? "Face · \(faceFeature.rawValue)" : section.rawValue).font(.headline).accessibilityAddTraits(.isHeader)
                            if loaded { controls }
                        }
                            .padding(.horizontal, 20).padding(.bottom, 24).frame(maxWidth: .infinity, alignment: .leading)
                    }.id("\(section.rawValue)-\(faceFeature.rawValue)").accessibilityIdentifier("character.options")
                }.padding(.top, 8)
            }
            .background(Color.wardrobeBackground)
            .navigationTitle("My character").navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(appearance != baseline)
            .labelStyle(.iconOnly)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { if appearance != baseline { discarding = true } else { dismiss() } }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") {
                        do { try CharacterPreferences().save(appearance); dismiss() }
                        catch { errorText = error.localizedDescription }
                    }.disabled(!loaded)
                }
            }
            .task {
                guard !loaded else { return }
                do { appearance = try CharacterPreferences().load(); baseline = appearance; hairGroup = appearance.hairstyle.group; loaded = true }
                catch { errorText = error.localizedDescription }
            }
            .wearwiseDiscardConfirmation(isPresented: $discarding) { dismiss() }
            .wearwiseErrorToast("Could not update character", message: $errorText)
        }
    }

    @ViewBuilder private var controls: some View {
        switch section {
        case .body:
            visualChoices("Silhouette", symbol: "figure.stand", values: BodySilhouette.allCases, selection: $appearance.silhouette, keyPath: \.silhouette, framing: .body)
            visualChoices("Build", symbol: "figure.stand", values: BodyBuild.allCases, selection: $appearance.build, keyPath: \.build, framing: .body)
            visualChoices("Torso length", symbol: "arrow.up.and.down", values: PartLength.allCases, selection: $appearance.torsoLength, keyPath: \.torsoLength, framing: .body)
            visualChoices("Shoulders", symbol: "arrow.left.and.right", values: ShoulderWidth.allCases, selection: $appearance.shoulders, keyPath: \.shoulders, framing: .body)
            customColor("Skin tone", selection: $appearance.skin)
            colorChoices(colors: CharacterColor.skin, selection: $appearance.skin).accessibilityLabel("Skin tone presets")
        case .arms:
            visualChoices("Arm length", symbol: "arrow.up.and.down", values: PartLength.allCases, selection: $appearance.armLength, keyPath: \.armLength, framing: .arms)
            visualChoices("Arm build", symbol: "arrow.left.and.right", values: LimbBuild.allCases, selection: $appearance.armBuild, keyPath: \.armBuild, framing: .arms)
        case .legs:
            visualChoices("Leg length", symbol: "arrow.up.and.down", values: CharacterHeight.allCases, selection: $appearance.height, keyPath: \.height, framing: .legs) { $0 == .petite ? "Short" : $0 == .tall ? "Long" : "Medium" }
            visualChoices("Leg build", symbol: "arrow.left.and.right", values: LimbBuild.allCases, selection: $appearance.legBuild, keyPath: \.legBuild, framing: .legs)
        case .hairstyle:
            customColor("Hair color", selection: $appearance.hair)
            colorChoices(colors: CharacterColor.hair, selection: $appearance.hair)
            Picker("Hairstyles", selection: $hairGroup) {
                ForEach(HairLengthGroup.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).labelStyle(.titleOnly)
            visualChoices("Hairstyle", symbol: "scissors", values: HairStyle.allCases.filter { $0.group == hairGroup }, selection: $appearance.hairstyle, keyPath: \.hairstyle, framing: .hair) { $0.title }
            visualChoices("Color treatment", symbol: "paintpalette", values: HairTreatment.allCases, selection: $appearance.hairTreatment, keyPath: \.hairTreatment, framing: .hair)
            if appearance.hairTreatment != .solid { customColor("Accent color", selection: $appearance.hairAccent) }
        case .beard:
            customColor("Beard color", selection: $appearance.beardColor)
            colorChoices(colors: CharacterColor.hair, selection: $appearance.beardColor)
            visualChoices("Beard", symbol: "mustache", values: BeardStyle.allCases, selection: $appearance.beard, keyPath: \.beard) { $0.title }
        case .face: faceControls
        }
    }

    @ViewBuilder private var faceControls: some View {
        switch faceFeature {
        case .shape:
            visualChoices("Facial structure", symbol: "person.crop.square", values: FacialStructure.allCases, selection: $appearance.facialStructure, keyPath: \.facialStructure)
            visualChoices("Face shape", symbol: "person.crop.square", values: FaceShape.allCases, selection: $appearance.faceShape, keyPath: \.faceShape)
        case .eyes:
            visualChoices("Eyes", symbol: "eye", values: EyeShape.allCases, selection: $appearance.eyes, keyPath: \.eyes) { $0.title }
            visualChoices("Eye size", symbol: "eye", values: EyeSize.allCases, selection: $appearance.eyeSize, keyPath: \.eyeSize)
            customColor("Iris color", selection: $appearance.iris)
        case .brows:
            visualChoices("Eyebrows", symbol: "eyebrow", values: EyebrowShape.allCases, selection: $appearance.eyebrows, keyPath: \.eyebrows)
        case .nose:
            visualChoices("Nose", symbol: "nose", values: NoseShape.allCases, selection: $appearance.nose, keyPath: \.nose)
        case .mouth:
            visualChoices("Mouth", symbol: "mouth", values: MouthShape.allCases, selection: $appearance.mouth, keyPath: \.mouth) { $0.rawValue.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).capitalized }
            visualChoices("Mouth fullness", symbol: "mouth", values: LipShape.allCases, selection: $appearance.lips, keyPath: \.lips)
        }
    }

    private func customColor(_ title: String, selection: Binding<UInt32>) -> some View {
        ColorPicker(title, selection: Binding(
            get: { Color(uiColor: UIColor(rgb: selection.wrappedValue)) },
            set: { value in
                var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
                precondition(UIColor(value).getRed(&red, green: &green, blue: &blue, alpha: &alpha))
                selection.wrappedValue = UInt32((min(max(red, 0), 1) * 255).rounded()) << 16 | UInt32((min(max(green, 0), 1) * 255).rounded()) << 8 | UInt32((min(max(blue, 0), 1) * 255).rounded())
            }
        ), supportsOpacity: false).labelStyle(.titleAndIcon)
    }

    private var columns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 8), count: typeSize.isAccessibilitySize ? 2 : 3) }

    private func selectionBackground(_ selected: Bool) -> some View {
        RoundedRectangle(cornerRadius: WearwiseRadius.small).fill(selected ? Color.accentSurface : Color.imageMount)
            .overlay { RoundedRectangle(cornerRadius: WearwiseRadius.small).strokeBorder(selected ? Color.wearwiseBlue : Color.subtleBorder, lineWidth: selected ? 2.5 : 1) }
    }

    private func visualChoices<Value: RawRepresentable & Hashable>(_ title: String, symbol: String, values: [Value], selection: Binding<Value>, keyPath: WritableKeyPath<CharacterAppearance, Value>, framing: CharacterFraming = .face) -> some View where Value.RawValue == String {
        visualChoices(title, symbol: symbol, values: values, selection: selection, keyPath: keyPath, framing: framing) { $0.rawValue.capitalized }
    }

    private func visualChoices<Value: Hashable>(_ title: String, symbol: String, values: [Value], selection: Binding<Value>, keyPath: WritableKeyPath<CharacterAppearance, Value>, framing: CharacterFraming = .face, label: @escaping (Value) -> String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.subheadline.weight(.medium)).foregroundStyle(.secondary).accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(values, id: \.self) { value in
                    let selected = selection.wrappedValue == value
                    Button { selection.wrappedValue = value } label: {
                        var preview = appearance
                        preview[keyPath: keyPath] = value
                        return VStack(spacing: 5) {
                            CharacterPreview(appearance: preview, framing: framing).frame(height: 88)
                            Text(label(value)).font(.caption2).foregroundStyle(Color.primary).multilineTextAlignment(.center)
                        }.padding(7).padding(.bottom, 3).frame(maxWidth: .infinity)
                            .background(selectionBackground(selected))
                            .overlay(alignment: .topTrailing) {
                                if selected {
                                    Image(systemName: "checkmark.circle.fill").font(.system(size: 16))
                                        .foregroundStyle(Color.wearwiseBlue).padding(5)
                                }
                            }
                            .accessibilityHidden(true)
                    }.buttonStyle(WearwisePressStyle())
                        .accessibilityLabel("\(title), \(label(value))")
                        .accessibilityAddTraits(selected ? [.isSelected] : [])
                }
            }
        }.accessibilityElement(children: .contain).accessibilityLabel(title)
    }

    private func colorChoices(colors: [CharacterColor], selection: Binding<UInt32>) -> some View {
        ScrollView(.horizontal) {
          HStack(spacing: 4) {
            ForEach(colors) { item in
                let selected = selection.wrappedValue == item.value
                Button { selection.wrappedValue = item.value } label: {
                    Circle().fill(Color(uiColor: UIColor(rgb: item.value))).frame(width: 32, height: 32)
                        .overlay { Circle().strokeBorder(Color.charcoalText.opacity(0.12), lineWidth: 1) }
                        .frame(width: 44, height: 52).background(selectionBackground(selected))
                        .overlay(alignment: .topTrailing) {
                            if selected { Image(systemName: "checkmark.circle.fill").font(.system(size: 16)).foregroundStyle(Color.wearwiseBlue).padding(5) }
                        }
                }.buttonStyle(WearwisePressStyle())
                    .accessibilityLabel(item.name).accessibilityAddTraits(selected ? [.isSelected] : [])
            }
          }
        }.scrollIndicators(.hidden)
    }
}


@MainActor
struct CharacterStickerStore {
    let context: ModelContext
    var assets: AssetStore = .shared

    static func png(_ appearance: CharacterAppearance) throws -> Data {
        let renderer = ImageRenderer(content: CharacterSticker(appearance: appearance).frame(width: 320, height: 400))
        renderer.scale = 2
        renderer.isOpaque = false
        guard let data = renderer.uiImage?.pngData() else { throw OutfitStoreError.renderingFailed }
        return data
    }

    func create(_ appearance: CharacterAppearance) throws -> AssetRecord {
        let record = try assets.savePNG(Self.png(appearance), id: UUID())
        let file = assets.url(for: record)
        record.kind = "sticker"
        do { context.insert(record); try context.save(); return record }
        catch { context.rollback(); try FileManager.default.removeItem(at: file); throw error }
    }

    func removeUnused(_ records: [AssetRecord]) throws {
        let unused = records.filter { $0.outfits.isEmpty && $0.journalEntries.isEmpty && $0.brands.isEmpty && $0.inspirationBrands.isEmpty && $0.renderedEntries.isEmpty }
        let files = unused.map { assets.url(for: $0) }
        do { for record in unused { context.delete(record) }; context.processPendingChanges(); try context.save() }
        catch { context.rollback(); throw error }
        for file in files {
            if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
        }
    }
}
