import Foundation

enum GarmentCategory {
    struct Group: Identifiable {
        let title: String
        let categories: [String]
        var id: String { title }
    }

    static let groups = [
        Group(title: "Tops", categories: ["T-shirt", "Shirt", "Blouse", "Tank top", "Sweater", "Cardigan", "Hoodie", "Sweatshirt"]),
        Group(title: "Outerwear", categories: ["Jacket", "Coat", "Blazer"]),
        Group(title: "Bottoms", categories: ["Jeans", "Trousers", "Shorts", "Skirt", "Leggings"]),
        Group(title: "One-piece", categories: ["Dress", "Jumpsuit"]),
        Group(title: "Shoes", categories: ["Sneakers", "Boots", "Sandals", "Shoes"]),
        Group(title: "Bags and accessories", categories: ["Bag", "Hat", "Scarf", "Belt", "Gloves", "Jewelry"]),
        Group(title: "Underwear and swimwear", categories: ["Underwear", "Bra", "Socks", "Swimsuit"]),
        Group(title: "Other", categories: ["Other"])
    ]

    static let all = groups.flatMap(\.categories)
}
