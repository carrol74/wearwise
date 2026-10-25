import Foundation
import SwiftData
import UIKit
import WearwiseCore

@MainActor
struct OutfitStore {
    let context: ModelContext
    var assets: AssetStore = .shared

    func layer(for garment: Garment, in canvas: FlatlayComposition) throws -> CompositionLayer {
        guard garment.status == GarmentStatus.owned || garment.status == GarmentStatus.candidate else {
            throw OutfitStoreError.retiredGarment
        }
        guard let asset = garment.cutoutAsset ?? garment.originalAsset else { throw OutfitStoreError.missingImage }
        guard asset.pixelWidth > 0, asset.pixelHeight > 0 else { throw OutfitStoreError.missingImage }
        try canvas.validate()
        let width = 0.36
        let height = width * canvas.width / canvas.height * Double(asset.pixelHeight) / Double(asset.pixelWidth)
        return CompositionLayer(assetID: asset.id, garmentID: garment.id, width: width, height: height)
    }

    @discardableResult
    func save(name: String, composition: FlatlayComposition, updating outfit: Outfit? = nil, from journal: JournalEntry? = nil) throws -> Outfit {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { throw OutfitStoreError.invalidName }
        guard !composition.layers.isEmpty else { throw OutfitStoreError.emptyComposition }
        let encoded = try composition.encoded()
        _ = try images(for: composition)
        let records = try context.fetch(FetchDescriptor<AssetRecord>()).filter { composition.assetIDs.contains($0.id) }
        let garments = try context.fetch(FetchDescriptor<Garment>()).filter { composition.garmentIDs.contains($0.id) }
        guard Set(records.map(\.id)) == composition.assetIDs else { throw OutfitStoreError.missingImage }
        guard Set(garments.map(\.id)) == composition.garmentIDs else { throw OutfitStoreError.missingGarment }
        let existingLayers = Set(try outfit?.composition().layers.map(\.id) ?? []).union(try journal?.composition().layers.map(\.id) ?? [])
        for garment in garments where garment.status != GarmentStatus.owned && garment.status != GarmentStatus.candidate {
            guard composition.layers.filter({ $0.garmentID == garment.id }).allSatisfy({ existingLayers.contains($0.id) }) else {
                throw OutfitStoreError.retiredGarment
            }
        }
        let result = outfit ?? Outfit(name: cleanName, compositionData: encoded)
        let previous = outfit.map { (name: $0.name, composition: $0.compositionData, garments: $0.garments, assets: $0.assets, updatedAt: $0.updatedAt) }
        do {
            result.name = cleanName
            result.compositionData = encoded
            result.garments = garments
            result.assets = records
            result.updatedAt = Date()
            if outfit == nil { context.insert(result) }
            try context.save()
            return result
        } catch {
            if let outfit, let previous {
                outfit.name = previous.name
                outfit.compositionData = previous.composition
                outfit.garments = previous.garments
                outfit.assets = previous.assets
                outfit.updatedAt = previous.updatedAt
            }
            context.rollback()
            throw error
        }
    }

    func images(for composition: FlatlayComposition) throws -> [UUID: UIImage] {
        let records = try context.fetch(FetchDescriptor<AssetRecord>()).filter { composition.assetIDs.contains($0.id) }
        guard Set(records.map(\.id)) == composition.assetIDs else { throw OutfitStoreError.missingImage }
        var images: [UUID: UIImage] = [:]
        for record in records {
            guard let image = UIImage(data: try assets.loadData(for: record)) else { throw OutfitStoreError.missingImage }
            images[record.id] = image
        }
        return images
    }

    func delete(_ outfit: Outfit) throws {
        let previous = (garments: outfit.garments, assets: outfit.assets)
        do {
            context.delete(outfit)
            context.processPendingChanges()
            try context.save()
        } catch {
            context.rollback()
            outfit.garments = previous.garments
            outfit.assets = previous.assets
            throw error
        }
    }
}

enum OutfitStoreError: LocalizedError {
    case invalidName, emptyComposition, missingImage, missingGarment, retiredGarment, renderingFailed

    var errorDescription: String? {
        switch self {
        case .invalidName: "Enter an outfit name."
        case .emptyComposition: "Add a garment to the canvas before saving."
        case .missingImage: "An outfit image is missing or unreadable. Check the garment's image before continuing."
        case .missingGarment: "An outfit garment could not be found."
        case .retiredGarment: "Removed items remain in saved outfits and are unavailable for new layers."
        case .renderingFailed: "The outfit image could not be rendered."
        }
    }
}
