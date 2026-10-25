import Foundation
import SwiftData
import WearwiseCore

@MainActor
struct ShoppingStore {
    let context: ModelContext
    var assets: AssetStore = .shared

    func addToWardrobe(_ item: Garment, price: String, currency: String, acquired: Date?, defaults: WardrobeDefaults = WardrobeDefaults()) throws {
        guard item.status == GarmentStatus.candidate else { throw ShoppingError.notShoppingItem }
        try defaults.validate()
        var draft = GarmentDraft(item)
        draft.price = price
        draft.currency = currency
        draft.acquisitionDate = acquired
        draft.acquisitionPrecision = "exact"
        draft.status = GarmentStatus.owned
        if item.costReference == nil, currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == defaults.currency {
            draft.costReference = defaults.costReference?.formatted(.number.precision(.fractionLength(0...38)).grouping(.never)) ?? ""
        }
        if item.durationReferenceYears == nil { draft.durationReferenceYears = defaults.yearReference.map(String.init) ?? "" }
        try GarmentStore(context: context, assets: assets).update(item, draft: draft)
    }

    func remove(_ item: Garment) throws {
        guard item.status == GarmentStatus.candidate else { throw ShoppingError.notShoppingItem }
        let store = GarmentStore(context: context, assets: assets)
        if item.outfits.isEmpty && item.journalEntries.isEmpty && item.wearRecords.isEmpty && item.openingWearCount == 0 {
            try store.delete(item)
        } else {
            var draft = GarmentDraft(item)
            draft.status = GarmentStatus.discarded
            try store.update(item, draft: draft)
        }
    }
}

enum ShoppingError: LocalizedError {
    case notShoppingItem
    var errorDescription: String? { "This item is no longer in Shopping. Reopen it from its current collection." }
}


struct ShoppingOffer: Codable, Equatable, Identifiable {
    var id = UUID()
    var retailer: String
    var website: String
    var amount: Decimal?
    var currency: String

    var priceLabel: String {
        amount.map { MoneyText.format($0, currency: currency) } ?? "Price not recorded"
    }
}

extension ShoppingStore {
    func offers(for item: Garment) throws -> [ShoppingOffer] {
        guard let data = item.shoppingOffersData else { return [] }
        return try JSONDecoder().decode([ShoppingOffer].self, from: data)
    }

    func saveOffer(for item: Garment, id: UUID? = nil, retailer: String, website: String,
        price: String, currency: String) throws {
        guard item.status == GarmentStatus.candidate else { throw ShoppingError.notShoppingItem }
        let address = BrandStore.websiteAddress(website)
        let amount = try ValueInput.amount(price)
        let rawCode = currency.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = rawCode.isEmpty ? "" : try ValueInput.currency(rawCode)
        var values = try offers(for: item)
        let offer = ShoppingOffer(id: id ?? UUID(), retailer: retailer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (BrandStore.websiteURL(address)?.host ?? address) : retailer.trimmingCharacters(in: .whitespacesAndNewlines), website: address, amount: amount, currency: code)
        if let index = values.firstIndex(where: { $0.id == offer.id }) { values[index] = offer }
        else { values.append(offer) }
        try writeOffers(values, to: item)
    }

    func deleteOffer(_ id: UUID, from item: Garment) throws {
        guard item.status == GarmentStatus.candidate else { throw ShoppingError.notShoppingItem }
        try writeOffers(offers(for: item).filter { $0.id != id }, to: item)
    }

    private func writeOffers(_ values: [ShoppingOffer], to item: Garment) throws {
        let previous = item.shoppingOffersData, updated = item.updatedAt
        do {
            item.shoppingOffersData = try JSONEncoder().encode(values)
            item.updatedAt = Date()
            try context.save()
        } catch {
            item.shoppingOffersData = previous
            item.updatedAt = updated
            context.rollback()
            throw error
        }
    }
}
