import Foundation
import SwiftData
import WearwiseCore

struct GarmentDraft: Equatable {
    var name: String
    var category: String
    var colorTags: Set<String>
    var brand: String
    var size: String
    var seasons: Set<String>
    var status: String
    var price: String
    var currency: String
    var acquisitionDate: Date?
    var acquisitionPrecision: String
    var firstUseDate: Date?
    var firstUsePrecision: String
    var condition: String
    var notes: String
    var openingWearCount: String
    var openingWearIsEstimate: Bool
    var costReference: String
    var durationReferenceYears: String

    init(_ garment: Garment) {
        name = garment.name
        category = garment.category
        colorTags = Set(garment.colorTags)
        brand = garment.brand
        size = garment.size
        seasons = Set(garment.seasons)
        status = garment.status
        price = garment.amount?.formatted(.number.precision(.fractionLength(0...38)).grouping(.never)) ?? ""
        currency = garment.currency
        acquisitionDate = garment.acquisitionDate
        acquisitionPrecision = garment.acquisitionPrecision
        firstUseDate = garment.firstUseDate
        firstUsePrecision = garment.firstUsePrecision
        condition = garment.condition
        notes = garment.notes
        openingWearCount = String(garment.openingWearCount)
        openingWearIsEstimate = garment.openingWearIsEstimate
        costReference = garment.costReference?.formatted(.number.precision(.fractionLength(0...38)).grouping(.never)) ?? ""
        durationReferenceYears = garment.durationReferenceYears.map(String.init) ?? ""
    }

    func apply(to garment: Garment) throws {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { throw GarmentStoreError.invalidName }
        guard let count = Int(openingWearCount), count >= 0 else {
            throw GarmentStoreError.invalidWearCount
        }
        let amount = try ValueInput.amount(price)
        let reference = try ValueInput.amount(costReference)
        let code = currency.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCurrency = code.isEmpty ? "" : try ValueInput.currency(code)
        let cleanYears = durationReferenceYears.trimmingCharacters(in: .whitespacesAndNewlines)
        let years: Int?
        if cleanYears.isEmpty { years = nil }
        else {
            guard let value = Int(cleanYears), value >= 0 else { throw ValueInputError.invalidReferenceYears }
            years = value
        }
        _ = try WearMetrics.summary(price: amount, openingWears: count, openingIsEstimated: openingWearIsEstimate, recordedWears: garment.wearRecords.count)
        for (date, precision) in [(acquisitionDate, acquisitionPrecision), (firstUseDate, firstUsePrecision)] {
            guard let date else { continue }
            guard let precision = DatePrecision(rawValue: precision) else { throw MetricsError.invalidDateRange }
            _ = try WearMetrics.duration(from: date, precision: precision, through: Date(), referenceYears: years, calendar: .current)
        }
        garment.name = cleanName
        garment.category = category.trimmingCharacters(in: .whitespacesAndNewlines)
        garment.colorTags = colorTags.sorted()
        garment.brand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        garment.size = size.trimmingCharacters(in: .whitespacesAndNewlines)
        garment.seasons = seasons.sorted()
        garment.status = status
        garment.amount = amount
        garment.currency = cleanCurrency
        garment.costReference = reference
        garment.durationReferenceYears = years
        garment.acquisitionDate = acquisitionDate
        garment.acquisitionPrecision = acquisitionPrecision
        garment.firstUseDate = firstUseDate
        garment.firstUsePrecision = firstUsePrecision
        garment.condition = condition
        garment.notes = notes
        let countChanged = count != garment.openingWearCount
        garment.openingWearCount = count
        garment.openingWearIsEstimate = countChanged ? count > 0 : openingWearIsEstimate
        garment.updatedAt = Date()
    }
}

@MainActor
struct GarmentStore {
    let context: ModelContext
    var assets: AssetStore = .shared

    func update(_ garment: Garment, draft: GarmentDraft) throws {
        let previous = (name: garment.name, category: garment.category, colors: garment.colorTags, brand: garment.brand,
            size: garment.size, seasons: garment.seasons, status: garment.status, amount: garment.amount, currency: garment.currency,
            acquired: garment.acquisitionDate, acquisitionPrecision: garment.acquisitionPrecision, firstUse: garment.firstUseDate,
            firstUsePrecision: garment.firstUsePrecision, condition: garment.condition, notes: garment.notes,
            count: garment.openingWearCount, estimated: garment.openingWearIsEstimate, costReference: garment.costReference,
            yearReference: garment.durationReferenceYears, updatedAt: garment.updatedAt, brandRecord: garment.brandRecord)
        do {
            try draft.apply(to: garment)
            garment.brandRecord = try context.fetch(FetchDescriptor<Brand>()).first { $0.normalizedName == Brand.key(garment.brand) }
            try context.save()
        } catch {
            garment.name = previous.name
            garment.category = previous.category
            garment.colorTags = previous.colors
            garment.brand = previous.brand
            garment.size = previous.size
            garment.seasons = previous.seasons
            garment.status = previous.status
            garment.amount = previous.amount
            garment.currency = previous.currency
            garment.acquisitionDate = previous.acquired
            garment.acquisitionPrecision = previous.acquisitionPrecision
            garment.firstUseDate = previous.firstUse
            garment.firstUsePrecision = previous.firstUsePrecision
            garment.condition = previous.condition
            garment.notes = previous.notes
            garment.openingWearCount = previous.count
            garment.openingWearIsEstimate = previous.estimated
            garment.costReference = previous.costReference
            garment.durationReferenceYears = previous.yearReference
            garment.updatedAt = previous.updatedAt
            garment.brandRecord = previous.brandRecord
            context.rollback()
            throw error
        }
    }

    func saveImages(original: Data, cutout: Data, on garment: Garment) throws {
        let previousOriginal = garment.originalAsset
        let previousCutout = garment.cutoutAsset
        let previousUpdatedAt = garment.updatedAt
        let originalRecord = try assets.savePNG(original, id: UUID())
        let originalURL = assets.url(for: originalRecord)
        let cutoutRecord: AssetRecord
        do {
            cutoutRecord = try assets.savePNG(cutout, id: UUID())
        } catch {
            try assets.remove(originalRecord)
            throw error
        }
        let cutoutURL = assets.url(for: cutoutRecord)
        do {
            context.insert(originalRecord)
            context.insert(cutoutRecord)
            garment.originalAsset = originalRecord
            garment.cutoutAsset = cutoutRecord
            garment.updatedAt = Date()
            context.insert(garment)
            try context.save()
        } catch {
            garment.originalAsset = previousOriginal
            garment.cutoutAsset = previousCutout
            garment.updatedAt = previousUpdatedAt
            context.rollback()
            try FileManager.default.removeItem(at: originalURL)
            try FileManager.default.removeItem(at: cutoutURL)
            throw error
        }
    }

    func retire(_ garment: Garment) throws {
        var draft = GarmentDraft(garment)
        draft.status = GarmentStatus.retired
        try update(garment, draft: draft)
    }

    func delete(_ garment: Garment) throws {
        guard garment.openingWearCount == 0, garment.outfits.isEmpty, garment.journalEntries.isEmpty, garment.wearRecords.isEmpty else { throw GarmentStoreError.retirementRequired }
        let remaining = try context.fetch(FetchDescriptor<Garment>()).filter { $0.id != garment.id }
        let retained = Set(remaining.flatMap { [$0.originalAsset?.id, $0.cutoutAsset?.id].compactMap { $0 } })
        let currentAssets = [garment.originalAsset, garment.cutoutAsset].compactMap { $0 }
        let previous = (original: garment.originalAsset, cutout: garment.cutoutAsset, brand: garment.brandRecord)
        var seen = Set<UUID>()
        let unused = currentAssets.filter { !retained.contains($0.id) && $0.outfits.isEmpty && $0.journalEntries.isEmpty && $0.brands.isEmpty && $0.inspirationBrands.isEmpty && $0.renderedEntries.isEmpty && seen.insert($0.id).inserted }
        let unusedFiles = unused.map { assets.url(for: $0) }
        do {
            context.delete(garment)
            for asset in unused { context.delete(asset) }
            context.processPendingChanges()
            try context.save()
        } catch {
            context.rollback()
            garment.originalAsset = previous.original
            garment.cutoutAsset = previous.cutout
            garment.brandRecord = previous.brand
            throw error
        }
        var cleanupErrors: [String] = []
        for file in unusedFiles {
            do { if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) } }
            catch { cleanupErrors.append(error.localizedDescription) }
        }
        if !cleanupErrors.isEmpty { throw GarmentStoreError.assetCleanupFailed(cleanupErrors.joined(separator: "\n")) }
    }
}

enum GarmentStoreError: LocalizedError {
    case invalidName, invalidPrice, invalidCurrency, invalidWearCount, retirementRequired
    case assetCleanupFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidName: "Enter a garment name."
        case .invalidPrice: "Enter a price of zero or more, or leave it empty if unknown."
        case .invalidCurrency: "Enter a three-letter currency code, such as EUR, SEK, or CNY."
        case .invalidWearCount: "Enter a whole number of zero or more for earlier wears."
        case .retirementRequired: "This garment has saved outfits or wear history. Retire it to preserve its records."
        case .assetCleanupFailed(let detail): "The item was deleted. Some image files could not be removed: \(detail)"
        }
    }
}
