import Foundation

enum GarmentCollection {
    case wardrobe, shopping

    var recordStatus: String {
        self == .wardrobe ? GarmentStatus.owned : GarmentStatus.candidate
    }

    var importTitle: String { self == .wardrobe ? "Import Garment" : "Add Shopping Item" }
    var pickerTitle: String { self == .wardrobe ? "Add Garment" : "Try Shopping Item" }
    var sourceLabel: String { self == .wardrobe ? "Wardrobe" : "Shopping" }

    func matches(_ garment: Garment, search: String = "") -> Bool {
        garment.status == recordStatus && garment.matches(search: search)
    }
}

extension Garment {
    func matches(search: String) -> Bool {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty || ([name, brand, category] + colorTags).contains {
            $0.localizedCaseInsensitiveContains(query)
        }
    }

    var collection: GarmentCollection {
        status == GarmentStatus.candidate || status == GarmentStatus.discarded ? .shopping : .wardrobe
    }
}
