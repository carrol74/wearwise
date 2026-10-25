import Foundation
import SwiftData

@Model
final class Brand {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var normalizedName: String
    var name: String
    var website: String
    var notes: String
    var fitNotes: String = ""
    var sizingNotes: String = ""
    var fabricNotes: String = ""
    var priceNotes: String = ""
    var interest: String
    var updatedAt: Date
    @Relationship(deleteRule: .nullify, inverse: \Garment.brandRecord) var garments: [Garment] = []
    @Relationship(deleteRule: .nullify, inverse: \AssetRecord.brands) var inspirationAsset: AssetRecord?

    @Relationship(deleteRule: .nullify, inverse: \AssetRecord.inspirationBrands) var additionalInspirationAssets: [AssetRecord] = []

    var inspirations: [AssetRecord] {
        ([inspirationAsset].compactMap { $0 } + additionalInspirationAssets).sorted {
            $0.createdAt == $1.createdAt ? $0.id.uuidString < $1.id.uuidString : $0.createdAt < $1.createdAt
        }
    }

    init(name: String, website: String = "", notes: String = "", interest: String = "Want to try") {
        id = UUID()
        self.name = name
        normalizedName = Self.key(name)
        self.website = website
        self.notes = notes
        self.interest = interest
        updatedAt = Date()
    }

    static func key(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

struct OwnedBrandGroup: Identifiable {
    var id: String
    var name: String
    var garments: [Garment]

    static func groups(from garments: [Garment]) -> [OwnedBrandGroup] {
        Dictionary(grouping: garments.filter { $0.status == GarmentStatus.owned }, by: { Brand.key($0.brand) })
            .map { key, garments in
                let sorted = garments.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                return OwnedBrandGroup(id: key, name: key.isEmpty ? "Unbranded" : sorted[0].brand.trimmingCharacters(in: .whitespacesAndNewlines), garments: sorted)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
