import Foundation
import ImageIO
import SwiftData
import UniformTypeIdentifiers

@Model
final class AssetRecord {
    @Attribute(.unique) var id: UUID
    var kind: String
    var relativePath: String
    var pixelWidth: Int
    var pixelHeight: Int
    var createdAt: Date
    var outfits: [Outfit] = []
    var journalEntries: [JournalEntry] = []
    var brands: [Brand] = []
    var inspirationBrands: [Brand] = []
    var renderedEntries: [JournalEntry] = []

    init(id: UUID = UUID(), kind: String, relativePath: String, pixelWidth: Int, pixelHeight: Int, createdAt: Date = Date()) {
        self.id = id
        self.kind = kind
        self.relativePath = relativePath
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.createdAt = createdAt
    }
}

@Model
final class Garment {
    @Attribute(.unique) var id: UUID
    var name: String
    var category: String
    var colorTags: [String]
    var brand: String
    var size: String
    var seasons: [String]
    var status: String
    var amount: Decimal?
    var currency: String
    var createdAt: Date
    var updatedAt: Date
    var acquisitionDate: Date? = nil
    var acquisitionPrecision: String = "exact"
    var firstUseDate: Date? = nil
    var firstUsePrecision: String = "exact"
    var condition: String = "unknown"
    var notes: String = ""
    var shoppingOffersData: Data? = nil
    var openingWearCount: Int = 0
    var openingWearIsEstimate: Bool = false
    var costReference: Decimal? = nil
    var durationReferenceYears: Int? = nil
    var outfits: [Outfit] = []
    var journalEntries: [JournalEntry] = []
    @Relationship(deleteRule: .nullify, inverse: \WearRecord.garment) var wearRecords: [WearRecord] = []

    var originalAsset: AssetRecord?
    var cutoutAsset: AssetRecord?
    var brandRecord: Brand?

    init(
        id: UUID = UUID(),
        name: String,
        category: String,
        colorTags: [String] = [],
        brand: String = "",
        size: String = "",
        seasons: [String] = [],
        status: String = "owned",
        amount: Decimal? = nil,
        currency: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.colorTags = colorTags
        self.brand = brand
        self.size = size
        self.seasons = seasons
        self.status = status
        self.amount = amount
        self.currency = currency
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum GarmentStatus {
    static let owned = "owned"
    static let candidate = "candidate"
    static let retired = "retired"
    static let discarded = "discarded"

}

struct AssetStore {
    static let shared = AssetStore()

    let baseURL: URL

    init(baseURL: URL = URL.applicationSupportDirectory.appending(path: "WearwiseAssets")) {
        self.baseURL = baseURL
    }

    func url(for record: AssetRecord) -> URL {
        baseURL.appending(path: record.relativePath)
    }

    func savePNG(_ data: Data, id: UUID) throws -> AssetRecord {
        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
        let path = "\(id.uuidString).png"
        let record = try makeRecord(data: data, id: id, kind: "png", relativePath: path)
        let fileURL = baseURL.appending(path: path)
        try data.write(to: fileURL, options: .atomic)
        return record
    }

    func saveJPEG(_ data: Data, id: UUID) throws -> AssetRecord {
        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
        let path = "\(id.uuidString).jpg"
        let fileURL = baseURL.appending(path: path)
        let record = try makeRecord(data: data, id: id, kind: "jpg", relativePath: path)
        try data.write(to: fileURL, options: .atomic)
        return record
    }

    func loadData(for record: AssetRecord) throws -> Data {
        try Data(contentsOf: url(for: record))
    }

    func remove(_ record: AssetRecord) throws {
        let file = url(for: record)
        if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
    }

    private func makeRecord(data: Data, id: UUID, kind: String, relativePath: String) throws -> AssetRecord {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else {
            throw AssetStoreError.metadataUnavailable
        }
        return AssetRecord(id: id, kind: kind, relativePath: relativePath, pixelWidth: width, pixelHeight: height)
    }
}

enum AssetStoreError: Error {
    case metadataUnavailable
}
