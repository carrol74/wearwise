import Foundation

struct WardrobeFilter {
    var search = ""
    var category = ""
    var season = ""
    var brand: String? = nil
    var colors: Set<String> = []

    func matches(_ garment: Garment) -> Bool {
        guard garment.status == GarmentStatus.owned,
              category.isEmpty || garment.category == category,
              season.isEmpty || garment.seasons.contains(season),
              brand == nil || Brand.key(garment.brand) == brand,
              colors.isEmpty || !colors.isDisjoint(with: garment.colorTags) else { return false }
        return garment.matches(search: search)
    }
}
