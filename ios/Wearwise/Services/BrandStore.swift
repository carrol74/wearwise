import Foundation
import SwiftData

struct BrandDraft: Equatable {
    var name = ""
    var website = ""
    var notes = ""
    var fitNotes = ""
    var sizingNotes = ""
    var fabricNotes = ""
    var priceNotes = ""
    var interest = "Want to try"

    init(_ brand: Brand? = nil, name: String = "") {
        self.name = brand?.name ?? name
        website = brand?.website ?? ""
        notes = brand?.notes ?? ""
        fitNotes = brand?.fitNotes ?? ""
        sizingNotes = brand?.sizingNotes ?? ""
        fabricNotes = brand?.fabricNotes ?? ""
        priceNotes = brand?.priceNotes ?? ""
        interest = brand?.interest ?? "Want to try"
    }
}

@MainActor
struct BrandStore {
    let context: ModelContext
    var assets: AssetStore = .shared

    @discardableResult
    func save(_ draft: BrandDraft, updating brand: Brand? = nil, inspirations: [Data] = [], removing imageIDs: Set<UUID> = []) throws -> Brand {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw BrandError.invalidName }
        let key = Brand.key(name)
        guard !((try context.fetch(FetchDescriptor<Brand>())).contains { $0.id != brand?.id && $0.normalizedName == key }) else {
            throw BrandError.duplicateName
        }
        let website = Self.websiteAddress(draft.website)
        let garments = try context.fetch(FetchDescriptor<Garment>())
        let oldKey = brand?.normalizedName
        let previous = brand.map { (name: $0.name, key: $0.normalizedName, website: $0.website, notes: $0.notes,
            fit: $0.fitNotes, sizing: $0.sizingNotes, fabric: $0.fabricNotes, price: $0.priceNotes, interest: $0.interest, updatedAt: $0.updatedAt, inspiration: $0.inspirationAsset, additional: $0.additionalInspirationAssets, garments: $0.garments) }
        let matching = garments.filter { (brand != nil && $0.brandRecord?.id == brand?.id) || Brand.key($0.brand) == key || (oldKey != nil && Brand.key($0.brand) == oldKey) }
        let previousGarments = matching.map { (item: $0, name: $0.brand, record: $0.brandRecord, updatedAt: $0.updatedAt) }
        let existing = brand?.inspirations ?? []
        let removed = existing.filter { imageIDs.contains($0.id) }
        let unused = removed.filter { isUnused($0, excluding: brand?.id, garments: garments) }
        let unusedFiles = unused.map { assets.url(for: $0) }
        var added: [AssetRecord] = []
        do {
            for data in inspirations {
                added.append(try assets.savePNG(ImageImportService.normalizedPNG(from: data), id: UUID()))
            }
        } catch {
            for asset in added { try assets.remove(asset) }
            throw error
        }
        let retained = existing.filter { !imageIDs.contains($0.id) } + added
        let result = brand ?? Brand(name: name)
        do {
            result.name = name
            result.normalizedName = key
            result.website = website
            result.notes = draft.notes
            result.fitNotes = draft.fitNotes
            result.sizingNotes = draft.sizingNotes
            result.fabricNotes = draft.fabricNotes
            result.priceNotes = draft.priceNotes
            result.interest = draft.interest
            result.updatedAt = Date()
            for asset in added { context.insert(asset) }
            result.inspirationAsset = retained.first
            result.additionalInspirationAssets = Array(retained.dropFirst())
            for asset in unused { context.delete(asset) }
            if brand == nil { context.insert(result) }
            for garment in matching {
                garment.brandRecord = result
                garment.brand = name
                garment.updatedAt = Date()
            }
            try context.save()
        } catch {
            for saved in previousGarments {
                saved.item.brand = saved.name
                saved.item.brandRecord = saved.record
                saved.item.updatedAt = saved.updatedAt
            }
            if let brand, let previous {
                brand.name = previous.name
                brand.normalizedName = previous.key
                brand.website = previous.website
                brand.notes = previous.notes
                brand.fitNotes = previous.fit
                brand.sizingNotes = previous.sizing
                brand.fabricNotes = previous.fabric
                brand.priceNotes = previous.price
                brand.interest = previous.interest
                brand.updatedAt = previous.updatedAt
                brand.inspirationAsset = previous.inspiration
                brand.additionalInspirationAssets = previous.additional
                brand.garments = previous.garments
            }
            context.rollback()
            for asset in added { try assets.remove(asset) }
            throw error
        }
        if let warning = cleanup(unusedFiles) { throw BrandError.assetCleanupFailed(warning) }
        return result
    }

    func link(_ garments: [Garment], to brand: Brand) throws {
        guard garments.allSatisfy({ $0.status == GarmentStatus.owned || $0.status == GarmentStatus.candidate }) else {
            throw BrandError.unavailableGarment
        }
        let previous = garments.map { (item: $0, name: $0.brand, record: $0.brandRecord, updatedAt: $0.updatedAt) }
        do {
            for garment in garments {
                garment.brandRecord = brand
                garment.brand = brand.name
                garment.updatedAt = Date()
            }
            try context.save()
        } catch {
            for saved in previous {
                saved.item.brand = saved.name
                saved.item.brandRecord = saved.record
                saved.item.updatedAt = saved.updatedAt
            }
            context.rollback()
            throw error
        }
    }

    @discardableResult
    func delete(_ brand: Brand) throws -> String? {
        let linked = brand.garments
        let images = brand.inspirations
        let primary = brand.inspirationAsset
        let additional = brand.additionalInspirationAssets
        let allGarments = try context.fetch(FetchDescriptor<Garment>())
        let unused = images.filter { isUnused($0, excluding: brand.id, garments: allGarments) }
        let unusedFiles = unused.map { assets.url(for: $0) }
        do {
            for garment in linked { garment.brandRecord = nil }
            brand.inspirationAsset = nil
            brand.additionalInspirationAssets = []
            context.delete(brand)
            for image in unused { context.delete(image) }
            context.processPendingChanges()
            try context.save()
        } catch {
            context.rollback()
            brand.inspirationAsset = primary
            brand.additionalInspirationAssets = additional
            brand.garments = linked
            for garment in linked { garment.brandRecord = brand }
            throw error
        }
        return cleanup(unusedFiles).map { "The brand was deleted. Some unused inspiration files could not be removed: \($0)" }
    }

    private func isUnused(_ asset: AssetRecord, excluding brandID: UUID?, garments: [Garment]) -> Bool {
        asset.outfits.isEmpty && asset.journalEntries.isEmpty && asset.renderedEntries.isEmpty
            && (asset.brands + asset.inspirationBrands).allSatisfy { $0.id == brandID }
            && !garments.contains { $0.originalAsset?.id == asset.id || $0.cutoutAsset?.id == asset.id }
    }

    private func cleanup(_ files: [URL]) -> String? {
        var errors: [String] = []
        for file in files {
            do { if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) } }
            catch { errors.append(error.localizedDescription) }
        }
        return errors.isEmpty ? nil : errors.joined(separator: "\n")
    }

    private static let websiteLinks = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    static func websiteAddress(_ text: String) -> String {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for match in websiteLinks.matches(in: value, range: NSRange(value.startIndex..., in: value)) {
            guard let range = Range(match.range, in: value), match.url?.host?.isEmpty == false else { continue }
            let address = String(value[range]), lowercased = address.lowercased()
            if lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://") { return address }
        }
        return value
    }

    static func websiteURL(_ text: String) -> URL? {
        let value = websiteAddress(text)
        guard !value.isEmpty else { return nil }
        let resolved = value.contains("://") ? value : "https://" + value
        guard let url = URL(string: resolved), let host = url.host, !host.isEmpty, ["https", "http"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        return url
    }

}

enum BrandError: LocalizedError {
    case invalidName, duplicateName, unavailableGarment
    case assetCleanupFailed(String)
    var errorDescription: String? {
        switch self {
        case .assetCleanupFailed(let detail): "The brand was saved. Some unused inspiration files could not be removed: \(detail)"
        case .invalidName: "Enter a brand name."
        case .duplicateName: "This brand is already saved. Open its existing record to edit it."
        case .unavailableGarment: "A selected garment is no longer available. Reopen the garment selection."
        }
    }
}
