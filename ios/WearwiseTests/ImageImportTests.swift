import Foundation
import ImageIO
import SwiftData
import SwiftUI
import UIKit
import XCTest
import WearwiseCore
@testable import Wearwise

private func garmentFixture() throws -> Data {
    let bundle = Bundle(for: ImageImportServiceTests.self)
    let url = try XCTUnwrap(bundle.url(forResource: "black-tshirt", withExtension: "jpg"))
    return try Data(contentsOf: url)
}

@MainActor
final class ImportAttributesTests: XCTestCase {
    func testImportAttributesPersistWithConfiguredCurrencyAndTargets() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let config = ModelConfiguration(url: directory.appending(path: "import.store"))
        let database = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self,
            JournalEntry.self, WearRecord.self, Brand.self, configurations: config)
        var attributes = ImportAttributes()
        attributes.name = " Wool coat "; attributes.category = "Coat"
        attributes.brand = " Arket "; attributes.size = " M "
        attributes.seasons = ["autumn", "winter"]; attributes.colors = ["black"]
        attributes.price = "120.50"; attributes.notes = "Room for a sweater"
        let item = try attributes.makeGarment(collection: .wardrobe,
            defaults: WardrobeDefaults(currency: "SEK", costReference: 4, yearReference: 3))
        database.mainContext.insert(item); try database.mainContext.save()
        let reopened = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self,
            JournalEntry.self, WearRecord.self, Brand.self, configurations: config)
        let saved = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<Garment>()).first)
        XCTAssertEqual(saved.name, "Wool coat"); XCTAssertEqual(saved.brand, "Arket")
        XCTAssertEqual(saved.size, "M"); XCTAssertEqual(saved.category, "Coat")
        XCTAssertEqual(saved.seasons, ["autumn", "winter"]); XCTAssertEqual(saved.colorTags, ["black"])
        XCTAssertEqual(saved.amount, Decimal(string: "120.50")); XCTAssertEqual(saved.currency, "SEK")
        XCTAssertEqual(saved.notes, attributes.notes)
        XCTAssertEqual(saved.costReference, 4); XCTAssertEqual(saved.durationReferenceYears, 3)
    }

    func testShoppingImportKeepsMetadataWithoutWardrobeTargets() throws {
        var attributes = ImportAttributes()
        attributes.name = "Coat"; attributes.brand = "Arket"; attributes.price = "0"
        let item = try attributes.makeGarment(collection: .shopping,
            defaults: WardrobeDefaults(currency: "USD", costReference: 4, yearReference: 3))
        XCTAssertEqual(item.status, GarmentStatus.candidate)
        XCTAssertEqual(item.brand, "Arket"); XCTAssertEqual(item.amount, 0); XCTAssertEqual(item.currency, "USD")
        XCTAssertNil(item.costReference); XCTAssertNil(item.durationReferenceYears)
    }

    func testImportPriceIsOptionalAndInvalidInputIsRejectedBeforeSaving() throws {
        var attributes = ImportAttributes(); attributes.name = "Coat"
        let item = try attributes.makeGarment(collection: .wardrobe, defaults: WardrobeDefaults())
        XCTAssertNil(item.amount); XCTAssertEqual(item.currency, "")
        attributes.price = "not a price"
        XCTAssertThrowsError(try attributes.makeGarment(collection: .wardrobe, defaults: WardrobeDefaults()))
    }
}

final class PreferencesStoreTests: XCTestCase {
    private var directory: URL!
    private var store: PreferencesStore!

    override func setUpWithError() throws {
        directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        store = PreferencesStore(fileURL: directory.appending(path: "defaults.json"))
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
    }

    func testCurrencyCatalogSearchesCodesAndNames() throws {
        let options = CurrencyOption.catalog(locale: Locale(identifier: "sv"))
        XCTAssertEqual(Set(options.map(\.code)).count, options.count)
        XCTAssertTrue(options.contains { $0.code == "USD" })
        let sek = try XCTUnwrap(options.first { $0.code == "SEK" })
        XCTAssertTrue(sek.matches(" sek "))
        XCTAssertTrue(sek.matches("Swedish"))
        XCTAssertTrue(sek.matches(sek.localizedName))
        XCTAssertFalse(options.contains { $0.matches("123notacurrency") })
        XCTAssertFalse(options.contains { ["XXX", "XTS", "USN", "USS", "VNN", "XAU", "XDR"].contains($0.code) })
        for option in options {
            var draft = PreferencesDraft(); draft.currency = option.code
            XCTAssertEqual(try draft.values().currency, option.code)
        }
    }

    func testDefaultsSaveReopenClearAndPreserveZero() throws {
        XCTAssertEqual(try store.load(), WardrobeDefaults())
        var draft = PreferencesDraft()
        draft.currency = " sek "
        draft.costReference = "5"
        draft.yearReference = "2"
        try store.save(draft)
        XCTAssertEqual(try store.load(), WardrobeDefaults(currency: "SEK", costReference: 5, yearReference: 2))
        draft.costReference = "0"
        draft.yearReference = "0"
        try store.save(draft)
        XCTAssertEqual(try store.load().costReference, 0)
        XCTAssertEqual(try store.load().yearReference, 0)
        try store.save(PreferencesDraft())
        XCTAssertEqual(try store.load(), WardrobeDefaults())
    }

    func testInvalidPreferencesPreserveSavedFile() throws {
        let saved = WardrobeDefaults(currency: "SEK", costReference: 5, yearReference: 2)
        try store.save(PreferencesDraft(saved))
        let bytes = try Data(contentsOf: store.fileURL)
        for value in ["-1", "12abc"] {
            var draft = PreferencesDraft(saved)
            draft.costReference = value
            XCTAssertThrowsError(try store.save(draft))
        }
        for value in ["-1", "1.5", "abc"] {
            var draft = PreferencesDraft(saved)
            draft.yearReference = value
            XCTAssertThrowsError(try store.save(draft))
        }
        for code in ["12", "123", "EURO"] {
            var draft = PreferencesDraft(saved)
            draft.currency = code
            XCTAssertThrowsError(try store.save(draft))
        }
        XCTAssertEqual(try Data(contentsOf: store.fileURL), bytes)
        XCTAssertEqual(try store.load(), saved)
    }

    func testActualWriteFailureAndCorruptFileAreReported() throws {
        let saved = WardrobeDefaults(currency: "SEK", costReference: 5, yearReference: 2)
        try store.save(PreferencesDraft(saved))
        let bytes = try Data(contentsOf: store.fileURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: directory.path)
        do {
            defer { try! FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path) }
            XCTAssertThrowsError(try store.save(PreferencesDraft()))
            XCTAssertEqual(try Data(contentsOf: store.fileURL), bytes)
        }
        try Data("invalid JSON".utf8).write(to: store.fileURL)
        XCTAssertThrowsError(try store.load())
    }
}

@MainActor
final class BrandLifecycleTests: XCTestCase {
    private var directory: URL!
    private var container: ModelContainer!
    private var store: BrandStore!

    override func setUpWithError() throws {
        directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        container = try ModelContainer(for: Brand.self, Garment.self, AssetRecord.self, Outfit.self, JournalEntry.self, WearRecord.self,
            configurations: ModelConfiguration(url: directory.appending(path: "brands.store")))
        store = BrandStore(context: container.mainContext, assets: AssetStore(baseURL: directory))
    }

    override func tearDownWithError() throws {
        store = nil
        container = nil
        try FileManager.default.removeItem(at: directory)
    }

    private func garment(_ name: String, brand: String, status: String = GarmentStatus.owned) throws -> Garment {
        let item = Garment(name: name, category: "Shirt", brand: brand, status: status, amount: 120, currency: "SEK")
        item.originalAsset = try store.assets.savePNG(ImageImportService.normalizedPNG(from: garmentFixture()), id: UUID())
        container.mainContext.insert(item)
        try container.mainContext.save()
        return item
    }

    func testOwnedGroupsIncludeUnsavedNamesUnknownsAndOnlyActiveWardrobe() throws {
        let first = try garment("A", brand: "COS")
        let second = try garment("B", brand: " cos ")
        let unknown = try garment("C", brand: "  ")
        _ = try garment("D", brand: "Arket", status: GarmentStatus.candidate)
        _ = try garment("E", brand: "Old", status: GarmentStatus.retired)
        _ = try garment("F", brand: "Removed", status: GarmentStatus.discarded)
        var groups = OwnedBrandGroup.groups(from: try container.mainContext.fetch(FetchDescriptor<Garment>()))
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups.first(where: { $0.id == "cos" })?.garments.map(\.id), [first.id, second.id])
        XCTAssertEqual(groups.first(where: { $0.id.isEmpty })?.name, "Unbranded")
        XCTAssertEqual(groups.first(where: { $0.id.isEmpty })?.garments.map(\.id), [unknown.id])
        try GarmentStore(context: container.mainContext, assets: store.assets).retire(first)
        groups = OwnedBrandGroup.groups(from: try container.mainContext.fetch(FetchDescriptor<Garment>()))
        XCTAssertEqual(groups.first(where: { $0.id == "cos" })?.garments.map(\.id), [second.id])
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<Brand>()).isEmpty)
    }

    func testDiscoveryAndRealInspirationReopenWithGarmentAssociations() throws {
        let item = try garment("Shirt", brand: " cos ")
        var draft = BrandDraft(name: "COS")
        draft.website = "https://example.com/collection"
        draft.notes = "Try the wool jacket."
        draft.interest = "Following"
        let brand = try store.save(draft, inspirations: [garmentFixture()])
        XCTAssertEqual(item.brandRecord?.id, brand.id)
        XCTAssertEqual(item.amount, 120)
        let asset = try XCTUnwrap(brand.inspirationAsset)
        XCTAssertNotNil(UIImage(data: try store.assets.loadData(for: asset)))
        let reopened = try ModelContainer(for: Brand.self, Garment.self, AssetRecord.self, Outfit.self, JournalEntry.self, WearRecord.self,
            configurations: ModelConfiguration(url: directory.appending(path: "brands.store")))
        let saved = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<Brand>()).first)
        XCTAssertEqual(saved.id, brand.id)
        XCTAssertEqual(saved.notes, draft.notes)
        XCTAssertEqual(saved.website, draft.website)
        XCTAssertEqual(saved.interest, "Following")
        XCTAssertEqual(saved.garments.map(\.id), [item.id])
        XCTAssertEqual(saved.inspirationAsset?.id, asset.id)
    }

    func testInvalidAndDuplicateBrandDraftsLeaveExistingDataAndFilesUnchanged() throws {
        let brand = try store.save(BrandDraft(name: "COS"), inspirations: [garmentFixture()])
        let before = try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
        var duplicate = BrandDraft(name: " cos ")
        XCTAssertThrowsError(try store.save(duplicate))
        duplicate.name = "  "
        XCTAssertThrowsError(try store.save(duplicate))
        var edit = BrandDraft(brand)
        edit.name = "Changed"
        edit.website = ""
        XCTAssertThrowsError(try store.save(edit, updating: brand, inspirations: [Data("unreadable".utf8)]))
        XCTAssertEqual(brand.name, "COS")
        XCTAssertNotNil(brand.inspirationAsset)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<Brand>()).count, 1)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted(), before)
    }

    func testSharedBrandRenameAndGarmentReassignmentPreserveOtherAttributes() throws {
        let item = try garment("Shirt", brand: "COS")
        item.openingWearCount = 12
        item.condition = "worn"
        let image = item.originalAsset?.id
        let brand = try store.save(BrandDraft(name: "COS"))
        var edit = BrandDraft(brand)
        edit.name = "COS Studio"
        try store.save(edit, updating: brand)
        XCTAssertEqual(item.brand, "COS Studio")
        XCTAssertEqual(item.brandRecord?.id, brand.id)
        XCTAssertEqual(item.name, "Shirt")
        XCTAssertEqual(item.openingWearCount, 12)
        XCTAssertEqual(item.condition, "worn")
        XCTAssertEqual(item.amount, 120)
        XCTAssertEqual(item.originalAsset?.id, image)
        let other = try store.save(BrandDraft(name: "Arket"))
        var garmentDraft = GarmentDraft(item)
        garmentDraft.brand = " arket "
        try GarmentStore(context: container.mainContext, assets: store.assets).update(item, draft: garmentDraft)
        XCTAssertEqual(item.brandRecord?.id, other.id)
        XCTAssertTrue(brand.garments.isEmpty)
        XCTAssertEqual(other.garments.map(\.id), [item.id])
        garmentDraft = GarmentDraft(item)
        garmentDraft.brand = ""
        try GarmentStore(context: container.mainContext, assets: store.assets).update(item, draft: garmentDraft)
        XCTAssertNil(item.brandRecord)
        XCTAssertTrue(other.garments.isEmpty)
    }

    func testLinkingPreservesCandidateStatusAndRejectsUnavailableItemsAtomically() throws {
        let brand = try store.save(BrandDraft(name: "Arket"))
        let item = try garment("Candidate", brand: "", status: GarmentStatus.candidate)
        let retired = try garment("Retired", brand: "Old", status: GarmentStatus.retired)
        XCTAssertThrowsError(try store.link([item, retired], to: brand))
        XCTAssertNil(item.brandRecord)
        XCTAssertEqual(item.brand, "")
        try store.link([item], to: brand)
        XCTAssertEqual(item.brandRecord?.id, brand.id)
        XCTAssertEqual(item.brand, "Arket")
        XCTAssertEqual(item.status, GarmentStatus.candidate)
        XCTAssertEqual(item.amount, 120)
        XCTAssertTrue(item.wearRecords.isEmpty)
    }

    func testRealImageWriteFailurePreservesExistingBrand() throws {
        let brand = try store.save(BrandDraft(name: "COS"), inspirations: [garmentFixture()])
        let image = brand.inspirationAsset?.id
        let blocker = directory.appending(path: "asset-location-file")
        try Data("file instead of directory".utf8).write(to: blocker)
        let unavailable = BrandStore(context: container.mainContext, assets: AssetStore(baseURL: blocker))
        var draft = BrandDraft(brand)
        draft.name = "Changed"
        XCTAssertThrowsError(try unavailable.save(draft, updating: brand, inspirations: [garmentFixture()]))
        XCTAssertEqual(brand.name, "COS")
        XCTAssertEqual(brand.inspirationAsset?.id, image)
        XCTAssertNotNil(UIImage(data: try store.assets.loadData(for: XCTUnwrap(brand.inspirationAsset))))
    }

    func testFailedBrandMetadataSavePreservesLinksAndRemovesNewImage() throws {
        let item = try garment("Shirt", brand: "COS")
        let brand = try store.save(BrandDraft(name: "COS"), inspirations: [garmentFixture()])
        let brandID = brand.id
        let originalImage = brand.inspirationAsset?.id
        let before = try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasSuffix(".png") }.sorted()
        let readOnly = try ModelContainer(for: Brand.self, Garment.self, AssetRecord.self, Outfit.self, JournalEntry.self, WearRecord.self,
            configurations: ModelConfiguration(url: directory.appending(path: "brands.store"), allowsSave: false))
        let saved = try XCTUnwrap(readOnly.mainContext.fetch(FetchDescriptor<Brand>()).first)
        let linked = try XCTUnwrap(readOnly.mainContext.fetch(FetchDescriptor<Garment>()).first)
        var draft = BrandDraft(saved)
        draft.name = "Do not save"
        draft.notes = "Do not save these notes"
        XCTAssertThrowsError(try BrandStore(context: readOnly.mainContext, assets: store.assets).save(draft, updating: saved, inspirations: [garmentFixture()]))
        XCTAssertEqual(saved.name, "COS")
        XCTAssertEqual(saved.notes, "")
        XCTAssertEqual(saved.inspirationAsset?.id, originalImage)
        XCTAssertEqual(saved.garments.map(\.id), [item.id])
        XCTAssertEqual(linked.brand, "COS")
        XCTAssertEqual(linked.brandRecord?.id, brandID)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasSuffix(".png") }.sorted(), before)
        XCTAssertFalse(readOnly.mainContext.hasChanges)
    }

    func testMultipleInspirationsPersistAndRemovalCleansOnlyRemovedFiles() throws {
        let brand = try store.save(BrandDraft(name: "Multiple photos"), inspirations: [garmentFixture(), garmentFixture(), garmentFixture()])
        let ids = brand.inspirations.map(\.id)
        let files = brand.inspirations.map { store.assets.url(for: $0) }
        XCTAssertEqual(ids.count, 3)
        let reopened = try ModelContainer(for: Brand.self, Garment.self, AssetRecord.self, Outfit.self, JournalEntry.self, WearRecord.self,
            configurations: ModelConfiguration(url: directory.appending(path: "brands.store")))
        let saved = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<Brand>()).first)
        XCTAssertEqual(saved.inspirations.map(\.id), ids)
        for image in saved.inspirations { XCTAssertNotNil(UIImage(data: try store.assets.loadData(for: image))) }
        try store.save(BrandDraft(brand), updating: brand, removing: [ids[0]])
        XCTAssertEqual(brand.inspirations.map(\.id), Array(ids.dropFirst()))
        XCTAssertFalse(FileManager.default.fileExists(atPath: files[0].path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: files[1].path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: files[2].path))
        try store.save(BrandDraft(brand), updating: brand, removing: Set(ids.dropFirst()))
        XCTAssertTrue(brand.inspirations.isEmpty)
        XCTAssertTrue(files.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) })
    }

    func testFailedMultiImageBatchLeavesExistingCollectionAndFilesUnchanged() throws {
        let brand = try store.save(BrandDraft(name: "Existing photo"), inspirations: [garmentFixture()])
        let ids = brand.inspirations.map(\.id)
        let before = try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasSuffix(".png") }.sorted()
        XCTAssertThrowsError(try store.save(BrandDraft(brand), updating: brand,
            inspirations: [garmentFixture(), Data("invalid image".utf8)], removing: Set(ids)))
        XCTAssertEqual(brand.inspirations.map(\.id), ids)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasSuffix(".png") }.sorted(), before)
        XCTAssertFalse(container.mainContext.hasChanges)
    }

    func testAdditionalInspirationSharedWithAnotherBrandSurvivesDeletion() throws {
        let first = try store.save(BrandDraft(name: "First"), inspirations: [garmentFixture(), garmentFixture()])
        let images = first.inspirations
        let shared = images[1]
        let second = Brand(name: "Second")
        second.inspirationAsset = shared
        container.mainContext.insert(second)
        try container.mainContext.save()
        XCTAssertEqual(shared.inspirationBrands.map(\.id), [first.id])
        XCTAssertNil(try store.delete(first))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.assets.url(for: images[0]).path))
        XCTAssertEqual(second.inspirations.map(\.id), [shared.id])
        XCTAssertNotNil(UIImage(data: try store.assets.loadData(for: shared)))
        XCTAssertNil(try store.delete(second))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.assets.url(for: shared).path))
    }

    func testFailedMultiImageMetadataSaveRestoresEntireCollection() throws {
        let brand = try store.save(BrandDraft(name: "Existing photos"), inspirations: [garmentFixture(), garmentFixture()])
        let ids = brand.inspirations.map(\.id)
        let before = try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasSuffix(".png") }.sorted()
        let readOnly = try ModelContainer(for: Brand.self, Garment.self, AssetRecord.self, Outfit.self, JournalEntry.self, WearRecord.self,
            configurations: ModelConfiguration(url: directory.appending(path: "brands.store"), allowsSave: false))
        let saved = try XCTUnwrap(readOnly.mainContext.fetch(FetchDescriptor<Brand>()).first)
        XCTAssertThrowsError(try BrandStore(context: readOnly.mainContext, assets: store.assets).save(BrandDraft(saved), updating: saved,
            inspirations: [garmentFixture()], removing: [ids[0]]))
        XCTAssertEqual(saved.inspirations.map(\.id), ids)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasSuffix(".png") }.sorted(), before)
        XCTAssertFalse(readOnly.mainContext.hasChanges)
    }

    func testWebsiteOpeningAcceptsAnOmittedScheme() {
        XCTAssertEqual(BrandStore.websiteURL("https://example.com/collection")?.host, "example.com")
        XCTAssertEqual(BrandStore.websiteURL("www.example.com/collection")?.absoluteString, "https://www.example.com/collection")
        XCTAssertNil(BrandStore.websiteURL("file:///tmp/image.png"))
        XCTAssertNil(BrandStore.websiteURL(""))
    }

}

@MainActor
final class AssetStoreTests: XCTestCase {
    func testSaveAndReloadRealPhoto() throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        let store = AssetStore(baseURL: directory)
        defer { try! FileManager.default.removeItem(at: directory) }
        let photo = try XCTUnwrap(UIImage(data: garmentFixture()))
        let data = try XCTUnwrap(photo.pngData())
        let record = try store.savePNG(data, id: UUID())
        let reloaded = try store.loadData(for: record)
        XCTAssertEqual(reloaded, data)
        XCTAssertEqual(record.pixelWidth, Int(photo.size.width * photo.scale))
        XCTAssertEqual(record.pixelHeight, Int(photo.size.height * photo.scale))
    }

    func testRecordsReopenAndRetirementHidesOnlyWardrobeEntry() throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try! FileManager.default.removeItem(at: directory) }
        let configuration = ModelConfiguration(url: directory.appending(path: "wardrobe.store"))
        let container = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self, configurations: configuration)
        let image = try XCTUnwrap(UIImage(data: garmentFixture()))
        let asset = try AssetStore(baseURL: directory).savePNG(try XCTUnwrap(image.pngData()), id: UUID())
        let garment = Garment(name: "Black T-shirt", category: "T-shirt", colorTags: ["black"], seasons: ["spring", "summer"], amount: 120, currency: "EUR")
        garment.cutoutAsset = asset
        container.mainContext.insert(garment)
        try container.mainContext.save()

        let reopened = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self, configurations: configuration)
        let fetched = try reopened.mainContext.fetch(FetchDescriptor<Garment>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Black T-shirt")
        XCTAssertEqual(fetched.first?.colorTags, ["black"])
        XCTAssertEqual(fetched.first?.seasons, ["spring", "summer"])
        XCTAssertEqual(fetched.first?.amount, 120)
        XCTAssertEqual(fetched.first?.currency, "EUR")
        XCTAssertEqual(fetched.first?.cutoutAsset?.relativePath, asset.relativePath)

        fetched[0].status = GarmentStatus.retired
        try reopened.mainContext.save()
        let active = FetchDescriptor<Garment>(predicate: #Predicate { $0.status != "retired" })
        XCTAssertTrue(try reopened.mainContext.fetch(active).isEmpty)
        XCTAssertEqual(try reopened.mainContext.fetch(FetchDescriptor<Garment>()).count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appending(path: asset.relativePath).path))
    }
}

@MainActor
final class LocalGarmentMaterialTests: XCTestCase {
    private func materials() throws -> [URL] {
        guard let directory = Bundle(for: Self.self).resourceURL?.appending(path: "LocalGarments"),
              FileManager.default.fileExists(atPath: directory.path) else {
            throw XCTSkip("Run scripts/test-garment-materials.py to stage the ignored local image corpus.")
        }
        let names = try JSONDecoder().decode([String].self,
            from: Data(contentsOf: directory.appending(path: "manifest.json")))
        XCTAssertFalse(names.isEmpty)
        return names.map { directory.appending(path: $0) }
    }

    private func container(at directory: URL) throws -> ModelContainer {
        try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self,
            JournalEntry.self, WearRecord.self, Brand.self,
            configurations: ModelConfiguration(url: directory.appending(path: "materials.store")))
    }

    func testLocalCutoutsCombineWithCharactersAndTransforms() throws {
        struct Look: Decodable {
            let name: String
            let background: String
            let garments: [String]
        }
        let inputs = try materials()
        let plan = try XCTUnwrap(Bundle(for: Self.self).resourceURL).appending(path: "LocalGarments/looks.json")
        guard FileManager.default.fileExists(atPath: plan.path) else {
            throw XCTSkip("Stage a cutout corpus and a look plan with --looks.")
        }
        let looks = try JSONDecoder().decode([Look].self, from: Data(contentsOf: plan))
        XCTAssertFalse(looks.isEmpty)
        var imagesByName: [String: UIImage] = [:]
        for input in inputs {
            let image = try XCTUnwrap(UIImage(data: Data(contentsOf: input)))
            let cg = try XCTUnwrap(image.cgImage)
            var pixels = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
            try pixels.withUnsafeMutableBytes { bytes in
                let bitmap = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: cg.width, height: cg.height,
                    bitsPerComponent: 8, bytesPerRow: cg.width * 4,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
                bitmap.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
            }
            XCTAssertTrue(stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] < 32 }, input.lastPathComponent)
            XCTAssertTrue(stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 224 }, input.lastPathComponent)
            imagesByName[input.lastPathComponent] = image
        }
        for look in looks {
            XCTAssertEqual(look.garments.count, 3)
            for gender in CharacterGender.allCases {
                var appearance = CharacterAppearance()
                appearance.gender = gender
                appearance.hairstyle = gender == .male ? .cropped : .bob
                appearance.height = .tall
                appearance.build = .slender
                let character = try XCTUnwrap(UIImage(data: CharacterStickerStore.png(appearance)))
                let characterID = UUID()
                var images = [characterID: character]
                var canvas = FlatlayComposition(background: try XCTUnwrap(CanvasBackground(rawValue: look.background)))
                let positions: [(Double, Double, Double)] = [(0.27, 0.30, 0.43), (0.72, 0.43, 0.27), (0.27, 0.76, 0.43)]
                for (index, name) in look.garments.enumerated() {
                    let image = try XCTUnwrap(imagesByName[name], "Missing cutout: \(name)")
                    let id = UUID()
                    images[id] = image
                    let (x, y, width) = positions[index]
                    canvas.layers.append(CompositionLayer(assetID: id, x: x, y: y, width: width,
                        height: width * canvas.width / canvas.height * image.size.height / image.size.width))
                }
                let clothesOnly = try FlatlayRenderer.png(composition: canvas, images: images)
                canvas.layers.append(CompositionLayer(assetID: characterID, x: 0.78, y: 0.83, width: 0.17,
                    height: 0.17 * canvas.width / canvas.height * character.size.height / character.size.width))
                let png = try FlatlayRenderer.png(composition: canvas, images: images)
                XCTAssertNotEqual(png, clothesOnly, "The actual character must appear alongside the cutout garments.")
                let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
                attachment.name = "Cutout collage - \(look.name) - \(gender.rawValue)"
                attachment.lifetime = .keepAlways
                add(attachment)
                let first = canvas.layers[0].id
                try canvas.resize(first, width: canvas.layers[0].width * 0.85)
                try canvas.rotate(first, degrees: -12)
                XCTAssertNotEqual(png, try FlatlayRenderer.png(composition: canvas, images: images))
                let sticker = try XCTUnwrap(canvas.layers.last)
                try canvas.move(first, x: sticker.x, y: sticker.y)
                try canvas.resize(first, width: 0.30)
                let characterInFront = try FlatlayRenderer.png(composition: canvas, images: images)
                try canvas.reorder(sticker.id, steps: -canvas.layers.count)
                let clothesInFront = try FlatlayRenderer.png(composition: canvas, images: images)
                XCTAssertNotEqual(characterInFront, clothesInFront, "Layer order must change actual overlapping pixels.")
                let overlap = XCTAttachment(data: clothesInFront, uniformTypeIdentifier: "public.png")
                overlap.name = "Overlap order check - \(look.name) - \(gender.rawValue)"
                overlap.lifetime = .keepAlways
                add(overlap)
            }
        }
        print("Cutout review: \(inputs.count) alpha-checked images, \(looks.count * CharacterGender.allCases.count) character collages and overlap/transform checks.")
    }

    func testLocalImagesNormalizePersistAndReopen() throws {
        let inputs = try materials()
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try! FileManager.default.removeItem(at: directory) }
        let database = try container(at: directory)
        let assets = AssetStore(baseURL: directory.appending(path: "images"))
        var expected: [String: Data] = [:]
        for input in inputs {
            let source = try Data(contentsOf: input)
            let normalized = try ImageImportService.normalizedPNG(from: source)
            let image = try XCTUnwrap(UIImage(data: normalized)?.cgImage, input.lastPathComponent)
            let original = try assets.savePNG(normalized, id: UUID())
            XCTAssertEqual(original.pixelWidth, image.width)
            XCTAssertEqual(original.pixelHeight, image.height)
            let garment = Garment(name: input.lastPathComponent, category: "Unknown")
            garment.originalAsset = original
            database.mainContext.insert(garment)
            database.mainContext.insert(original)
            expected[input.lastPathComponent] = normalized
            XCTAssertEqual(try Data(contentsOf: input), source, "Import must preserve the source file.")
            print("Local material: \(input.lastPathComponent), \(image.width)x\(image.height), source \(source.count) bytes")
        }
        try database.mainContext.save()
        let reopened = try container(at: directory)
        let garments = try reopened.mainContext.fetch(FetchDescriptor<Garment>())
        XCTAssertEqual(garments.count, inputs.count)
        XCTAssertEqual(Set(garments.map(\.name)), Set(expected.keys))
        for garment in garments {
            XCTAssertNil(garment.cutoutAsset, "No foreground extraction was executed by this test.")
            XCTAssertTrue(garment.colorTags.isEmpty, "No cutout color analysis was executed by this test.")
            XCTAssertEqual(try assets.loadData(for: XCTUnwrap(garment.originalAsset)), expected[garment.name])
        }
    }

    func testLocalImagesExportFlatlayAndRetainDiary() throws {
        let inputs = try materials()
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try! FileManager.default.removeItem(at: directory) }
        let database = try container(at: directory)
        let assets = AssetStore(baseURL: directory.appending(path: "images"))
        let outfits = OutfitStore(context: database.mainContext, assets: assets)
        let journal = JournalStore(context: database.mainContext, assets: assets)
        let rows = Int(ceil(Double(inputs.count + 1) / 3))
        var composition = FlatlayComposition()
        for (index, input) in inputs.enumerated() {
            let normalized = try ImageImportService.normalizedPNG(from: Data(contentsOf: input))
            let asset = try assets.savePNG(normalized, id: UUID())
            let garment = Garment(name: input.lastPathComponent, category: "Unknown")
            garment.originalAsset = asset
            database.mainContext.insert(asset)
            database.mainContext.insert(garment)
            var layer = try outfits.layer(for: garment, in: composition)
            layer.x = (Double(index % 3) + 0.5) / 3
            layer.y = (Double(index / 3) + 0.5) / Double(rows)
            let width = min(0.29, 0.88 / Double(rows) * composition.height / composition.width
                * Double(asset.pixelWidth) / Double(asset.pixelHeight))
            composition.layers.append(layer)
            try composition.resize(layer.id, width: width)
            let resized = try XCTUnwrap(composition.layers.last)
            XCTAssertEqual(resized.width * composition.width / (resized.height * composition.height),
                Double(asset.pixelWidth) / Double(asset.pixelHeight), accuracy: 0.000001)
        }
        let sticker = try CharacterStickerStore(context: database.mainContext, assets: assets).create(CharacterAppearance())
        composition.layers.append(CompositionLayer(assetID: sticker.id,
            x: (Double(inputs.count % 3) + 0.5) / 3,
            y: (Double(inputs.count / 3) + 0.5) / Double(rows), width: 0.12,
            height: 0.12 * composition.width / composition.height * Double(sticker.pixelHeight) / Double(sticker.pixelWidth)))
        try database.mainContext.save()
        let images = try outfits.images(for: composition)
        var exports: [Data] = []
        for background in CanvasBackground.allCases {
            var canvas = composition
            canvas.background = background
            let png = try FlatlayRenderer.png(composition: canvas, images: images)
            let image = try XCTUnwrap(UIImage(data: png)?.cgImage)
            XCTAssertEqual(image.width, 1080)
            XCTAssertEqual(image.height, 1350)
            XCTAssertNotEqual(png, try FlatlayRenderer.png(composition: FlatlayComposition(background: background), images: [:]))
            XCTAssertFalse(exports.contains(png), "The selected background must change the actual export.")
            exports.append(png)
            let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
            attachment.name = "Local original images and character - \(background.rawValue)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        var missing = images
        missing.removeValue(forKey: composition.layers[0].assetID)
        XCTAssertThrowsError(try FlatlayRenderer.png(composition: composition, images: missing))
        let outfit = try outfits.save(name: "Local original image review", composition: composition)
        let entry = try journal.save(name: outfit.name, date: Date(), note: "",
            composition: composition, from: outfit)
        let savedPNG = try assets.loadData(for: XCTUnwrap(entry.renderedAsset))
        XCTAssertEqual(savedPNG, exports[0])
        let retainedAsset = try XCTUnwrap(outfit.assets.first { $0.id == composition.layers[0].assetID })
        let retainedData = try assets.loadData(for: retainedAsset)
        let alternate = try XCTUnwrap(inputs.last)
        let replacement = try assets.savePNG(ImageImportService.normalizedPNG(from: Data(contentsOf: alternate)), id: UUID())
        let firstGarment = try XCTUnwrap(outfit.garments.first { $0.id == composition.layers[0].garmentID })
        database.mainContext.insert(replacement)
        firstGarment.originalAsset = replacement
        try database.mainContext.save()
        let reopened = try container(at: directory)
        let savedOutfit = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<Outfit>()).first)
        let savedEntry = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<JournalEntry>()).first)
        XCTAssertEqual(try savedOutfit.composition(), composition)
        XCTAssertEqual(try savedEntry.composition(), composition)
        XCTAssertEqual(try assets.loadData(for: XCTUnwrap(savedEntry.renderedAsset)), savedPNG)
        XCTAssertEqual(try assets.loadData(for: retainedAsset), retainedData)
        let reopenedOutfits = OutfitStore(context: reopened.mainContext, assets: assets)
        XCTAssertEqual(try FlatlayRenderer.png(composition: savedOutfit.composition(),
            images: reopenedOutfits.images(for: savedOutfit.composition())), savedPNG)
        print("Local corpus: \(inputs.count) original images, 3 backgrounds, character, saved outfit and retained diary PNG.")
    }
}

final class ImageImportServiceTests: XCTestCase {
    func testUndecodableDataIsRejected() async {
        do {
            _ = try await ImageImportService.process(Data("not an image".utf8))
            XCTFail("Expected undecodable error")
        } catch {
            XCTAssertEqual(error as? ImageImportError, .undecodable)
        }
    }

    func testRealGarmentProducesCutoutAndColors() async throws {
        let result = try await ImageImportService.process(garmentFixture())
        let image = try XCTUnwrap(UIImage(data: result.cutoutPNG))
        let cgImage = try XCTUnwrap(image.cgImage)
        var bytes = [UInt8](repeating: 0, count: cgImage.width * cgImage.height * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(
                data: buffer.baseAddress, width: cgImage.width, height: cgImage.height,
                bitsPerComponent: 8, bytesPerRow: cgImage.width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            ))
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        }
        let alphas = stride(from: 3, to: bytes.count, by: 4).map { bytes[$0] }
        XCTAssertTrue(alphas.contains { $0 < 32 }, "The background must actually become transparent.")
        XCTAssertTrue(alphas.contains { $0 > 224 }, "The garment must remain visible.")
        XCTAssertTrue(result.suggestedColors.contains("black"))
        let attachment = XCTAttachment(image: image)
        attachment.name = "Real garment cutout"
        attachment.lifetime = .keepAlways
        add(attachment)
        print("Garment colors: \(result.suggestedColors)")
    }
}

@MainActor
final class GarmentMaintenanceTests: XCTestCase {
    private var directory: URL!
    private var container: ModelContainer!
    private var store: GarmentStore!

    override func setUpWithError() throws {
        directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        container = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self,
                                       configurations: ModelConfiguration(url: directory.appending(path: "wardrobe.store")))
        store = GarmentStore(context: container.mainContext, assets: AssetStore(baseURL: directory))
    }

    override func tearDownWithError() throws {
        store = nil
        container = nil
        try FileManager.default.removeItem(at: directory)
    }

    private func savePhotoGarment() throws -> Garment {
        let photo = try XCTUnwrap(UIImage(data: garmentFixture()))
        let data = try XCTUnwrap(photo.pngData())
        let garment = Garment(name: "Black T-shirt", category: "T-shirt", colorTags: ["black"])
        try store.saveImages(original: data, cutout: data, on: garment)
        return garment
    }

    func testEditedAttributesReopenAndAffectFilters() throws {
        let garment = try savePhotoGarment()
        let identifier = garment.id
        var draft = GarmentDraft(garment)
        draft.name = "Blue shirt"
        draft.category = "Shirt"
        draft.colorTags = ["blue", "white"]
        draft.brand = "Uniqlo"
        draft.size = "M"
        draft.seasons = ["spring", "summer"]
        draft.status = GarmentStatus.owned
        draft.price = Decimal(string: "129.50")!.formatted(.number)
        draft.currency = "sek"
        draft.condition = "good"
        draft.notes = "Try with jeans"
        draft.openingWearCount = "15"
        draft.openingWearIsEstimate = true
        draft.acquisitionDate = Date(timeIntervalSince1970: 1_700_000_000)
        draft.acquisitionPrecision = "month"
        draft.firstUseDate = Date(timeIntervalSince1970: 1_700_086_400)
        draft.firstUsePrecision = "exact"
        XCTAssertEqual(garment.name, "Black T-shirt", "A draft must not mutate the saved record.")
        try store.update(garment, draft: draft)

        let reopened = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self,
                                         configurations: ModelConfiguration(url: directory.appending(path: "wardrobe.store")))
        let saved = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<Garment>()).first)
        XCTAssertEqual(saved.id, identifier)
        XCTAssertEqual(GarmentDraft(saved).name, draft.name)
        XCTAssertEqual(saved.category, "Shirt")
        XCTAssertEqual(saved.colorTags, ["blue", "white"])
        XCTAssertEqual(saved.brand, "Uniqlo")
        XCTAssertEqual(saved.size, "M")
        XCTAssertEqual(saved.seasons, ["spring", "summer"])
        XCTAssertEqual(saved.amount, Decimal(string: "129.50"))
        XCTAssertEqual(saved.currency, "SEK")
        XCTAssertEqual(saved.notes, draft.notes)
        XCTAssertEqual(saved.condition, "good")
        XCTAssertEqual(saved.openingWearCount, 15)
        XCTAssertTrue(saved.openingWearIsEstimate)
        XCTAssertEqual(saved.acquisitionDate, draft.acquisitionDate)
        XCTAssertEqual(saved.acquisitionPrecision, "month")
        XCTAssertEqual(saved.firstUseDate, draft.firstUseDate)
        XCTAssertTrue(WardrobeFilter(search: "uniqlo", category: "Shirt", season: "summer").matches(saved))
        XCTAssertTrue(WardrobeFilter(search: "WHITE").matches(saved))
        XCTAssertFalse(WardrobeFilter(category: "Dress").matches(saved))
        XCTAssertFalse(WardrobeFilter(season: "winter").matches(saved))
        XCTAssertFalse(GarmentCollection.shopping.matches(saved))
        saved.status = GarmentStatus.retired
        XCTAssertFalse(WardrobeFilter().matches(saved))
    }

    func testInvalidEditPreservesSavedAttributes() throws {
        let garment = try savePhotoGarment()
        var draft = GarmentDraft(garment)
        draft.name = "Changed name"
        draft.price = "-10"
        draft.currency = "EUR"
        XCTAssertThrowsError(try store.update(garment, draft: draft))
        XCTAssertEqual(garment.name, "Black T-shirt")
        XCTAssertNil(garment.amount)
        draft.price = ""
        draft.openingWearCount = "-1"
        XCTAssertThrowsError(try store.update(garment, draft: draft))
        XCTAssertEqual(garment.openingWearCount, 0)
    }

    func testImageReplacementKeepsIdentityAndEarlierImageVersions() throws {
        let garment = try savePhotoGarment()
        let identifier = garment.id
        let previous = try XCTUnwrap(garment.cutoutAsset)
        let oldData = try store.assets.loadData(for: previous)
        let image = try XCTUnwrap(UIImage(data: garmentFixture())?.cgImage)
        let cropped = try XCTUnwrap(image.cropping(to: CGRect(x: 100, y: 100, width: 300, height: 300)))
        let newData = try XCTUnwrap(UIImage(cgImage: cropped).pngData())
        try store.saveImages(original: newData, cutout: newData, on: garment)
        XCTAssertEqual(garment.id, identifier)
        XCTAssertEqual(garment.name, "Black T-shirt")
        XCTAssertEqual(garment.category, "T-shirt")
        XCTAssertEqual(garment.colorTags, ["black"])
        XCTAssertNotEqual(garment.cutoutAsset?.id, previous.id)
        XCTAssertEqual(try store.assets.loadData(for: XCTUnwrap(garment.cutoutAsset)), newData)
        XCTAssertEqual(try store.assets.loadData(for: previous), oldData)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<Garment>()).count, 1)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<AssetRecord>()).count, 4)
    }

    func testReferencesReopenAndInvalidChangesPreserveSavedEvidence() throws {
        let garment = try savePhotoGarment()
        let id = garment.id
        var draft = GarmentDraft(garment)
        draft.price = "120"
        draft.currency = " sek "
        draft.openingWearCount = "12"
        draft.costReference = "10"
        draft.durationReferenceYears = "2"
        draft.acquisitionDate = Date(timeIntervalSince1970: 1_700_000_000)
        draft.acquisitionPrecision = "month"
        try store.update(garment, draft: draft)
        let reopened = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self,
            configurations: ModelConfiguration(url: directory.appending(path: "wardrobe.store")))
        let saved = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<Garment>()).first)
        XCTAssertEqual(saved.id, id)
        XCTAssertEqual(saved.currency, "SEK")
        XCTAssertEqual(saved.costReference, 10)
        XCTAssertEqual(saved.durationReferenceYears, 2)
        XCTAssertEqual(saved.acquisitionPrecision, "month")
        XCTAssertEqual(try WearMetrics.summary(price: saved.amount, openingWears: saved.openingWearCount,
            openingIsEstimated: saved.openingWearIsEstimate, recordedWears: saved.wearRecords.count).costPerWear, 10)

        for invalid in ["12abc", "12.30.40", "-1"] {
            var invalidDraft = GarmentDraft(garment)
            invalidDraft.price = invalid
            invalidDraft.name = "Do not save this name"
            XCTAssertThrowsError(try store.update(garment, draft: invalidDraft))
            XCTAssertEqual(garment.name, "Black T-shirt")
            XCTAssertEqual(garment.amount, 120)
            XCTAssertEqual(garment.costReference, 10)
        }
        var invalidDraft = GarmentDraft(garment)
        invalidDraft.durationReferenceYears = "1.5"
        XCTAssertThrowsError(try store.update(garment, draft: invalidDraft))
        XCTAssertEqual(garment.durationReferenceYears, 2)
        invalidDraft = GarmentDraft(garment)
        invalidDraft.costReference = "-1"
        XCTAssertThrowsError(try store.update(garment, draft: invalidDraft))
        XCTAssertEqual(garment.costReference, 10)
        draft = GarmentDraft(garment)
        draft.costReference = ""
        draft.durationReferenceYears = ""
        try store.update(garment, draft: draft)
        XCTAssertNil(garment.costReference)
        XCTAssertNil(garment.durationReferenceYears)
    }

    func testFutureAndInvalidPrecisionDatesDoNotChangeSavedGarment() throws {
        let garment = try savePhotoGarment()
        var draft = GarmentDraft(garment)
        draft.acquisitionDate = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 2, to: Date()))
        XCTAssertThrowsError(try store.update(garment, draft: draft))
        XCTAssertNil(garment.acquisitionDate)
        draft.acquisitionDate = Date(timeIntervalSince1970: 1_700_000_000)
        draft.acquisitionPrecision = "invalid"
        XCTAssertThrowsError(try store.update(garment, draft: draft))
        XCTAssertNil(garment.acquisitionDate)
        draft.acquisitionDate = nil
        draft.firstUseDate = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 2, to: Date()))
        XCTAssertThrowsError(try store.update(garment, draft: draft))
        XCTAssertNil(garment.firstUseDate)
    }

    func testFailedMetadataAndImageSaveKeepOriginalGarmentAndFiles() throws {
        let item = try savePhotoGarment()
        let originalDraft = GarmentDraft(item)
        let originalID = item.originalAsset?.id
        let cutoutID = item.cutoutAsset?.id
        let originalPNG = try store.assets.loadData(for: XCTUnwrap(item.originalAsset))
        let before = try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasSuffix(".png") }.sorted()
        let readOnly = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self,
            configurations: ModelConfiguration(url: directory.appending(path: "wardrobe.store"), allowsSave: false))
        let saved = try XCTUnwrap(readOnly.mainContext.fetch(FetchDescriptor<Garment>()).first)
        let unavailable = GarmentStore(context: readOnly.mainContext, assets: store.assets)
        var draft = GarmentDraft(saved)
        draft.name = "Do not save"
        draft.status = GarmentStatus.retired
        draft.price = "240"
        draft.currency = "SEK"
        draft.costReference = "5"
        draft.durationReferenceYears = "3"
        draft.openingWearCount = "5"
        XCTAssertThrowsError(try unavailable.update(saved, draft: draft))
        XCTAssertEqual(GarmentDraft(saved), originalDraft)
        XCTAssertThrowsError(try unavailable.saveImages(original: originalPNG, cutout: originalPNG, on: saved))
        XCTAssertEqual(saved.originalAsset?.id, originalID)
        XCTAssertEqual(saved.cutoutAsset?.id, cutoutID)
        XCTAssertEqual(GarmentDraft(saved), originalDraft)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasSuffix(".png") }.sorted(), before)
        XCTAssertFalse(readOnly.mainContext.hasChanges)
    }

    func testFailedGarmentDeletionRestoresRecordAndCurrentImages() throws {
        let item = try savePhotoGarment()
        let itemID = item.id
        let originalID = item.originalAsset?.id
        let cutoutID = item.cutoutAsset?.id
        let readOnly = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self,
            configurations: ModelConfiguration(url: directory.appending(path: "wardrobe.store"), allowsSave: false))
        let saved = try XCTUnwrap(readOnly.mainContext.fetch(FetchDescriptor<Garment>()).first)
        XCTAssertThrowsError(try GarmentStore(context: readOnly.mainContext, assets: store.assets).delete(saved))
        let retained = try XCTUnwrap(readOnly.mainContext.fetch(FetchDescriptor<Garment>()).first)
        XCTAssertEqual(retained.id, itemID)
        XCTAssertEqual(retained.name, "Black T-shirt")
        XCTAssertEqual(retained.originalAsset?.id, originalID)
        XCTAssertEqual(retained.cutoutAsset?.id, cutoutID)
        XCTAssertNotNil(UIImage(data: try store.assets.loadData(for: XCTUnwrap(retained.cutoutAsset))))
        XCTAssertTrue(readOnly.mainContext.deletedModelsArray.isEmpty)
        XCTAssertTrue(readOnly.mainContext.insertedModelsArray.isEmpty)
        let retry = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self,
            configurations: ModelConfiguration(url: directory.appending(path: "wardrobe.store")))
        let onDisk = try XCTUnwrap(retry.mainContext.fetch(FetchDescriptor<Garment>()).first)
        XCTAssertEqual(onDisk.id, itemID)
        XCTAssertEqual(onDisk.cutoutAsset?.id, cutoutID)
        try GarmentStore(context: retry.mainContext, assets: store.assets).delete(onDisk)
        XCTAssertTrue(try retry.mainContext.fetch(FetchDescriptor<Garment>()).isEmpty)
    }

    func testDeletionReportsCommittedStateWhenImageDirectoryCannotBeCleaned() throws {
        let imageDirectory = directory.appending(path: "images")
        let assets = AssetStore(baseURL: imageDirectory)
        let imageStore = GarmentStore(context: container.mainContext, assets: assets)
        let png = try ImageImportService.normalizedPNG(from: garmentFixture())
        let item = Garment(name: "Delete this item", category: "Shirt")
        try imageStore.saveImages(original: png, cutout: png, on: item)
        let cutoutURL = assets.url(for: try XCTUnwrap(item.cutoutAsset))
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: imageDirectory.path)
        defer { try! FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: imageDirectory.path) }
        do {
            try imageStore.delete(item)
            XCTFail("The real directory permissions must prevent image cleanup.")
        } catch GarmentStoreError.assetCleanupFailed(let detail) {
            XCTAssertFalse(detail.isEmpty)
        }
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<Garment>()).isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: cutoutURL.path))
    }

    func testFailedImageReplacementPreservesOldReferencesAndRemovesPartialFile() throws {
        let garment = try savePhotoGarment()
        let original = garment.originalAsset?.id
        let cutout = garment.cutoutAsset?.id
        let contentsBefore = try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
        let realPhoto = try store.assets.loadData(for: XCTUnwrap(garment.originalAsset))
        XCTAssertThrowsError(try store.saveImages(original: realPhoto, cutout: Data("invalid image".utf8), on: garment))
        XCTAssertEqual(garment.originalAsset?.id, original)
        XCTAssertEqual(garment.cutoutAsset?.id, cutout)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted(), contentsBefore)
    }

    func testDeletionPreservesSharedAssetAndRetirementPreservesHistory() throws {
        let garment = try savePhotoGarment()
        let shared = try XCTUnwrap(garment.cutoutAsset)
        let originalURL = store.assets.url(for: try XCTUnwrap(garment.originalAsset))
        let second = Garment(name: "Second record", category: "T-shirt")
        second.cutoutAsset = shared
        container.mainContext.insert(second)
        try container.mainContext.save()
        try store.delete(garment)
        XCTAssertFalse(FileManager.default.fileExists(atPath: originalURL.path))
        XCTAssertFalse(try container.mainContext.fetch(FetchDescriptor<Garment>()).contains { $0.id == garment.id })
        XCTAssertEqual(second.cutoutAsset?.id, shared.id)
        XCTAssertFalse(try store.assets.loadData(for: shared).isEmpty)

        var draft = GarmentDraft(second)
        draft.openingWearCount = "20"
        try store.update(second, draft: draft)
        XCTAssertThrowsError(try store.delete(second))
        try store.retire(second)
        XCTAssertEqual(second.status, GarmentStatus.retired)
        XCTAssertEqual(second.openingWearCount, 20)
        XCTAssertFalse(try store.assets.loadData(for: shared).isEmpty)
    }
}

@MainActor
final class OutfitLifecycleTests: XCTestCase {
    private var directory: URL!
    private var container: ModelContainer!
    private var garments: GarmentStore!
    private var outfits: OutfitStore!

    override func setUpWithError() throws {
        directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        container = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self,
                                       configurations: ModelConfiguration(url: directory.appending(path: "wardrobe.store")))
        let assets = AssetStore(baseURL: directory)
        garments = GarmentStore(context: container.mainContext, assets: assets)
        outfits = OutfitStore(context: container.mainContext, assets: assets)
    }

    override func tearDownWithError() throws {
        garments = nil
        outfits = nil
        container = nil
        try FileManager.default.removeItem(at: directory)
    }

    private func garment(status: String = "owned") throws -> Garment {
        let photo = try XCTUnwrap(UIImage(data: garmentFixture()))
        let data = try XCTUnwrap(photo.pngData())
        let result = Garment(name: "Black tee", category: "T-shirt", status: status, amount: 120, currency: "EUR")
        try garments.saveImages(original: data, cutout: data, on: result)
        return result
    }

    func testMixedOwnedAndCandidateCompositionReopensWithEveryTransform() throws {
        let owned = try garment()
        let candidate = try garment(status: GarmentStatus.candidate)
        var composition = FlatlayComposition(background: .indigo)
        composition.layers = [try outfits.layer(for: owned, in: composition), try outfits.layer(for: candidate, in: composition)]
        let id = composition.layers[0].id
        try composition.move(id, x: 0.2, y: 0.7)
        try composition.resize(id, width: 0.6)
        try composition.rotate(id, degrees: -35)
        try composition.reorder(id, steps: 1)
        let outfit = try outfits.save(name: "Tomorrow", composition: composition)
        XCTAssertEqual(outfit.garments.count, 2)
        XCTAssertEqual(outfit.assets.count, 2)
        XCTAssertEqual(owned.openingWearCount, 0, "Planning must not record wearing.")
        XCTAssertEqual(candidate.status, GarmentStatus.candidate)
        XCTAssertFalse(WardrobeFilter().matches(candidate))
        XCTAssertTrue(GarmentCollection.shopping.matches(candidate))
        let reopened = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self,
                                         configurations: ModelConfiguration(url: directory.appending(path: "wardrobe.store")))
        let restored = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<Outfit>()).first)
        XCTAssertEqual(restored.id, outfit.id)
        XCTAssertEqual(restored.name, "Tomorrow")
        XCTAssertEqual(try restored.composition(), composition)
        XCTAssertEqual(Set(restored.garments.map(\.id)), composition.garmentIDs)
        XCTAssertEqual(Set(restored.assets.map(\.id)), composition.assetIDs)
    }

    func testRepeatedGarmentLayersHaveDistinctTransformsAndOneRecordAssociation() throws {
        let garment = try garment()
        var composition = FlatlayComposition()
        composition.layers = [try outfits.layer(for: garment, in: composition), try outfits.layer(for: garment, in: composition)]
        try composition.move(composition.layers[1].id, x: 0.8, y: 0.7)
        let outfit = try outfits.save(name: "Two views", composition: composition)
        XCTAssertEqual(try outfit.composition().layers.count, 2)
        XCTAssertEqual(outfit.garments.count, 1)
        XCTAssertEqual(outfit.assets.count, 1)
        XCTAssertEqual(garment.outfits.count, 1)
        try composition.remove(composition.layers[0].id)
        try outfits.save(name: "One view", composition: composition, updating: outfit)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<Outfit>()).count, 1)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<Garment>()).count, 1)
        XCTAssertEqual(garment.openingWearCount, 0)
    }

    func testReplacingGarmentImageKeepsSavedOutfitOnItsEarlierImage() throws {
        let garment = try garment()
        var composition = FlatlayComposition()
        composition.layers = [try outfits.layer(for: garment, in: composition)]
        let outfit = try outfits.save(name: "Original image", composition: composition)
        let previous = try XCTUnwrap(garment.cutoutAsset)
        let originalData = try outfits.assets.loadData(for: previous)
        let source = try XCTUnwrap(UIImage(data: garmentFixture())?.cgImage)
        let cropped = try XCTUnwrap(source.cropping(to: CGRect(x: 100, y: 100, width: 300, height: 300)))
        let replacement = try XCTUnwrap(UIImage(cgImage: cropped).pngData())
        try garments.saveImages(original: replacement, cutout: replacement, on: garment)
        XCTAssertNotEqual(garment.cutoutAsset?.id, previous.id)
        XCTAssertEqual(try outfit.composition().layers[0].assetID, previous.id)
        XCTAssertEqual(outfit.assets.first?.id, previous.id)
        XCTAssertEqual(try outfits.assets.loadData(for: previous), originalData)
        XCTAssertEqual(try outfits.images(for: outfit.composition()).count, 1)
        XCTAssertThrowsError(try garments.delete(garment))
    }

    func testRetirementPreservesSavedOutfitAndBlocksNewSelection() throws {
        let garment = try garment()
        var composition = FlatlayComposition()
        composition.layers = [try outfits.layer(for: garment, in: composition)]
        let outfit = try outfits.save(name: "Saved before retirement", composition: composition)
        try garments.retire(garment)
        XCTAssertFalse(WardrobeFilter().matches(garment))
        XCTAssertThrowsError(try outfits.layer(for: garment, in: composition))
        XCTAssertThrowsError(try garments.delete(garment))
        try composition.rotate(composition.layers[0].id, degrees: 40)
        try outfits.save(name: "Retained outfit", composition: composition, updating: outfit)
        XCTAssertEqual(try outfits.images(for: composition).count, 1)
        XCTAssertEqual(try outfit.composition().layers[0].rotation, 40)
    }

    func testMissingAssetsAndMalformedCompositionDoNotCreateAnOutfit() throws {
        let missing = FlatlayComposition(layers: [CompositionLayer(assetID: UUID(), width: 0.4, height: 0.4)])
        XCTAssertThrowsError(try outfits.save(name: "Missing image", composition: missing))
        XCTAssertThrowsError(try outfits.images(for: missing))
        XCTAssertThrowsError(try outfits.save(name: "Empty", composition: FlatlayComposition()))
        let garment = try garment()
        let valid = FlatlayComposition(layers: [try outfits.layer(for: garment, in: FlatlayComposition())])
        XCTAssertThrowsError(try outfits.save(name: "   ", composition: valid))
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<Outfit>()).isEmpty)
    }

    func testRenderedExportUsesSavedImagesCanvasAndBackground() throws {
        let garment = try garment()
        var composition = FlatlayComposition(width: 320, height: 400)
        composition.layers = [try outfits.layer(for: garment, in: composition)]
        let images = try outfits.images(for: composition)
        let first = try FlatlayRenderer.png(composition: composition, images: images)
        let blank = try FlatlayRenderer.png(composition: FlatlayComposition(width: 320, height: 400), images: [:])
        XCTAssertNotEqual(first, blank, "The export must contain the real garment image.")
        let image = try XCTUnwrap(UIImage(data: first)?.cgImage)
        XCTAssertEqual(image.width, 320)
        XCTAssertEqual(image.height, 400)
        composition.background = .charcoal
        try composition.rotate(composition.layers[0].id, degrees: 45)
        let changed = try FlatlayRenderer.png(composition: composition, images: images)
        XCTAssertNotEqual(first, changed)
        XCTAssertThrowsError(try FlatlayRenderer.png(composition: composition, images: [:]))
    }

    func testDeletingOutfitLeavesWardrobeImagesAndClearsReferences() throws {
        let garment = try garment()
        let composition = FlatlayComposition(layers: [try outfits.layer(for: garment, in: FlatlayComposition())])
        let outfit = try outfits.save(name: "Remove this outfit", composition: composition)
        try outfits.delete(outfit)
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<Outfit>()).isEmpty)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<Garment>()).count, 1)
        XCTAssertTrue(garment.outfits.isEmpty)
        XCTAssertEqual(try outfits.images(for: composition).count, 1)
    }

    func testPurchaseCalculatorResetsInputsAndLeavesPersistentRecordsUnchanged() throws {
        let garment = try garment(status: GarmentStatus.candidate)
        var draft = PurchaseDraft(garment: garment)
        draft.years = "1"
        draft.seasonsPerYear = 1
        draft.unit = .season
        draft.frequency = "12"
        XCTAssertEqual(try draft.costPerWear(), 10)
        draft.price = Decimal(240).formatted(.number)
        XCTAssertEqual(try draft.costPerWear(), 20)
        XCTAssertEqual(garment.amount, 120)
        XCTAssertEqual(garment.openingWearCount, 0)
        XCTAssertEqual(garment.status, GarmentStatus.candidate)
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<Outfit>()).isEmpty)
        XCTAssertEqual(PurchaseDraft(garment: garment).years, "")
        XCTAssertEqual(PurchaseDraft(garment: garment).frequency, "")
    }

    func testPurchaseCountAndPriceBoundaries() throws {
        let garment = try garment()
        var draft = PurchaseDraft(garment: garment)
        draft.years = "1"
        draft.seasonsPerYear = 1
        draft.unit = .season
        for count in ["", "0", "-1", "1.5", "abc"] {
            draft.frequency = count
            XCTAssertThrowsError(try draft.costPerWear())
        }
        draft.frequency = "1"
        draft.price = ""
        XCTAssertNil(try draft.costPerWear())
        draft.price = "0"
        XCTAssertEqual(try draft.costPerWear(), 0)
        draft.price = "-1"
        XCTAssertThrowsError(try draft.costPerWear())
        draft.price = "abc"
        XCTAssertThrowsError(try draft.costPerWear())
        draft.price = "120"
        draft.currency = ""
        XCTAssertEqual(try draft.costPerWear(), 120)
    }

    func testSeasonalPurchaseDraftRejectsInvalidFieldsAndKeepsHistoryUnchanged() throws {
        let item = try garment(status: GarmentStatus.candidate)
        item.amount = 1490
        item.currency = "SEK"
        try container.mainContext.save()
        var draft = PurchaseDraft(garment: item)
        draft.years = "3"
        draft.frequency = "1"
        XCTAssertEqual(try draft.estimatedWears(), 78)
        draft.unit = .month
        XCTAssertEqual(try draft.estimatedWears(), 18)
        draft.unit = .season
        XCTAssertEqual(try draft.estimatedWears(), 6)
        for years in ["", "0", "-1", "1.5", "abc", String(Int.max) + "0"] {
            draft.years = years
            XCTAssertThrowsError(try draft.costPerWear())
        }
        draft.years = "3"
        draft.seasonsPerYear = 5
        XCTAssertThrowsError(try draft.costPerWear())
        draft.seasonsPerYear = 2
        draft.price = "12abc"
        XCTAssertThrowsError(try draft.costPerWear())
        draft.price = "1490"
        draft.currency = "123"
        XCTAssertThrowsError(try draft.costPerWear())
        draft.currency = "SEK"
        draft.years = String(Int.max)
        XCTAssertThrowsError(try draft.costPerWear())
        XCTAssertEqual(item.amount, 1490)
        XCTAssertEqual(item.status, GarmentStatus.candidate)
        XCTAssertEqual(item.openingWearCount, 0)
        XCTAssertTrue(item.wearRecords.isEmpty)
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<JournalEntry>()).isEmpty)
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<Outfit>()).isEmpty)
        let reopened = PurchaseDraft(garment: item)
        XCTAssertEqual(reopened.years, "")
        XCTAssertEqual(reopened.frequency, "")
        XCTAssertEqual(reopened.seasonsPerYear, 2)
        XCTAssertEqual(reopened.unit, .week)
    }

    func testPurchasePreviewValidatesPartialInputAndClearsOldResults() throws {
        let item = try garment(status: GarmentStatus.candidate)
        var draft = PurchaseDraft(garment: item)
        XCTAssertNil(try draft.preview())
        draft.years = "-1"
        XCTAssertThrowsError(try draft.preview())
        draft.years = "3"
        XCTAssertNil(try draft.preview())
        draft.frequency = "1"
        XCTAssertEqual(try draft.preview()?.wears, 78)
        draft.frequency = ""
        XCTAssertNil(try draft.preview())
        draft.price = "12abc"
        XCTAssertThrowsError(try draft.preview())
        draft.price = ""
        draft.frequency = "1"
        XCTAssertEqual(try draft.preview()?.wears, 78)
        XCTAssertNil(try draft.preview()?.cost)
    }

    func testWardrobeAndShoppingSelectionsRemainSeparateAfterReopening() throws {
        let owned = try garment()
        let shopping = try garment(status: GarmentStatus.candidate)
        let reopened = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self,
                                         configurations: ModelConfiguration(url: directory.appending(path: "wardrobe.store")))
        let all = try reopened.mainContext.fetch(FetchDescriptor<Garment>())
        XCTAssertEqual(all.filter { WardrobeFilter().matches($0) }.map(\.id), [owned.id])
        XCTAssertEqual(all.filter { GarmentCollection.shopping.matches($0) }.map(\.id), [shopping.id])
        XCTAssertFalse(GarmentCollection.wardrobe.matches(shopping))
        XCTAssertFalse(GarmentCollection.shopping.matches(owned))
        XCTAssertTrue(GarmentCollection.shopping.matches(shopping, search: "BLACK"))
        XCTAssertFalse(GarmentCollection.shopping.matches(shopping, search: "missing name"))
    }

    func testAddingShoppingItemToWardrobePreservesOutfitAndWearHistory() throws {
        let item = try garment(status: GarmentStatus.candidate)
        item.openingWearCount = 4
        try container.mainContext.save()
        let id = item.id
        let asset = try XCTUnwrap(item.cutoutAsset)
        let composition = FlatlayComposition(layers: [try outfits.layer(for: item, in: FlatlayComposition())])
        let outfit = try outfits.save(name: "Purchase comparison", composition: composition)
        let acquired = Date(timeIntervalSince1970: 1_700_000_000)
        try ShoppingStore(context: container.mainContext, assets: garments.assets).addToWardrobe(item, price: "100", currency: "EUR", acquired: acquired)
        XCTAssertEqual(item.id, id)
        XCTAssertEqual(item.cutoutAsset?.id, asset.id)
        XCTAssertEqual(item.amount, 100)
        XCTAssertEqual(item.acquisitionDate, acquired)
        XCTAssertEqual(item.openingWearCount, 4)
        XCTAssertTrue(WardrobeFilter().matches(item))
        XCTAssertFalse(GarmentCollection.shopping.matches(item))
        XCTAssertEqual(try outfit.composition(), composition)
        XCTAssertEqual(try outfits.images(for: composition).count, 1)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<Garment>()).count, 1)
    }

    func testAcquisitionWithRecordedDiaryRollsBackRetriesAndReopens() throws {
        let item = try garment(status: GarmentStatus.candidate)
        let owned = try garment()
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        item.openingWearCount = 3
        item.openingWearIsEstimate = true
        item.firstUseDate = day
        item.firstUsePrecision = "month"
        try container.mainContext.save()
        let composition = FlatlayComposition(layers: [
            try outfits.layer(for: owned, in: FlatlayComposition()),
            try outfits.layer(for: item, in: FlatlayComposition())
        ])
        let outfit = try outfits.save(name: "Before buying", composition: composition)
        let journal = JournalStore(context: container.mainContext, assets: garments.assets)
        let entry = try journal.save(name: "Borrowed and worn", date: day, note: "Keep this history",
            composition: composition, from: outfit)
        try journal.recordWearing(entry)
        let historicalImageID = try XCTUnwrap(item.cutoutAsset).id
        let source = try XCTUnwrap(UIImage(data: garmentFixture())?.cgImage)
        let crop = try XCTUnwrap(source.cropping(to: CGRect(x: 100, y: 100, width: 300, height: 300)))
        let replacement = try XCTUnwrap(UIImage(cgImage: crop).pngData())
        try garments.saveImages(original: replacement, cutout: replacement, on: item)
        let currentImageID = try XCTUnwrap(item.cutoutAsset).id
        XCTAssertNotEqual(currentImageID, historicalImageID)
        let baseline = GarmentDraft(item)
        let updatedAt = item.updatedAt
        let renderedID = try XCTUnwrap(entry.renderedAsset).id
        let eventIDs = Set(entry.wearRecords.map(\.id))
        let itemEventID = try XCTUnwrap(item.wearRecords.first).id
        let itemEventDate = try XCTUnwrap(item.wearRecords.first).date
        let savedFiles = try Dictionary(uniqueKeysWithValues:
            container.mainContext.fetch(FetchDescriptor<AssetRecord>()).map {
                ($0.id, try garments.assets.loadData(for: $0))
            })
        let storeURL = directory.appending(path: "wardrobe.store")
        let readOnly = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self,
            configurations: ModelConfiguration(url: storeURL, allowsSave: false))
        let protectedItem = try XCTUnwrap(readOnly.mainContext.fetch(FetchDescriptor<Garment>()).first { $0.id == item.id })
        let protectedEntry = try XCTUnwrap(readOnly.mainContext.fetch(FetchDescriptor<JournalEntry>()).first)
        let acquired = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 1, to: day))
        let defaults = WardrobeDefaults(currency: "SEK", costReference: 5, yearReference: 2)
        XCTAssertThrowsError(try ShoppingStore(context: readOnly.mainContext, assets: garments.assets)
            .addToWardrobe(protectedItem, price: "200", currency: "SEK", acquired: acquired, defaults: defaults))
        XCTAssertEqual(GarmentDraft(protectedItem), baseline)
        XCTAssertEqual(protectedItem.updatedAt, updatedAt)
        XCTAssertEqual(protectedItem.wearRecords.map(\.id), [itemEventID])
        XCTAssertEqual(Set(protectedEntry.wearRecords.map(\.id)), eventIDs)
        XCTAssertEqual(protectedEntry.renderedAsset?.id, renderedID)
        XCTAssertTrue(protectedEntry.wearingRecorded)
        XCTAssertFalse(readOnly.mainContext.hasChanges)

        let retry = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self,
            configurations: ModelConfiguration(url: storeURL))
        let retryItem = try XCTUnwrap(retry.mainContext.fetch(FetchDescriptor<Garment>()).first { $0.id == item.id })
        XCTAssertEqual(GarmentDraft(retryItem), baseline)
        let shopping = ShoppingStore(context: retry.mainContext, assets: garments.assets)
        try shopping.addToWardrobe(retryItem, price: "200", currency: "SEK", acquired: acquired, defaults: defaults)
        XCTAssertThrowsError(try shopping.addToWardrobe(retryItem, price: "99", currency: "EUR", acquired: nil))

        let reopened = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self,
            configurations: ModelConfiguration(url: storeURL))
        let all = try reopened.mainContext.fetch(FetchDescriptor<Garment>())
        XCTAssertEqual(all.count, 2)
        let restored = try XCTUnwrap(all.first { $0.id == item.id })
        XCTAssertTrue(WardrobeFilter().matches(restored))
        XCTAssertFalse(GarmentCollection.shopping.matches(restored))
        XCTAssertEqual(restored.amount, 200)
        XCTAssertEqual(restored.currency, "SEK")
        XCTAssertEqual(restored.acquisitionDate, acquired)
        XCTAssertEqual(restored.acquisitionPrecision, "exact")
        XCTAssertEqual(restored.firstUseDate, day)
        XCTAssertEqual(restored.firstUsePrecision, "month")
        XCTAssertEqual(restored.costReference, 5)
        XCTAssertEqual(restored.durationReferenceYears, 2)
        XCTAssertEqual(restored.cutoutAsset?.id, currentImageID)
        XCTAssertEqual(restored.openingWearCount, 3)
        XCTAssertTrue(restored.openingWearIsEstimate)
        XCTAssertEqual(restored.wearRecords.map(\.id), [itemEventID])
        XCTAssertEqual(restored.wearRecords.first?.date, itemEventDate)
        let summary = try WearMetrics.summary(price: restored.amount, openingWears: restored.openingWearCount,
            openingIsEstimated: restored.openingWearIsEstimate, recordedWears: restored.wearRecords.count)
        XCTAssertEqual(summary.costPerWear, 50)
        let restoredOutfit = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<Outfit>()).first)
        let restoredEntry = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<JournalEntry>()).first)
        XCTAssertEqual(restoredOutfit.id, outfit.id)
        XCTAssertEqual(try restoredOutfit.composition(), composition)
        XCTAssertEqual(Set(restoredOutfit.garments.map(\.id)), composition.garmentIDs)
        XCTAssertEqual(restoredEntry.id, entry.id)
        XCTAssertEqual(restoredEntry.date, day)
        XCTAssertTrue(restoredEntry.wearingRecorded)
        XCTAssertEqual(restoredEntry.sourceOutfitID, outfit.id)
        XCTAssertEqual(restoredEntry.note, "Keep this history")
        XCTAssertEqual(try restoredEntry.composition(), composition)
        XCTAssertEqual(restoredEntry.renderedAsset?.id, renderedID)
        XCTAssertEqual(Set(restoredEntry.garments.map(\.id)), composition.garmentIDs)
        XCTAssertEqual(Set(restoredEntry.wearRecords.map(\.id)), eventIDs)
        try JournalStore(context: reopened.mainContext, assets: garments.assets).recordWearing(restoredEntry)
        XCTAssertEqual(try reopened.mainContext.fetch(FetchDescriptor<WearRecord>()).count, 2)
        let retainedAssets = try reopened.mainContext.fetch(FetchDescriptor<AssetRecord>())
        XCTAssertEqual(Set(retainedAssets.map(\.id)), Set(savedFiles.keys))
        for asset in retainedAssets { XCTAssertEqual(try garments.assets.loadData(for: asset), savedFiles[asset.id]) }
        XCTAssertEqual(try reopened.mainContext.fetch(FetchDescriptor<Outfit>()).count, 1)
        XCTAssertEqual(try reopened.mainContext.fetch(FetchDescriptor<JournalEntry>()).count, 1)
    }

    func testAcquisitionDefaultsRespectCurrencyAndExistingReferences() throws {
        let defaults = WardrobeDefaults(currency: "SEK", costReference: 5, yearReference: 2)
        let first = try garment(status: GarmentStatus.candidate)
        let second = try garment(status: GarmentStatus.candidate)
        let third = try garment(status: GarmentStatus.candidate)
        third.costReference = 3
        third.durationReferenceYears = 4
        try container.mainContext.save()
        let shop = ShoppingStore(context: container.mainContext, assets: garments.assets)
        try shop.addToWardrobe(first, price: "120", currency: "sek", acquired: nil, defaults: defaults)
        XCTAssertEqual(first.costReference, 5)
        XCTAssertEqual(first.durationReferenceYears, 2)
        try shop.addToWardrobe(second, price: "120", currency: "EUR", acquired: nil, defaults: defaults)
        XCTAssertNil(second.costReference)
        XCTAssertEqual(second.durationReferenceYears, 2)
        try shop.addToWardrobe(third, price: "120", currency: "SEK", acquired: nil, defaults: defaults)
        XCTAssertEqual(third.costReference, 3)
        XCTAssertEqual(third.durationReferenceYears, 4)
        let changed = WardrobeDefaults(currency: "EUR", costReference: 10, yearReference: 7)
        let imported = Garment(name: "New import", category: "Shirt")
        changed.applyToNewGarment(imported, collection: .wardrobe)
        XCTAssertEqual(imported.currency, "EUR")
        XCTAssertEqual(imported.costReference, 10)
        XCTAssertEqual(first.currency, "SEK")
        XCTAssertEqual(first.costReference, 5)
    }

    func testInvalidTransferLeavesShoppingRecordUnchangedAndRepeatedTransferIsRejected() throws {
        let item = try garment(status: GarmentStatus.candidate)
        let store = ShoppingStore(context: container.mainContext, assets: garments.assets)
        XCTAssertThrowsError(try store.addToWardrobe(item, price: "-1", currency: "EUR", acquired: Date()))
        XCTAssertEqual(item.status, GarmentStatus.candidate)
        XCTAssertEqual(item.amount, 120)
        XCTAssertNil(item.acquisitionDate)
        try store.addToWardrobe(item, price: "", currency: "", acquired: nil)
        XCTAssertNil(item.amount)
        XCTAssertTrue(WardrobeFilter().matches(item))
        XCTAssertThrowsError(try store.addToWardrobe(item, price: "20", currency: "EUR", acquired: Date()))
        XCTAssertNil(item.amount)
    }

    func testRemovingShoppingItemPreservesSavedOutfitReferences() throws {
        let item = try garment(status: GarmentStatus.candidate)
        let composition = FlatlayComposition(layers: [try outfits.layer(for: item, in: FlatlayComposition())])
        let outfit = try outfits.save(name: "Earlier comparison", composition: composition)
        try ShoppingStore(context: container.mainContext, assets: garments.assets).remove(item)
        XCTAssertEqual(item.status, GarmentStatus.discarded)
        XCTAssertTrue(item.collection == .shopping)
        XCTAssertThrowsError(try outfits.layer(for: item, in: composition))
        XCTAssertFalse(WardrobeFilter().matches(item))
        XCTAssertFalse(GarmentCollection.shopping.matches(item))
        XCTAssertEqual(try outfit.composition(), composition)
        XCTAssertEqual(try outfits.images(for: composition).count, 1)
        var changed = composition
        try changed.rotate(changed.layers[0].id, degrees: 30)
        try outfits.save(name: "Retained comparison", composition: changed, updating: outfit)
        changed.layers.append(CompositionLayer(assetID: changed.layers[0].assetID, garmentID: item.id, width: 0.2, height: 0.2))
        XCTAssertThrowsError(try outfits.save(name: "New removed-item layer", composition: changed, updating: outfit))
    }

    func testRemovingUnusedShoppingItemDeletesItsUnsharedImages() throws {
        let item = try garment(status: GarmentStatus.candidate)
        let original = garments.assets.url(for: try XCTUnwrap(item.originalAsset))
        let cutout = garments.assets.url(for: try XCTUnwrap(item.cutoutAsset))
        try ShoppingStore(context: container.mainContext, assets: garments.assets).remove(item)
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<Garment>()).isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: original.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: cutout.path))
    }

    func testJournalCopiesSurviveTemplateEditingImageReplacementAndReopening() throws {
        let item = try garment()
        let asset = try XCTUnwrap(item.cutoutAsset)
        let canvas = FlatlayComposition(layers: [try outfits.layer(for: item, in: FlatlayComposition())])
        let look = try outfits.save(name: "Reusable", composition: canvas)
        let journal = JournalStore(context: container.mainContext, assets: garments.assets)
        let entry = try journal.useToday(look)
        XCTAssertEqual(entry.sourceOutfitID, look.id)
        let sourceID = look.id
        var edited = canvas
        try edited.rotate(edited.layers[0].id, degrees: 40)
        try outfits.save(name: "Changed", composition: edited, updating: look)
        let data = try garments.assets.loadData(for: asset)
        try garments.saveImages(original: data, cutout: data, on: item)
        XCTAssertEqual(try entry.composition(), canvas)
        XCTAssertEqual(entry.name, "Reusable")
        XCTAssertEqual(entry.assets.map(\.id), [asset.id])
        try outfits.delete(look)
        let reopened = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self,
            configurations: ModelConfiguration(url: directory.appending(path: "wardrobe.store")))
        let savedEntry = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<JournalEntry>()).first)
        XCTAssertEqual(savedEntry.sourceOutfitID, sourceID)
        XCTAssertEqual(try savedEntry.composition(), canvas)
        XCTAssertEqual(try OutfitStore(context: reopened.mainContext, assets: garments.assets).images(for: savedEntry.composition()).count, 1)
    }

    func testDiaryPNGReopensReusesTextEditsAndChangesOnlyWithComposition() throws {
        let item = try garment()
        var canvas = FlatlayComposition(width: 320, height: 400)
        canvas.layers = [try outfits.layer(for: item, in: canvas)]
        let journal = JournalStore(context: container.mainContext, assets: garments.assets)
        let entry = try journal.save(name: "Diary", date: Date(), note: "", composition: canvas)
        let firstAsset = try XCTUnwrap(entry.renderedAsset)
        let firstPNG = try garments.assets.loadData(for: firstAsset)
        let image = try XCTUnwrap(UIImage(data: firstPNG)?.cgImage)
        XCTAssertEqual(image.width, 320)
        XCTAssertEqual(image.height, 400)
        try journal.save(name: "Updated title", date: Date(), note: "User note", composition: canvas, updating: entry)
        XCTAssertEqual(entry.renderedAsset?.id, firstAsset.id)
        let input = try garments.assets.loadData(for: XCTUnwrap(item.originalAsset))
        try garments.saveImages(original: input, cutout: input, on: item)
        XCTAssertEqual(try garments.assets.loadData(for: firstAsset), firstPNG)
        canvas.background = .charcoal
        try journal.save(name: entry.name, date: entry.date, note: entry.note, composition: canvas, updating: entry)
        let changedAsset = try XCTUnwrap(entry.renderedAsset)
        XCTAssertNotEqual(changedAsset.id, firstAsset.id)
        let changedPNG = try garments.assets.loadData(for: changedAsset)
        XCTAssertNotEqual(changedPNG, firstPNG)
        let reopened = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self,
            configurations: ModelConfiguration(url: directory.appending(path: "wardrobe.store")))
        let saved = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<JournalEntry>()).first)
        XCTAssertEqual(saved.name, "Updated title")
        XCTAssertEqual(saved.note, "User note")
        XCTAssertEqual(saved.renderedAsset?.id, changedAsset.id)
        XCTAssertEqual(try garments.assets.loadData(for: XCTUnwrap(saved.renderedAsset)), changedPNG)
        XCTAssertEqual(try saved.composition(), canvas)
    }

    func testMissingRealSourceFileBlocksOutfitAndDiarySaveWithoutMutation() throws {
        let item = try garment()
        let canvas = FlatlayComposition(layers: [try outfits.layer(for: item, in: FlatlayComposition())])
        let look = try outfits.save(name: "Preserve outfit", composition: canvas)
        let journal = JournalStore(context: container.mainContext, assets: garments.assets)
        let entry = try journal.save(name: "Preserve diary", date: Date(), note: "Original", composition: canvas)
        let renderedID = entry.renderedAsset?.id
        try garments.assets.remove(XCTUnwrap(item.cutoutAsset))
        XCTAssertThrowsError(try outfits.save(name: "Changed", composition: canvas, updating: look))
        XCTAssertThrowsError(try journal.save(name: "Changed", date: Date(), note: "Changed", composition: canvas, updating: entry))
        XCTAssertEqual(look.name, "Preserve outfit")
        XCTAssertEqual(entry.name, "Preserve diary")
        XCTAssertEqual(entry.note, "Original")
        XCTAssertEqual(entry.renderedAsset?.id, renderedID)
        XCTAssertNotNil(UIImage(data: try garments.assets.loadData(for: XCTUnwrap(entry.renderedAsset))))
    }

    func testFailedOutfitSaveKeepsOriginalLayoutAndReferences() throws {
        let item = try garment()
        var canvas = FlatlayComposition(layers: [try outfits.layer(for: item, in: FlatlayComposition())])
        let outfit = try outfits.save(name: "Keep outfit", composition: canvas)
        let id = outfit.id
        let original = canvas
        let readOnly = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self,
            configurations: ModelConfiguration(url: directory.appending(path: "wardrobe.store"), allowsSave: false))
        let saved = try XCTUnwrap(readOnly.mainContext.fetch(FetchDescriptor<Outfit>()).first)
        canvas.background = .charcoal
        XCTAssertThrowsError(try OutfitStore(context: readOnly.mainContext, assets: garments.assets).save(name: "Do not save", composition: canvas, updating: saved))
        XCTAssertEqual(saved.id, id)
        XCTAssertEqual(saved.name, "Keep outfit")
        XCTAssertEqual(try saved.composition(), original)
        XCTAssertEqual(saved.garments.map(\.id), [item.id])
        XCTAssertEqual(Set(saved.assets.map(\.id)), original.assetIDs)
        XCTAssertFalse(readOnly.mainContext.hasChanges)
    }

    func testFailedOutfitDeletionRestoresGarmentAndAssetReferences() throws {
        let item = try garment()
        let canvas = FlatlayComposition(layers: [try outfits.layer(for: item, in: FlatlayComposition())])
        let outfit = try outfits.save(name: "Keep outfit", composition: canvas)
        let id = outfit.id
        let readOnly = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self,
            configurations: ModelConfiguration(url: directory.appending(path: "wardrobe.store"), allowsSave: false))
        let saved = try XCTUnwrap(readOnly.mainContext.fetch(FetchDescriptor<Outfit>()).first)
        XCTAssertThrowsError(try OutfitStore(context: readOnly.mainContext, assets: garments.assets).delete(saved))
        let retained = try XCTUnwrap(readOnly.mainContext.fetch(FetchDescriptor<Outfit>()).first)
        XCTAssertEqual(retained.id, id)
        XCTAssertEqual(retained.garments.map(\.id), [item.id])
        XCTAssertEqual(Set(retained.assets.map(\.id)), canvas.assetIDs)
        XCTAssertEqual(retained.garments.first?.outfits.map(\.id), [id])
        XCTAssertTrue(readOnly.mainContext.deletedModelsArray.isEmpty)
        XCTAssertTrue(readOnly.mainContext.insertedModelsArray.isEmpty)
        let retry = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self,
            configurations: ModelConfiguration(url: directory.appending(path: "wardrobe.store")))
        let onDisk = try XCTUnwrap(retry.mainContext.fetch(FetchDescriptor<Outfit>()).first)
        XCTAssertEqual(onDisk.id, id)
        XCTAssertEqual(onDisk.garments.map(\.id), [item.id])
        try OutfitStore(context: retry.mainContext, assets: garments.assets).delete(onDisk)
        XCTAssertTrue(try retry.mainContext.fetch(FetchDescriptor<Outfit>()).isEmpty)
    }

    func testFailedDiaryMetadataSaveRemovesNewPNGAndPreservesExistingSnapshot() throws {
        let item = try garment()
        var canvas = FlatlayComposition(layers: [try outfits.layer(for: item, in: FlatlayComposition())])
        let journal = JournalStore(context: container.mainContext, assets: garments.assets)
        let entry = try journal.save(name: "Keep diary", date: Date(), note: "Original", composition: canvas)
        let renderedID = entry.renderedAsset?.id
        let before = try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasSuffix(".png") }.sorted()
        let readOnly = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self,
            configurations: ModelConfiguration(url: directory.appending(path: "wardrobe.store"), allowsSave: false))
        let saved = try XCTUnwrap(readOnly.mainContext.fetch(FetchDescriptor<JournalEntry>()).first)
        canvas.background = .charcoal
        XCTAssertThrowsError(try JournalStore(context: readOnly.mainContext, assets: garments.assets).save(
            name: "Do not keep", date: Date(), note: "Changed", composition: canvas, updating: saved))
        XCTAssertEqual(saved.name, "Keep diary")
        XCTAssertEqual(saved.note, "Original")
        XCTAssertEqual(saved.renderedAsset?.id, renderedID)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasSuffix(".png") }.sorted(), before)
        XCTAssertFalse(readOnly.mainContext.hasChanges)
    }

    func testFailedWearingAndReversalPreserveEntryAndGarmentCounts() throws {
        let item = try garment()
        let canvas = FlatlayComposition(layers: [try outfits.layer(for: item, in: FlatlayComposition())])
        let journal = JournalStore(context: container.mainContext, assets: garments.assets)
        let entry = try journal.save(name: "Wearing", date: Date(), note: "", composition: canvas)
        let configuration = ModelConfiguration(url: directory.appending(path: "wardrobe.store"), allowsSave: false)
        let readOnly = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self, configurations: configuration)
        let saved = try XCTUnwrap(readOnly.mainContext.fetch(FetchDescriptor<JournalEntry>()).first)
        let savedItem = try XCTUnwrap(readOnly.mainContext.fetch(FetchDescriptor<Garment>()).first)
        XCTAssertThrowsError(try JournalStore(context: readOnly.mainContext, assets: garments.assets).recordWearing(saved))
        XCTAssertFalse(saved.wearingRecorded)
        XCTAssertTrue(saved.wearRecords.isEmpty)
        XCTAssertTrue(savedItem.wearRecords.isEmpty)
        XCTAssertFalse(readOnly.mainContext.hasChanges)

        try journal.recordWearing(entry)
        let second = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self, configurations: configuration)
        let recorded = try XCTUnwrap(second.mainContext.fetch(FetchDescriptor<JournalEntry>()).first)
        let recordedItem = try XCTUnwrap(second.mainContext.fetch(FetchDescriptor<Garment>()).first)
        let eventID = try XCTUnwrap(recorded.wearRecords.first).id
        XCTAssertThrowsError(try JournalStore(context: second.mainContext, assets: garments.assets).reverseWearing(recorded))
        XCTAssertTrue(recorded.wearingRecorded)
        XCTAssertEqual(recorded.wearRecords.map(\.id), [eventID])
        XCTAssertEqual(recordedItem.wearRecords.map(\.id), [eventID])
        XCTAssertFalse(second.mainContext.hasChanges)
    }

    func testFailedDiaryDeletionPreservesEntryAndRetentionState() throws {
        let item = try garment()
        let canvas = FlatlayComposition(layers: [try outfits.layer(for: item, in: FlatlayComposition())])
        let journal = JournalStore(context: container.mainContext, assets: garments.assets)
        let entry = try journal.save(name: "Keep diary", date: Date(), note: "", composition: canvas)
        try journal.recordWearing(entry)
        let readOnly = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self,
            configurations: ModelConfiguration(url: directory.appending(path: "wardrobe.store"), allowsSave: false))
        let saved = try XCTUnwrap(readOnly.mainContext.fetch(FetchDescriptor<JournalEntry>()).first)
        let renderedID = saved.renderedAsset?.id
        XCTAssertThrowsError(try JournalStore(context: readOnly.mainContext, assets: garments.assets).delete(saved))
        let retained = try XCTUnwrap(readOnly.mainContext.fetch(FetchDescriptor<JournalEntry>()).first)
        XCTAssertEqual(retained.name, "Keep diary")
        XCTAssertTrue(retained.wearingRecorded)
        XCTAssertEqual(retained.renderedAsset?.id, renderedID)
        XCTAssertEqual(retained.wearRecords.count, 1)
        XCTAssertFalse(try XCTUnwrap(retained.wearRecords.first).retainedAfterEntryDeletion)
        XCTAssertTrue(readOnly.mainContext.deletedModelsArray.isEmpty)
        XCTAssertTrue(readOnly.mainContext.insertedModelsArray.isEmpty)
        let retry = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self,
            configurations: ModelConfiguration(url: directory.appending(path: "wardrobe.store")))
        let onDisk = try XCTUnwrap(retry.mainContext.fetch(FetchDescriptor<JournalEntry>()).first)
        XCTAssertEqual(onDisk.name, "Keep diary")
        XCTAssertEqual(onDisk.renderedAsset?.id, renderedID)
        XCTAssertFalse(try XCTUnwrap(onDisk.wearRecords.first).retainedAfterEntryDeletion)
        try JournalStore(context: retry.mainContext, assets: garments.assets).delete(onDisk)
        XCTAssertTrue(try retry.mainContext.fetch(FetchDescriptor<JournalEntry>()).isEmpty)
        XCTAssertEqual(try retry.mainContext.fetch(FetchDescriptor<WearRecord>()).count, 1)
    }

    func testRetiredJournalCanBecomeReusableOutfitAndKeepsGarmentReferences() throws {
        let item = try garment()
        let canvas = FlatlayComposition(layers: [try outfits.layer(for: item, in: FlatlayComposition())])
        let journal = JournalStore(context: container.mainContext, assets: garments.assets)
        let entry = try journal.save(name: "Earlier day", date: Date(), note: "", composition: canvas)
        try garments.retire(item)
        XCTAssertThrowsError(try garments.delete(item))
        let look = try journal.saveAsOutfit(entry)
        let today = try journal.useToday(look)
        XCTAssertEqual(try today.composition(), canvas)
        XCTAssertEqual(today.garments.map(\.id), [item.id])
        XCTAssertFalse(WardrobeFilter().matches(item))
        XCTAssertThrowsError(try outfits.layer(for: item, in: canvas))
    }

    func testWearingCountsDistinctGarmentsOncePerDayAcrossEntriesAndKeepsHistoryAfterDeletion() throws {
        let item = try garment(status: GarmentStatus.candidate)
        let layer = try outfits.layer(for: item, in: FlatlayComposition())
        let repeated = CompositionLayer(assetID: layer.assetID, garmentID: item.id, width: 0.2, height: 0.2)
        let canvas = FlatlayComposition(layers: [layer, repeated])
        let journal = JournalStore(context: container.mainContext, assets: garments.assets)
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let first = try journal.save(name: "First", date: day, note: "", composition: canvas)
        let second = try journal.save(name: "Second", date: day.addingTimeInterval(60), note: "", composition: canvas)
        try journal.recordWearing(first)
        try journal.recordWearing(first)
        try journal.recordWearing(second)
        XCTAssertEqual(item.wearRecords.count, 1)
        XCTAssertEqual(item.status, GarmentStatus.candidate)
        let nextDay = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 1, to: day))
        let third = try journal.save(name: "Third", date: nextDay, note: "", composition: canvas)
        try journal.recordWearing(third)
        XCTAssertEqual(item.wearRecords.count, 2)
        try journal.delete(first)
        try journal.delete(second)
        try journal.delete(third)
        XCTAssertEqual(item.wearRecords.count, 2)
        try ShoppingStore(context: container.mainContext, assets: garments.assets).remove(item)
        XCTAssertEqual(item.status, GarmentStatus.discarded)
        XCTAssertThrowsError(try garments.delete(item))
        let result = try WearMetrics.summary(price: item.amount, openingWears: item.openingWearCount,
            openingIsEstimated: item.openingWearIsEstimate, recordedWears: item.wearRecords.count)
        XCTAssertEqual(result.costPerWear, 60)
    }

    func testFutureWearingIsRejectedAndDiaryDateEditsKeepOriginalWearDate() throws {
        let item = try garment()
        let canvas = FlatlayComposition(layers: [try outfits.layer(for: item, in: FlatlayComposition())])
        let journal = JournalStore(context: container.mainContext, assets: garments.assets)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let tomorrow = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 1, to: now))
        let entry = try journal.save(name: "Tomorrow", date: tomorrow, note: "", composition: canvas)
        XCTAssertThrowsError(try journal.recordWearing(entry, now: now))
        XCTAssertFalse(entry.wearingRecorded)
        XCTAssertTrue(item.wearRecords.isEmpty)
        try journal.recordWearing(entry, now: tomorrow)
        try journal.save(name: "Changed", date: now, note: "", composition: canvas, updating: entry)
        XCTAssertEqual(entry.name, "Changed")
        XCTAssertEqual(entry.date, now)
        XCTAssertEqual(item.wearRecords.first?.date, Calendar.current.startOfDay(for: tomorrow))
        XCTAssertEqual(item.wearRecords.count, 1)
    }

    func testWearingReversalRetainsOtherEntriesAndDeletedEntryHistory() throws {
        let item = try garment()
        let canvas = FlatlayComposition(layers: [try outfits.layer(for: item, in: FlatlayComposition())])
        let journal = JournalStore(context: container.mainContext, assets: garments.assets)
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let first = try journal.save(name: "One", date: day, note: "", composition: canvas)
        let second = try journal.save(name: "Two", date: day, note: "", composition: canvas)
        try journal.recordWearing(first)
        try journal.recordWearing(second)
        try journal.reverseWearing(first)
        XCTAssertFalse(first.wearingRecorded)
        XCTAssertTrue(first.wearRecords.isEmpty)
        XCTAssertEqual(item.wearRecords.count, 1)
        try journal.reverseWearing(second)
        XCTAssertTrue(item.wearRecords.isEmpty)
        try journal.recordWearing(first)
        try journal.recordWearing(second)
        try journal.delete(first)
        try journal.reverseWearing(second)
        XCTAssertEqual(item.wearRecords.count, 1)
        XCTAssertTrue(item.wearRecords[0].retainedAfterEntryDeletion)
    }

    func testRecordedDiaryProtectsGarmentSetAndAllowsIndependentLayoutEdits() throws {
        let first = try garment()
        let second = try garment(status: GarmentStatus.candidate)
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let journal = JournalStore(context: container.mainContext, assets: garments.assets)
        let original = FlatlayComposition(layers: [try outfits.layer(for: first, in: FlatlayComposition())])
        let entry = try journal.save(name: "Recorded look", date: day, note: "", composition: original)
        try journal.recordWearing(entry)
        let eventID = try XCTUnwrap(first.wearRecords.first?.id)
        let renderedID = try XCTUnwrap(entry.renderedAsset?.id)
        let filesBefore = try FileManager.default.contentsOfDirectory(atPath: directory.path)

        var added = original
        added.layers.append(try outfits.layer(for: second, in: added))
        var replaced = original
        replaced.layers = [try outfits.layer(for: second, in: replaced)]
        for invalid in [added, replaced] {
            XCTAssertThrowsError(try journal.save(name: "Rejected edit", date: day, note: "Rejected note",
                composition: invalid, updating: entry)) { error in
                guard case JournalError.recordedGarmentsChanged = error else { return XCTFail("Unexpected error: \(error)") }
            }
            XCTAssertEqual(entry.name, "Recorded look")
            XCTAssertEqual(entry.note, "")
            XCTAssertEqual(try entry.composition(), original)
            XCTAssertEqual(entry.renderedAsset?.id, renderedID)
            XCTAssertEqual(first.wearRecords.map(\.id), [eventID])
            XCTAssertTrue(second.wearRecords.isEmpty)
            XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(atPath: directory.path)), Set(filesBefore))
        }

        var adjusted = original
        adjusted.background = .charcoal
        try adjusted.move(adjusted.layers[0].id, x: 0.25, y: 0.7)
        try adjusted.rotate(adjusted.layers[0].id, degrees: 35)
        adjusted.layers.append(try outfits.layer(for: first, in: adjusted))
        try journal.save(name: "Adjusted look", date: day, note: "User note", composition: adjusted, updating: entry)
        let reopened = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self,
            configurations: ModelConfiguration(url: directory.appending(path: "wardrobe.store")))
        let saved = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<JournalEntry>()).first)
        XCTAssertEqual(saved.id, entry.id)
        XCTAssertEqual(try saved.composition(), adjusted)
        XCTAssertEqual(saved.note, "User note")
        XCTAssertTrue(saved.wearingRecorded)
        XCTAssertEqual(saved.wearRecords.map(\.id), [eventID])
        XCTAssertEqual(saved.wearRecords.first?.date, Calendar.current.startOfDay(for: day))
        XCTAssertEqual(saved.garments.map(\.id), [first.id])
        XCTAssertNotEqual(saved.renderedAsset?.id, renderedID)
        XCTAssertNotNil(UIImage(data: try garments.assets.loadData(for: XCTUnwrap(saved.renderedAsset))))
        let reopenedJournal = JournalStore(context: reopened.mainContext, assets: garments.assets)
        try reopenedJournal.reverseWearing(saved)
        try reopenedJournal.reverseWearing(saved)
        XCTAssertTrue(try reopened.mainContext.fetch(FetchDescriptor<WearRecord>()).isEmpty)
        try reopenedJournal.save(name: "Corrected garments", date: day, note: saved.note, composition: replaced, updating: saved)
        try reopenedJournal.recordWearing(saved)
        XCTAssertEqual(saved.garments.map(\.id), [second.id])
        XCTAssertEqual(saved.wearRecords.count, 1)
        XCTAssertEqual(saved.wearRecords.first?.garment?.id, second.id)
        XCTAssertEqual(saved.garments.first?.status, GarmentStatus.candidate)
    }

    func testHiddenHistoricalGarmentsCanRecordAndReverseWearingAfterReopening() throws {
        let owned = try garment()
        let candidate = try garment(status: GarmentStatus.candidate)
        let journal = JournalStore(context: container.mainContext, assets: garments.assets)
        let composition = FlatlayComposition(layers: [try outfits.layer(for: owned, in: FlatlayComposition()),
            try outfits.layer(for: candidate, in: FlatlayComposition())])
        let entry = try journal.save(name: "Historical look", date: Date(timeIntervalSince1970: 1_700_000_000),
            note: "", composition: composition)
        let renderedBytes = try garments.assets.loadData(for: XCTUnwrap(entry.renderedAsset))
        try garments.retire(owned)
        try ShoppingStore(context: container.mainContext, assets: garments.assets).remove(candidate)
        let reopened = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self,
            configurations: ModelConfiguration(url: directory.appending(path: "wardrobe.store")))
        let context = reopened.mainContext
        let saved = try XCTUnwrap(context.fetch(FetchDescriptor<JournalEntry>()).first)
        let records = try context.fetch(FetchDescriptor<Garment>())
        XCTAssertEqual(Set(records.map(\.status)), [GarmentStatus.retired, GarmentStatus.discarded])
        XCTAssertFalse(records.contains { WardrobeFilter().matches($0) || GarmentCollection.shopping.matches($0) })
        let history = JournalStore(context: context, assets: garments.assets)
        for _ in 0..<2 {
            try history.recordWearing(saved)
            try history.recordWearing(saved)
            XCTAssertEqual(try context.fetch(FetchDescriptor<WearRecord>()).count, 2)
            XCTAssertTrue(records.allSatisfy { $0.wearRecords.count == 1 })
            try history.reverseWearing(saved)
            XCTAssertFalse(saved.wearingRecorded)
            XCTAssertTrue(try context.fetch(FetchDescriptor<WearRecord>()).isEmpty)
            XCTAssertTrue(records.allSatisfy { $0.wearRecords.isEmpty })
        }
        XCTAssertEqual(try saved.composition(), composition)
        XCTAssertEqual(try garments.assets.loadData(for: XCTUnwrap(saved.renderedAsset)), renderedBytes)
        XCTAssertEqual(records.count, 2)
        for record in records {
            XCTAssertThrowsError(try OutfitStore(context: context, assets: garments.assets).layer(for: record, in: composition))
        }
        let persisted = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self,
            configurations: ModelConfiguration(url: directory.appending(path: "wardrobe.store")))
        XCTAssertTrue(try persisted.mainContext.fetch(FetchDescriptor<WearRecord>()).isEmpty)
        XCTAssertFalse(try XCTUnwrap(persisted.mainContext.fetch(FetchDescriptor<JournalEntry>()).first).wearingRecorded)
        XCTAssertEqual(try persisted.mainContext.fetch(FetchDescriptor<Garment>()).count, 2)
    }

    func testWearingUsesCalendarDaysAcrossBothDaylightSavingTransitions() throws {
        let item = try garment()
        let composition = FlatlayComposition(layers: [try outfits.layer(for: item, in: FlatlayComposition())])
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Stockholm"))
        let journal = JournalStore(context: container.mainContext, assets: garments.assets, calendar: calendar)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 11, day: 1)))
        for (month, day, hours) in [(3, 30, 23), (10, 26, 25)] {
            let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: month, day: day)))
            let next = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: start))
            XCTAssertEqual(next.timeIntervalSince(start), Double(hours * 3600))
            let first = try journal.save(name: "Before clock change", date: start.addingTimeInterval(1800), note: "", composition: composition)
            let last = try journal.save(name: "Same local day", date: next.addingTimeInterval(-60), note: "", composition: composition)
            let following = try journal.save(name: "Next local day", date: next.addingTimeInterval(60), note: "", composition: composition)
            try journal.recordWearing(first, now: now)
            try journal.recordWearing(last, now: now)
            XCTAssertEqual(first.wearRecords.first?.id, last.wearRecords.first?.id)
            try journal.recordWearing(following, now: now)
            XCTAssertNotEqual(first.wearRecords.first?.id, following.wearRecords.first?.id)
        }
        let reopened = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self,
            configurations: ModelConfiguration(url: directory.appending(path: "wardrobe.store")))
        XCTAssertEqual(try reopened.mainContext.fetch(FetchDescriptor<WearRecord>()).count, 4)
        let saved = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<Garment>()).first)
        XCTAssertEqual(saved.wearRecords.count, 4)
    }

    func testHistoricalCountInfersEstimateAndColorFiltersMatchAnyChosenColor() throws {
        let item = try garment()
        var draft = GarmentDraft(item)
        draft.openingWearCount = "20"
        draft.colorTags = ["black", "blue"]
        try garments.update(item, draft: draft)
        XCTAssertTrue(item.openingWearIsEstimate)
        XCTAssertTrue(WardrobeFilter(colors: ["blue", "red"]).matches(item))
        XCTAssertFalse(WardrobeFilter(colors: ["red", "white"]).matches(item))
        XCTAssertFalse(WardrobeFilter(category: "Jeans", colors: ["black"]).matches(item))
        draft = GarmentDraft(item)
        draft.openingWearCount = "0"
        try garments.update(item, draft: draft)
        XCTAssertFalse(item.openingWearIsEstimate)
    }

    func testAbandonedExportsCleanOnlyOwnedTemporaryFilesAndReportWriteFailure() throws {
        let exports = directory.appending(path: "exports")
        try FileManager.default.createDirectory(at: exports, withIntermediateDirectories: true)
        let png = try CharacterStickerStore.png(CharacterAppearance())
        let first = exports.appending(path: "\(TemporaryOutfitExports.prefix)\(UUID().uuidString).png")
        let second = exports.appending(path: "\(TemporaryOutfitExports.prefix)\(UUID().uuidString).png")
        let unrelated = exports.appending(path: "reference.png")
        let otherType = exports.appending(path: "\(TemporaryOutfitExports.prefix)notes.txt")
        try png.write(to: first)
        try png.write(to: second)
        try png.write(to: unrelated)
        try Data("retained notes".utf8).write(to: otherType)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: exports.path)
        defer { try! FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: exports.path) }
        XCTAssertThrowsError(try TemporaryOutfitExports.removeAbandoned(in: exports))
        XCTAssertEqual(try Data(contentsOf: first), png)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: exports.path)
        try TemporaryOutfitExports.removeAbandoned(in: exports)
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: second.path))
        XCTAssertEqual(try Data(contentsOf: unrelated), png)
        XCTAssertEqual(try String(contentsOf: otherType, encoding: .utf8), "retained notes")
        try TemporaryOutfitExports.removeAbandoned(in: exports)
    }

    func testCharacterPNGHasTransparencyAndOptionsChangeRealPixels() throws {
        let original = try CharacterStickerStore.png(CharacterAppearance())
        var appearance = CharacterAppearance()
        appearance.hair = 0x252526
        appearance.longHair = false
        appearance.glasses = true
        let changed = try CharacterStickerStore.png(appearance)
        XCTAssertNotEqual(original, changed)
        let image = try XCTUnwrap(UIImage(data: changed)?.cgImage)
        XCTAssertEqual(image.width, 640)
        XCTAssertEqual(image.height, 800)
        var pixel = [UInt8](repeating: 0, count: 4)
        let bitmap = try XCTUnwrap(CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8,
            bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        bitmap.draw(image, in: CGRect(x: 0, y: 0, width: 640, height: 800))
        XCTAssertEqual(pixel[3], 0, "The corner outside the character must remain transparent.")
    }

    func testCharacterPreferencesPersistMigrateAndReportRealFileFailures() throws {
        let suite = "wearwise-character-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let file = directory.appending(path: "character.json")
        let preferences = CharacterPreferences(fileURL: file, legacyDefaults: defaults)
        XCTAssertEqual(try preferences.load(), CharacterAppearance())
        let oldData = try JSONSerialization.data(withJSONObject: ["skin": 0xE2B597, "hair": 0x252526, "top": 0x3E63DD,
            "longHair": false, "glasses": true, "smiling": true])
        defaults.set(oldData, forKey: "wearwise.character")
        var appearance = try preferences.load()
        XCTAssertEqual(appearance.hair, 0x252526)
        XCTAssertEqual(appearance.hairstyle, .cropped)
        XCTAssertEqual(appearance.gender, .female)
        XCTAssertTrue(appearance.glasses)
        XCTAssertEqual(appearance.build, .medium)
        appearance.faceShape = .square
        appearance.eyes = .almond
        appearance.nose = .defined
        appearance.height = .tall
        appearance.shoulders = .broad
        appearance.build = .full
        appearance.gender = .male
        appearance.hairstyle = .wavy
        appearance.eyebrows = .arched
        appearance.lips = .full
        appearance.earrings = .hoops
        appearance.necklace = true
        try preferences.save(appearance)
        XCTAssertNil(defaults.data(forKey: "wearwise.character"))
        XCTAssertEqual(try preferences.load(), appearance)
        let savedBytes = try Data(contentsOf: file)
        let blocked = directory.appending(path: "blocked-preferences")
        try Data("file, not a directory".utf8).write(to: blocked)
        let unavailable = CharacterPreferences(fileURL: blocked.appending(path: "character.json"), legacyDefaults: defaults)
        XCTAssertThrowsError(try unavailable.save(CharacterAppearance()))
        XCTAssertEqual(try Data(contentsOf: file), savedBytes)
        try Data("invalid JSON".utf8).write(to: file)
        XCTAssertThrowsError(try preferences.load())
    }

    func testEveryCharacterCategoryChangesActualRenderedPixels() throws {
        let original = try CharacterStickerStore.png(CharacterAppearance())
        var variants: [CharacterAppearance] = []
        for value in FaceShape.allCases where value != .oval { var a = CharacterAppearance(); a.faceShape = value; variants.append(a) }
        for value in EyeShape.allCases where value != .round { var a = CharacterAppearance(); a.eyes = value; variants.append(a) }
        for value in NoseShape.allCases where value != .soft { var a = CharacterAppearance(); a.nose = value; variants.append(a) }
        for value in BodyBuild.allCases where value != .medium { var a = CharacterAppearance(); a.build = value; variants.append(a) }
        for value in CharacterHeight.allCases where value != .medium { var a = CharacterAppearance(); a.height = value; variants.append(a) }
        for value in ShoulderWidth.allCases where value != .medium { var a = CharacterAppearance(); a.shoulders = value; variants.append(a) }
        for value in HairStyle.allCases where value != .long { var a = CharacterAppearance(); a.hairstyle = value; variants.append(a) }
        for value in PartLength.allCases where value != .medium {
            var torso = CharacterAppearance(); torso.torsoLength = value; variants.append(torso)
            var arms = CharacterAppearance(); arms.armLength = value; variants.append(arms)
        }
        for value in LimbBuild.allCases where value != .medium {
            var arms = CharacterAppearance(); arms.armBuild = value; variants.append(arms)
            var legs = CharacterAppearance(); legs.legBuild = value; variants.append(legs)
        }
        for value in BeardStyle.allCases where value != .none { var a = CharacterAppearance(); a.beard = value; variants.append(a) }
        for value in LipShape.allCases where value != .natural { var a = CharacterAppearance(); a.lips = value; variants.append(a) }
        for value in EyebrowShape.allCases where value != .soft { var a = CharacterAppearance(); a.eyebrows = value; variants.append(a) }
        for value in BodySilhouette.allCases where value != .balanced { var a = CharacterAppearance(); a.silhouette = value; variants.append(a) }
        for value in FacialStructure.allCases where value != .soft { var a = CharacterAppearance(); a.facialStructure = value; variants.append(a) }
        for value in EyeSize.allCases where value != .medium { var a = CharacterAppearance(); a.eyeSize = value; variants.append(a) }
        for value in MouthShape.allCases where value != .smile { var a = CharacterAppearance(); a.mouth = value; variants.append(a) }
        for value in HairTreatment.allCases where value != .solid { var a = CharacterAppearance(); a.hairTreatment = value; variants.append(a) }
        var iris = CharacterAppearance(); iris.iris = 0x408EA2; variants.append(iris)
        for value in CharacterColor.skin where value.value != CharacterAppearance().skin { var a = CharacterAppearance(); a.skin = value.value; variants.append(a) }
        for value in CharacterColor.hair where value.value != CharacterAppearance().hair { var a = CharacterAppearance(); a.hair = value.value; variants.append(a) }
        var lips = CharacterAppearance(); lips.lips = .full; variants.append(lips)
        for appearance in variants {
            let data = try CharacterStickerStore.png(appearance)
            XCTAssertNotEqual(data, original)
            let image = try XCTUnwrap(UIImage(data: data)?.cgImage)
            XCTAssertEqual(image.width, 640)
            XCTAssertEqual(image.height, 800)
        }
    }

    func testBothGendersKeepIndependentOptionsAndLegacyHairMigrates() throws {
        for gender in CharacterGender.allCases {
            for style in HairStyle.allCases {
                var appearance = CharacterAppearance()
                appearance.gender = gender; appearance.facialStructure = gender == .male ? .defined : .soft; appearance.silhouette = gender == .male ? .straight : .balanced; appearance.hairstyle = style
                appearance.earrings = .hoops; appearance.glasses = true; appearance.necklace = true
                appearance.hair = 0xB7B8BE; appearance.skin = 0x493328; appearance.build = .full
                let data = try JSONEncoder().encode(appearance)
                XCTAssertEqual(try JSONDecoder().decode(CharacterAppearance.self, from: data), appearance)
                let prior = appearance
                appearance.gender = gender == .male ? .female : .male
                XCTAssertEqual(appearance.hairstyle, prior.hairstyle)
                XCTAssertEqual(appearance.hair, prior.hair)
                XCTAssertEqual(appearance.skin, prior.skin)
                XCTAssertEqual(appearance.earrings, prior.earrings)
                XCTAssertEqual(appearance.build, prior.build)
                XCTAssertEqual(try CharacterStickerStore.png(appearance), try CharacterStickerStore.png(prior), "Legacy gender does not override independently selected features.")
            }
        }
        for long in [true, false] {
            let old = try JSONSerialization.data(withJSONObject: ["longHair": long, "glasses": true])
            let appearance = try JSONDecoder().decode(CharacterAppearance.self, from: old)
            XCTAssertEqual(appearance.hairstyle, long ? .long : .cropped)
            XCTAssertTrue(appearance.glasses)
        }
        let invalid = Data(#"{"gender":"male","hairstyle":"missing"}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(CharacterAppearance.self, from: invalid))
    }

    private func characterRender(_ appearance: CharacterAppearance, framing: CharacterFraming = .body, scale: CGFloat = 4) throws -> CGImage {
        let bounds = framing.bounds
        let renderer = ImageRenderer(content: CharacterSticker(appearance: appearance, framing: framing).frame(width: bounds.width * scale, height: bounds.height * scale))
        renderer.scale = 1
        return try XCTUnwrap(renderer.uiImage?.cgImage)
    }

    private func characterPixel(_ image: CGImage, at point: CGPoint, framing: CharacterFraming = .body, scale: CGFloat = 4) throws -> [UInt8] {
        let bounds = framing.bounds
        let crop = try XCTUnwrap(image.cropping(to: CGRect(x: (point.x - bounds.minX) * scale, y: (point.y - bounds.minY) * scale, width: 1, height: 1)))
        var pixel = [UInt8](repeating: 0, count: 4)
        try pixel.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: 1, height: 1,
                bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.draw(crop, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return pixel
    }

    private func assertCharacterPixel(_ image: CGImage, at point: CGPoint, value: UInt32, framing: CharacterFraming = .body, label: String) throws {
        let pixel = try characterPixel(image, at: point, framing: framing)
        XCTAssertEqual(pixel[3], 255, "Transparent joint: \(label) at \(point)")
        for (channel, shift) in [16, 8, 0].enumerated() {
            XCTAssertEqual(Double(pixel[channel]), Double((value >> shift) & 255), accuracy: 3,
                "Unexpected joint color: \(label) at \(point)")
        }
    }

    func testShoulderWidthChangesUpperBodyWithoutScalingLegsOrWaist() throws {
        func region(_ image: CGImage, _ rect: CGRect) throws -> Data {
            let bounds = CharacterFraming.body.bounds
            let crop = try XCTUnwrap(image.cropping(to: CGRect(x: rect.minX * 4,
                y: (rect.minY - bounds.minY) * 4, width: rect.width * 4, height: rect.height * 4)))
            return try XCTUnwrap(UIImage(cgImage: crop).pngData())
        }
        for silhouette in BodySilhouette.allCases {
            for torso in PartLength.allCases {
                var a = CharacterAppearance()
                a.silhouette = silhouette; a.torsoLength = torso; a.build = .full
                a.legBuild = .muscular; a.hairstyle = .bald
                let base = try characterRender(a)
                let legs = try region(base, CGRect(x: 0, y: 140, width: 160, height: 70))
                // The central waistband stays clear of arms as their attachment points move.
                let waist = try region(base, CGRect(x: 75, y: 90, width: 10, height: 10))
                let upper = try region(base, CGRect(x: 20, y: 50, width: 120, height: 30))
                for shoulders in [ShoulderWidth.narrow, .broad] {
                    a.shoulders = shoulders
                    let image = try characterRender(a)
                    XCTAssertEqual(try region(image, CGRect(x: 0, y: 140, width: 160, height: 70)), legs)
                    XCTAssertEqual(try region(image, CGRect(x: 75, y: 90, width: 10, height: 10)), waist)
                    XCTAssertNotEqual(try region(image, CGRect(x: 20, y: 50, width: 120, height: 30)), upper)
                    if silhouette == .balanced && torso == .short {
                        let attachment = XCTAttachment(image: UIImage(cgImage: image))
                        attachment.name = "Independent shoulders - \(shoulders)"
                        attachment.lifetime = .keepAlways
                        add(attachment)
                    }
                }
            }
        }
    }

    func testNecklineRemainsFilledAcrossFaceAndShoulderOptions() throws {
        for gender in CharacterGender.allCases {
            for face in FaceShape.allCases {
                for shoulders in ShoulderWidth.allCases {
                    for torso in PartLength.allCases {
                        var a = CharacterAppearance()
                        a.facialStructure = gender == .male ? .defined : .soft
                        a.faceShape = face; a.shoulders = shoulders; a.torsoLength = torso; a.hairstyle = .bald
                        let image = try characterRender(a, framing: .face)
                        for x: CGFloat in [79,80,81] {
                            for y: CGFloat in [49,50,51,52] {
                                let pixel = try characterPixel(image, at: .init(x: x, y: y), framing: .face)
                                XCTAssertGreaterThanOrEqual(pixel[3], 250, "Transparent neckline: \(gender)/\(face)/\(shoulders)/\(torso) at \(x),\(y)")
                            }
                        }
                    }
                }
            }
        }
    }

    func testHairRootsFormOneConnectedSilhouette() throws {
        for gender in CharacterGender.allCases {
            for face in FaceShape.allCases {
                for hairstyle in HairStyle.allCases {
                    var a = CharacterAppearance()
                    a.gender = gender; a.facialStructure = gender == .male ? .defined : .soft; a.silhouette = gender == .male ? .straight : .balanced; a.faceShape = face; a.hairstyle = hairstyle
                    let image = try characterRender(a, framing: .hair)
                    let bounds = CharacterFraming.hair.bounds
                    let crop = try XCTUnwrap(image.cropping(to: CGRect(x: 0, y: (0 - bounds.minY) * 4,
                        width: CGFloat(image.width), height: 44 * 4)))
                    let width = crop.width, height = crop.height
                    var pixels = [UInt8](repeating: 0, count: width * height * 4)
                    try pixels.withUnsafeMutableBytes { bytes in
                        let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: width, height: height,
                            bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
                        context.draw(crop, in: CGRect(x: 0, y: 0, width: width, height: height))
                    }
                    var visited = [Bool](repeating: false, count: width * height)
                    var components: [Int] = []
                    for origin in 0..<(width * height) where !visited[origin] && pixels[origin * 4 + 3] >= 128 {
                        var queue = [origin], next = 0
                        visited[origin] = true
                        while next < queue.count {
                            let point = queue[next], x = point % width, y = point / width
                            next += 1
                            for (nx, ny) in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)] where nx >= 0 && nx < width && ny >= 0 && ny < height {
                                let candidate = ny * width + nx
                                if !visited[candidate] && pixels[candidate * 4 + 3] >= 128 {
                                    visited[candidate] = true; queue.append(candidate)
                                }
                            }
                        }
                        // Ignore isolated antialiasing pixels; a detached lock is substantially larger.
                        if queue.count > 8 { components.append(queue.count) }
                    }
                    XCTAssertEqual(components.count, 1, "Disconnected hair root: \(gender)/\(face)/\(hairstyle), components \(components)")
                }
            }
        }
    }

    private func assertIllustratedCharacterConnected(_ appearance: CharacterAppearance, label: String) throws {
        let image = try characterRender(appearance, scale: 1)
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        try pixels.withUnsafeMutableBytes { bytes in
            let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        var visited = [Bool](repeating: false, count: width * height)
        var sizes: [Int] = []
        for origin in 0..<(width * height) where !visited[origin] && pixels[origin * 4 + 3] >= 128 {
            var queue = [origin], next = 0
            visited[origin] = true
            while next < queue.count {
                let point = queue[next], x = point % width, y = point / width
                next += 1
                for (xx, yy) in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)] where xx >= 0 && xx < width && yy >= 0 && yy < height {
                    let candidate = yy * width + xx
                    if !visited[candidate] && pixels[candidate * 4 + 3] >= 128 {
                        visited[candidate] = true; queue.append(candidate)
                    }
                }
            }
            if queue.count > 3 { sizes.append(queue.count) }
        }
        XCTAssertEqual(sizes.count, 1, "Illustrated parts must form one connected figure at sticker size: \(label), components \(sizes)")
    }

    func testCharacterPartConnectionsAcrossSupportedOptions() throws {
        for silhouette in BodySilhouette.allCases {
            for build in BodyBuild.allCases {
                for torso in PartLength.allCases {
                    for width in LimbBuild.allCases {
                        for height in CharacterHeight.allCases {
                            var a = CharacterAppearance()
                            a.silhouette = silhouette; a.build = build; a.torsoLength = torso
                            a.armBuild = width; a.legBuild = width; a.height = height; a.hairstyle = .bald
                            try assertIllustratedCharacterConnected(a, label: "\(silhouette)/\(build)/\(torso)/\(width)/\(height)")
                        }
                    }
                }
            }
        }
        for silhouette in BodySilhouette.allCases {
            for shoulders in ShoulderWidth.allCases {
                for width in LimbBuild.allCases {
                    for length in PartLength.allCases {
                        for torso in PartLength.allCases {
                            var a = CharacterAppearance()
                            a.silhouette = silhouette; a.shoulders = shoulders; a.armBuild = width
                            a.armLength = length; a.torsoLength = torso; a.hairstyle = .bald
                            try assertIllustratedCharacterConnected(a, label: "\(silhouette)/\(shoulders)/\(width)/\(length)/\(torso)")
                        }
                    }
                }
            }
        }
    }

    func testRefinedCloseCropsStayInsideTheScalp() throws {
        func alpha(_ image: CGImage) throws -> [UInt8] {
            var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
            try bytes.withUnsafeMutableBytes { storage in
                let context = try XCTUnwrap(CGContext(data: storage.baseAddress, width: image.width, height: image.height,
                    bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
                context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            }
            return stride(from: 3, to: bytes.count, by: 4).map { bytes[$0] }
        }
        for structure in FacialStructure.allCases {
            for face in FaceShape.allCases {
                var a = CharacterAppearance()
                a.facialStructure = structure; a.faceShape = face; a.hairstyle = .bald
                let bald = try alpha(characterRender(a, framing: .face))
                for style in [HairStyle.buzzCut, .shaved] {
                    a.hairstyle = style
                    let rendered = try characterRender(a, framing: .face)
                    let cap = try alpha(rendered)
                    let bounds = CharacterFraming.face.bounds
                    for y in 0..<Int((42 - bounds.minY) * 4) {
                        for x in 0..<rendered.width {
                            let i = y * rendered.width + x
                            if bald[i] < 50 { XCTAssertLessThan(cap[i], 200, "Hair floats outside the scalp: \(structure)/\(face)/\(style)") }
                        }
                    }
                    if structure == .soft && face == .oval {
                        let attachment = XCTAttachment(image: UIImage(cgImage: rendered))
                        attachment.name = "Fitted scalp - \(style)"; attachment.lifetime = .keepAlways; add(attachment)
                    }
                }
            }
        }
    }

    func testRefinedEyesAndFittedBaseRenderAllOptions() throws {
        var images: Set<Data> = []
        for eyes in EyeShape.allCases {
            var a = CharacterAppearance(); a.eyes = eyes; a.hairstyle = .cropped
            let image = try characterRender(a, framing: .face)
            images.insert(try XCTUnwrap(UIImage(cgImage: image).pngData()))
            if [.deepSet, .doubleFold, .monolid, .upturned].contains(eyes) {
                let attachment = XCTAttachment(image: UIImage(cgImage: image))
                attachment.name = "Eye shape - \(eyes)"; attachment.lifetime = .keepAlways; add(attachment)
            }
        }
        XCTAssertEqual(images.count, 12)
        for leg in LimbBuild.allCases {
            var a = CharacterAppearance(); a.legBuild = leg; a.armBuild = .muscular
            a.shoulders = .narrow; a.torsoLength = .short
            try assertIllustratedCharacterConnected(a, label: "Fitted base / \(leg)")
            let attachment = XCTAttachment(image: UIImage(cgImage: try characterRender(a)))
            attachment.name = "Fitted base - \(leg)"; attachment.lifetime = .keepAlways; add(attachment)
        }
    }

    func testRemovedHighlightsDecodeAsSolidAndAreNotOffered() throws {
        let old = Data(#"{"hairTreatment":"highlights","hairAccent":15110062}"#.utf8)
        let appearance = try JSONDecoder().decode(CharacterAppearance.self, from: old)
        XCTAssertEqual(appearance.hairTreatment, .solid)
        XCTAssertEqual(HairTreatment.allCases, [.solid, .ombre])
        XCTAssertEqual(EyeShape.allCases.count, 12)
    }

    func testCustomCharacterColorsTreatmentsAndLegacyDefaults() throws {
        let old = Data(#"{"gender":"male","smiling":false,"longHair":false,"glasses":true,"earrings":"hoops","necklace":true}"#.utf8)
        var appearance = try JSONDecoder().decode(CharacterAppearance.self, from: old)
        XCTAssertEqual(appearance.facialStructure, .defined)
        XCTAssertEqual(appearance.silhouette, .straight)
        XCTAssertEqual(appearance.mouth, .neutral)
        var plain = appearance; plain.glasses = false; plain.earrings = .none; plain.necklace = false
        XCTAssertEqual(try CharacterStickerStore.png(plain), try CharacterStickerStore.png(appearance))
        appearance.hairstyle = .long; appearance.hair = 0x39275A; appearance.hairAccent = 0xE78FAE
        appearance.iris = 0x298A95; appearance.beardColor = 0x9C3D70; appearance.eyeSize = .large
        appearance.hairTreatment = .ombre
        let encoded = try JSONEncoder().encode(appearance)
        XCTAssertEqual(try JSONDecoder().decode(CharacterAppearance.self, from: encoded), appearance)
        let preferences = CharacterPreferences(fileURL: directory.appending(path: "custom-colors.json"))
        try preferences.save(appearance)
        XCTAssertEqual(try preferences.load(), appearance)
        for mouth in MouthShape.allCases {
            var fullness: Set<Data> = []
            for lips in LipShape.allCases { var value = appearance; value.mouth = mouth; value.lips = lips; fullness.insert(try CharacterStickerStore.png(value)) }
            XCTAssertEqual(fullness.count, 3, "Mouth fullness must stay visible with \(mouth).")
        }
        var rendered: Set<Data> = []
        var facePixels: [[UInt8]] = []
        for treatment in HairTreatment.allCases {
            appearance.hairTreatment = treatment
            rendered.insert(try CharacterStickerStore.png(appearance))
            let image = try characterRender(appearance)
            facePixels.append(try characterPixel(image, at: .init(x: 80, y: 39)))
            if treatment == .ombre {
                let upper = try characterPixel(image, at: .init(x: 65.6, y: 45.6))
                let lower = try characterPixel(image, at: .init(x: 64.4, y: 60.8))
                XCTAssertGreaterThanOrEqual(upper[3], 250, "The sample must fall inside the painted hair.")
                XCTAssertGreaterThanOrEqual(lower[3], 250, "The sample must fall inside the painted hair.")
                XCTAssertNotEqual(lower, [0xE5, 0xE6, 0xE8, 255], "The lower sample must fall on hair, not the shirt.")
                XCTAssertNotEqual(lower, [UInt8((appearance.skin >> 16) & 255), UInt8((appearance.skin >> 8) & 255), UInt8(appearance.skin & 255), 255], "The lower sample must fall on hair, not skin.")
                XCTAssertNotEqual(upper, lower, "Ombre must change the actual hair color along its length.")
            }
        }
        XCTAssertEqual(rendered.count, 2)
        XCTAssertEqual(Set(facePixels.map { Data($0) }).count, 1, "Hair paint must not change skin pixels.")
        for length in PartLength.allCases {
            appearance.torsoLength = length
            let image = try characterRender(appearance)
            let ground = try (40...120).map { x in try characterPixel(image, at: .init(x: CGFloat(x), y: 197)) }
            XCTAssertTrue(ground.contains { $0[3] >= 128 }, "The feet must remain on the same ground plane when torso length changes.")
        }
        XCTAssertEqual(CharacterSection.allCases.count, 6)
        XCTAssertEqual(HairStyle.allCases.count, 34)
    }

    func testAthleticLimbBuildsPersistIndependently() throws {
        let preferences = CharacterPreferences(fileURL: directory.appending(path: "athletic-limbs.json"))
        let legacy = Data(#"{"armBuild":"slender","legBuild":"full","build":"medium"}"#.utf8)
        var appearance = try JSONDecoder().decode(CharacterAppearance.self, from: legacy)
        XCTAssertEqual(appearance.armBuild, .slender)
        XCTAssertEqual(appearance.legBuild, .full)
        var arms: Set<Data> = [], legs: Set<Data> = []
        for value in [LimbBuild.lean, .athletic, .muscular] {
            appearance.armBuild = value; appearance.silhouette = .athletic
            try preferences.save(appearance)
            XCTAssertEqual(try preferences.load(), appearance)
            XCTAssertEqual(try preferences.load().legBuild, .full)
            arms.insert(try CharacterStickerStore.png(appearance))
        }
        appearance.armBuild = .lean
        for value in [LimbBuild.lean, .athletic, .muscular] {
            appearance.legBuild = value; appearance.silhouette = .muscular
            try preferences.save(appearance)
            XCTAssertEqual(try preferences.load(), appearance)
            XCTAssertEqual(try preferences.load().armBuild, .lean)
            legs.insert(try CharacterStickerStore.png(appearance))
        }
        XCTAssertEqual(arms.count, 3)
        XCTAssertEqual(legs.count, 3)
    }

    func testCharacterBaseUsesBareFeet() throws {
        for build in LimbBuild.allCases {
            for height in CharacterHeight.allCases {
                var appearance = CharacterAppearance()
                appearance.legBuild = build; appearance.height = height
                let end: CGFloat = height == .petite ? 182 : height == .tall ? 210 : 198
                let image = try characterRender(appearance)
                let crop = try XCTUnwrap(image.cropping(to: CGRect(x: 0, y: (end - 12 - CharacterFraming.body.bounds.minY) * 4,
                    width: CGFloat(image.width), height: 12 * 4)))
                let width = crop.width, rows = crop.height
                var pixels = [UInt8](repeating: 0, count: width * rows * 4)
                try pixels.withUnsafeMutableBytes { bytes in
                    let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: width, height: rows,
                        bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
                    context.draw(crop, in: CGRect(x: 0, y: 0, width: width, height: rows))
                }
                var visible = 0, nonSkin = 0
                for i in stride(from: 0, to: pixels.count, by: 4) where pixels[i + 3] >= 128 {
                    visible += 1
                    if Int(pixels[i]) - Int(pixels[i + 2]) <= 8 { nonSkin += 1 }
                }
                XCTAssertGreaterThan(visible, 50, "The feet must remain visible: \(build)/\(height)")
                XCTAssertEqual(nonSkin, 0, "The base character must have bare feet without neutral shoe or sole pixels: \(build)/\(height)")
            }
        }
    }

    func testCharacterCombinationContactSheets() throws {
        var base = CharacterAppearance()
        base.gender = .male; base.hairstyle = .cropped; base.eyes = .almond
        func sheet(_ name: String, columns: Int, framing: CharacterFraming = .face, cases: [(String, CharacterAppearance)]) throws {
            let images = try cases.map { item in
                let png = try CharacterStickerStore.png(item.1)
                let exported = try XCTUnwrap(UIImage(data: png)?.cgImage)
                XCTAssertEqual(exported.width, 640)
                XCTAssertEqual(exported.height, 800)
                let renderer = ImageRenderer(content: CharacterSticker(appearance: item.1, framing: framing).frame(width: 128, height: 168))
                renderer.scale = 1
                return try XCTUnwrap(renderer.uiImage)
            }
            let rows = (cases.count + columns - 1) / columns
            let size = CGSize(width: columns * 128, height: rows * 198)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let data = UIGraphicsImageRenderer(size: size, format: format).pngData { context in
                UIColor(white: 0.95, alpha: 1).setFill()
                context.fill(CGRect(origin: .zero, size: size))
                for (index, image) in images.enumerated() {
                    let x = CGFloat(index % columns * 128), y = CGFloat(index / columns * 198)
                    image.draw(in: CGRect(x: x, y: y, width: 128, height: 168))
                    (cases[index].0 as NSString).draw(in: CGRect(x: x + 4, y: y + 170, width: 120, height: 28), withAttributes: [
                        .font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.black
                    ])
                }
            }
            XCTAssertNotNil(UIImage(data: data))
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
            attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        }
        for gender in CharacterGender.allCases {
            var cases: [(String, CharacterAppearance)] = []
            for face in FaceShape.allCases {
                var distinct: Set<Data> = []
                for beard in BeardStyle.allCases {
                    var appearance = base
                    appearance.gender = gender; appearance.facialStructure = gender == .male ? .defined : .soft; appearance.silhouette = gender == .male ? .straight : .balanced; appearance.faceShape = face; appearance.beard = beard
                    distinct.insert(try CharacterStickerStore.png(appearance))
                    cases.append(("\(face.rawValue) / \(beard.title)", appearance))
                }
                XCTAssertEqual(distinct.count, BeardStyle.allCases.count, "Every beard must remain distinct for \(gender) / \(face).")
            }
            try sheet("Face and beard matrix - \(gender.rawValue)", columns: 8, cases: cases)
        }
        var colors: [(String, CharacterAppearance)] = []
        var distinctColors: Set<Data> = []
        for skin in CharacterColor.skin {
            for beardColor in CharacterColor.hair {
                var appearance = base
                appearance.skin = skin.value; appearance.beardColor = beardColor.value; appearance.beard = .stubble
                distinctColors.insert(try CharacterStickerStore.png(appearance))
                colors.append(("\(skin.name) / \(beardColor.name)", appearance))
            }
        }
        XCTAssertEqual(distinctColors.count, 56, "Independent skin and stubble colors must render independently.")
        try sheet("Stubble skin and color matrix", columns: 7, cases: colors)
        for start in stride(from: 0, to: HairStyle.allCases.count, by: 7) {
            var cases: [(String, CharacterAppearance)] = []
            for hairstyle in HairStyle.allCases[start..<min(start + 7, HairStyle.allCases.count)] {
                for beard in BeardStyle.allCases {
                    var appearance = base
                    appearance.hairstyle = hairstyle; appearance.beard = beard
                    cases.append(("\(hairstyle.title) / \(beard.title)", appearance))
                }
            }
            try sheet("Hair and beard matrix - \(start / 7 + 1)", columns: 8, cases: cases)
        }
        var mouths: [(String, CharacterAppearance)] = []
        for mouth in MouthShape.allCases {
            for lips in LipShape.allCases {
                for beard in BeardStyle.allCases {
                    var appearance = base
                    appearance.mouth = mouth; appearance.lips = lips; appearance.beard = beard
                    mouths.append(("\(mouth.rawValue) / \(lips.rawValue) / \(beard.title)", appearance))
                }
            }
        }
        try sheet("Mouth fullness and beard matrix", columns: 8, cases: mouths)
        var treatments: [(String, CharacterAppearance)] = []
        for treatment in HairTreatment.allCases {
            for hairstyle in [HairStyle.long, .ponytail, .braids, .curlyLong] {
                var appearance = base; appearance.hairstyle = hairstyle; appearance.hairTreatment = treatment
                appearance.hair = 0x39275A; appearance.hairAccent = 0xE78FAE
                treatments.append(("\(hairstyle.title) / \(treatment)", appearance))
            }
        }
        try sheet("Custom hair treatments", columns: 4, framing: .hair, cases: treatments)
        var armJoints: [(String, CharacterAppearance)] = []
        var legJoints: [(String, CharacterAppearance)] = []
        var headJoints: [(String, CharacterAppearance)] = []
        for gender in CharacterGender.allCases {
            for shoulders in ShoulderWidth.allCases {
                for width in [LimbBuild.slender, .muscular] {
                    var a = base; a.gender = gender; a.facialStructure = gender == .male ? .defined : .soft; a.silhouette = gender == .male ? .straight : .balanced; a.shoulders = shoulders; a.armBuild = width
                    a.armLength = .short; a.torsoLength = .long; a.build = .full
                    armJoints.append(("\(gender) / \(shoulders) / \(width)", a))
                }
            }
            for width in LimbBuild.allCases {
                for height in [CharacterHeight.petite, .tall] {
                    var a = base; a.gender = gender; a.facialStructure = gender == .male ? .defined : .soft; a.silhouette = gender == .male ? .straight : .balanced; a.legBuild = width; a.height = height; a.build = .full; a.torsoLength = .long
                    legJoints.append(("\(gender) / \(width) / \(height)", a))
                }
            }
            for (index, face) in FaceShape.allCases.enumerated() {
                var a = base; a.gender = gender; a.facialStructure = gender == .male ? .defined : .soft; a.silhouette = gender == .male ? .straight : .balanced; a.faceShape = face
                a.hairstyle = [.bald, .quiff, .afro, .braids, .ponytail, .long, .lowPonytail, .locs][index]
                a.earrings = .hoops; a.glasses = true; a.necklace = true
                headJoints.append(("\(gender) / \(face) / \(a.hairstyle.title)", a))
            }
        }
        try sheet("Arm joint extremes", columns: 6, framing: .arms, cases: armJoints)
        try sheet("Leg and foot joint extremes", columns: 6, framing: .legs, cases: legJoints)
        try sheet("Head and hair crop extremes", columns: 6, framing: .hair, cases: headJoints)
    }

    func testIndependentPartsAndBeardsPersistWithEarlierSettings() throws {
        let old = Data(#"{"gender":"male","hairstyle":"wavy","hair":11027788,"height":"tall","build":"full","faceShape":"square","glasses":true}"#.utf8)
        var appearance = try JSONDecoder().decode(CharacterAppearance.self, from: old)
        XCTAssertEqual(appearance.gender, .male)
        XCTAssertEqual(appearance.hairstyle, .wavy)
        XCTAssertEqual(appearance.beard, .none)
        XCTAssertEqual(appearance.beardColor, appearance.hair)
        XCTAssertEqual(appearance.torsoLength, .medium)
        XCTAssertEqual(appearance.armLength, .medium)
        XCTAssertEqual(appearance.armBuild, .medium)
        XCTAssertEqual(appearance.legBuild, .medium)
        appearance.torsoLength = .short
        appearance.armLength = .long
        appearance.armBuild = .slender
        appearance.legBuild = .full
        appearance.beard = .handlebar
        appearance.beardColor = 0xB7B8BE
        let suite = "wearwise-expanded-character-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = CharacterPreferences(fileURL: directory.appending(path: "expanded-character.json"), legacyDefaults: defaults)
        try preferences.save(appearance)
        let saved = try preferences.load()
        XCTAssertEqual(saved, appearance)
        XCTAssertEqual(saved.height, .tall)
        XCTAssertEqual(saved.build, .full)
        var differentHair = saved
        differentHair.hairstyle = .braids
        differentHair.hair = 0x252526
        XCTAssertEqual(differentHair.beard, .handlebar)
        XCTAssertEqual(differentHair.beardColor, 0xB7B8BE)
        XCTAssertEqual(differentHair.armLength, .long)
        XCTAssertNotEqual(try CharacterStickerStore.png(saved), try CharacterStickerStore.png(differentHair))
        var previews: [Data] = []
        for style in BeardStyle.allCases {
            var value = saved; value.beard = style
            let png = try CharacterStickerStore.png(value)
            XCTAssertFalse(previews.contains(png), "Every beard must have its own rendered appearance.")
            previews.append(png)
            let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
            attachment.name = "Expanded beard - \(style.title)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testCharacterAssetSurvivesDiaryAndUnusedStickerFilesAreRemoved() throws {
        let stickers = CharacterStickerStore(context: container.mainContext, assets: garments.assets)
        let kept = try stickers.create(CharacterAppearance())
        let retainedPixels = try garments.assets.loadData(for: kept)
        var changed = CharacterAppearance()
        changed.gender = .male; changed.hairstyle = .bob; changed.earrings = .hoops
        let suite = "wearwise-sticker-retention-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = CharacterPreferences(fileURL: directory.appending(path: "changed-character.json"), legacyDefaults: defaults)
        try preferences.save(changed)
        let unused = try stickers.create(preferences.load())
        XCTAssertNotEqual(try garments.assets.loadData(for: unused), retainedPixels)
        let canvas = FlatlayComposition(layers: [CompositionLayer(assetID: kept.id, width: 0.3, height: 0.3)])
        let entry = try JournalStore(context: container.mainContext, assets: garments.assets).save(name: "Character", date: Date(), note: "", composition: canvas)
        _ = try outfits.save(name: "Retained character", composition: canvas)
        try stickers.removeUnused([kept, unused])
        XCTAssertEqual(try garments.assets.loadData(for: kept), retainedPixels)
        XCTAssertFalse(FileManager.default.fileExists(atPath: garments.assets.url(for: unused).path))
        XCTAssertEqual(try outfits.images(for: entry.composition()).count, 1)
        XCTAssertThrowsError(try JournalStore(context: container.mainContext, assets: garments.assets).recordWearing(entry))
        let item = try garment()
        var combined = canvas
        combined.layers.append(try outfits.layer(for: item, in: combined))
        try combined.move(combined.layers[0].id, x: 0.25, y: 0.5)
        try combined.move(combined.layers[1].id, x: 0.7, y: 0.5)
        let output = try FlatlayRenderer.png(composition: combined, images: outfits.images(for: combined))
        let characterOnly = try FlatlayRenderer.png(composition: canvas, images: outfits.images(for: canvas))
        XCTAssertNotEqual(output, characterOnly)
        var garmentOnly = combined
        try garmentOnly.remove(garmentOnly.layers[0].id)
        XCTAssertNotEqual(output, try FlatlayRenderer.png(composition: garmentOnly, images: outfits.images(for: garmentOnly)))
        let attachment = XCTAttachment(data: output, uniformTypeIdentifier: "public.png")
        attachment.name = "Real garment and character composition"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

@MainActor
final class CharacterDesignSyncTests: XCTestCase {
    private let region = CGRect(x: 52, y: 20, width: 56, height: 30)

    private func pixels(_ layers: [IllustrationLayer]) throws -> [UInt8] {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = false
        let image = UIGraphicsImageRenderer(size: CGSize(width: region.width * 4, height: region.height * 4), format: format).image { context in
            context.cgContext.scaleBy(x: 4, y: 4); context.cgContext.translateBy(x: -region.minX, y: -region.minY)
            for layer in layers { CharacterIllustrations.shared.image(layer).draw(in: layer.drawingFrame) }
        }
        let cg = try XCTUnwrap(image.cgImage)
        var bytes = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: cg.width, height: cg.height, bitsPerComponent: 8, bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        }
        return bytes
    }

    func testCharacterPreviewDiskCacheSurvivesRendererRecreation() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let disk = CharacterPreviewDiskCache(rootURL: directory, generation: "test-build-1")
        var appearance = CharacterAppearance()
        appearance.hairstyle = .curtains
        let request = CharacterPreviewRequest(appearance: appearance, framing: .hair, width: 208, height: 260)
        let clock = ContinuousClock(), coldStart = clock.now
        let first = try await CharacterPreviewRenderer(diskCache: disk).image(for: request)
        let cold = coldStart.duration(to: clock.now)
        let file = try disk.fileURL(for: request)
        let before = try FileManager.default.attributesOfItem(atPath: file.path)
        let png = try Data(contentsOf: file)
        let oldDate = Date(timeIntervalSince1970: 1)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: file.path)
        let warmStart = clock.now
        let reopened = try await CharacterPreviewRenderer(diskCache: disk).image(for: request)
        let warm = warmStart.duration(to: clock.now)
        let after = try FileManager.default.attributesOfItem(atPath: file.path)
        XCTAssertEqual(before[.systemFileNumber] as? NSNumber, after[.systemFileNumber] as? NSNumber,
            "A disk hit must read the existing file, not atomically replace it with a rerender.")
        XCTAssertGreaterThan(try XCTUnwrap(after[.modificationDate] as? Date), oldDate)
        XCTAssertEqual(try Data(contentsOf: file), png)
        XCTAssertEqual(first.image.pngData(), reopened.image.pngData())
        XCTAssertEqual(reopened.image.cgImage?.width, 208)
        XCTAssertEqual(reopened.image.cgImage?.height, 260)
        var other = request.appearance
        other.hair = 0xFFBBDD
        let requests = [
            CharacterPreviewRequest(appearance: other, framing: .hair, width: 208, height: 260),
            CharacterPreviewRequest(appearance: appearance, framing: .face, width: 208, height: 260),
            CharacterPreviewRequest(appearance: appearance, framing: .hair, width: 416, height: 520),
        ]
        for variant in requests { XCTAssertNotEqual(try disk.fileURL(for: variant), file) }
        print("Character preview: first render=\(cold), persistent cache hit=\(warm), PNG bytes=\(png.count)")
    }

    func testCharacterPreviewDiskCacheRecoversAfterCorruptionAndSystemPurge() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let disk = CharacterPreviewDiskCache(rootURL: directory, generation: "test-build-1")
        let request = CharacterPreviewRequest(appearance: CharacterAppearance(), framing: .face, width: 128, height: 164)
        let first = try await CharacterPreviewRenderer(diskCache: disk).image(for: request)
        let file = try disk.fileURL(for: request)
        try Data("Interrupted PNG data".utf8).write(to: file)
        let repaired = try await CharacterPreviewRenderer(diskCache: disk).image(for: request)
        XCTAssertEqual(first.image.pngData(), repaired.image.pngData())
        XCTAssertNotNil(UIImage(data: try Data(contentsOf: file)))
        let worker = CharacterPreviewRenderer(diskCache: disk)
        _ = try await worker.image(for: request)
        try FileManager.default.removeItem(at: directory)
        let changed = CharacterPreviewRequest(appearance: request.appearance, framing: .body, width: 160, height: 240)
        _ = try await worker.image(for: changed)
        XCTAssertTrue(FileManager.default.fileExists(atPath: try disk.fileURL(for: changed).path))
    }

    func testCharacterPreviewDiskCacheEvictsOldFilesAndInvalidatesBuilds() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let root = directory.appending(path: "cache")
        let preference = directory.appending(path: "WearwiseCharacter.json")
        let preferences = CharacterPreferences(fileURL: preference)
        try preferences.save(CharacterAppearance())
        let saved = try Data(contentsOf: preference)
        let sourceDisk = CharacterPreviewDiskCache(rootURL: directory.appending(path: "source"), generation: "source")
        let worker = CharacterPreviewRenderer(diskCache: sourceDisk)
        var requests: [CharacterPreviewRequest] = []
        var images: [CharacterPreviewImage] = []
        for style in [HairStyle.long, .curtains, .texturedSlickBack] {
            var appearance = CharacterAppearance(); appearance.hairstyle = style
            let request = CharacterPreviewRequest(appearance: appearance, framing: .body, width: 160, height: 240)
            requests.append(request)
            images.append(try await worker.image(for: request))
        }
        let sizes = try images.map { try XCTUnwrap($0.image.pngData()).count }
        let limit = sizes[0] + max(sizes[1], sizes[2])
        var disk = CharacterPreviewDiskCache(rootURL: root, generation: "build-one", byteLimit: limit)
        for index in 0..<2 { try disk.store(images[index].image, for: requests[index]) }
        for index in 0..<2 {
            try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: Double(index + 1))], ofItemAtPath: try disk.fileURL(for: requests[index]).path)
        }
        XCTAssertNotNil(try disk.load(requests[0]))
        try disk.store(images[2].image, for: requests[2])
        XCTAssertTrue(FileManager.default.fileExists(atPath: try disk.fileURL(for: requests[0]).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: try disk.fileURL(for: requests[1]).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: try disk.fileURL(for: requests[2]).path))
        let files = try FileManager.default.contentsOfDirectory(at: disk.directory, includingPropertiesForKeys: [.fileSizeKey])
        let total = try files.reduce(0) { try $0 + ($1.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) }
        XCTAssertLessThanOrEqual(total, limit)
        var updated = CharacterPreviewDiskCache(rootURL: root, generation: "build-two", byteLimit: limit)
        XCTAssertNil(try updated.load(requests[0]))
        XCTAssertFalse(FileManager.default.fileExists(atPath: disk.directory.path))
        try updated.store(images[0].image, for: requests[0])
        XCTAssertNotNil(try updated.load(requests[0]))
        XCTAssertEqual(try Data(contentsOf: preference), saved)
        XCTAssertEqual(CharacterPreviewDiskCache().byteLimit, 32 * 1024 * 1024)
        XCTAssertEqual(CharacterPreviewDiskCache.currentGeneration(), CharacterPreviewDiskCache.currentGeneration())
    }

    func testBackgroundEditorPreviewPreservesExportAndReusesCachedImage() async throws {
        let worker = CharacterPreviewRenderer()
        var appearance = CharacterAppearance()
        appearance.hairstyle = .texturedSlickBack
        appearance.faceShape = .square
        appearance.facialStructure = .defined
        let request = CharacterPreviewRequest(appearance: appearance, framing: .body, width: 640, height: 800)
        let task = Task { try await worker.image(for: request) }
        let clock = ContinuousClock()
        let start = clock.now
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertLessThan(start.duration(to: clock.now), .seconds(1), "The main actor must remain available while previews render.")
        let first = try await task.value
        let original = try CharacterStickerStore.png(appearance)
        let cached = try await worker.image(for: request)
        XCTAssertTrue(first === cached)
        let expected = try XCTUnwrap(UIImage(data: original)?.cgImage)
        let actual = try XCTUnwrap(first.image.cgImage)
        XCTAssertEqual(actual.width, 640)
        XCTAssertEqual(actual.height, 800)
        func bytes(_ image: CGImage) throws -> [UInt8] {
            var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
            try data.withUnsafeMutableBytes { storage in
                let context = try XCTUnwrap(CGContext(data: storage.baseAddress, width: image.width, height: image.height,
                    bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
                context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            }
            return data
        }
        let a = try bytes(expected), b = try bytes(actual)
        var intersection = 0, union = 0, difference = 0, channels = 0
        for i in stride(from: 0, to: a.count, by: 4) {
            let visibleA = a[i + 3] >= 128, visibleB = b[i + 3] >= 128
            if visibleA || visibleB { union += 1 }
            if visibleA && visibleB {
                intersection += 1
                for c in 0..<3 { difference += abs(Int(a[i + c]) - Int(b[i + c])); channels += 1 }
            }
        }
        func hasNeighbor(_ bytes: [UInt8], x: Int, y: Int) -> Bool {
            for yy in max(0, y - 1)...min(actual.height - 1, y + 1) {
                for xx in max(0, x - 1)...min(actual.width - 1, x + 1) {
                    if bytes[(yy * actual.width + xx) * 4 + 3] >= 128 { return true }
                }
            }
            return false
        }
        var displaced = 0
        for y in 0..<actual.height {
            for x in 0..<actual.width {
                let i = (y * actual.width + x) * 4 + 3
                if a[i] >= 128 && b[i] < 128 && !hasNeighbor(b, x: x, y: y) { displaced += 1 }
                if b[i] >= 128 && a[i] < 128 && !hasNeighbor(a, x: x, y: y) { displaced += 1 }
            }
        }
        XCTAssertEqual(displaced, 0, "Canvas and UIKit edge antialiasing may differ by at most one output pixel.")
        XCTAssertGreaterThan(Double(intersection) / Double(union), 0.99)
        for (name, image) in [("Background preview", first.image), ("Original sticker export", UIImage(cgImage: expected))] {
            let attachment = XCTAttachment(image: image)
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        print("Preview comparison: IoU=\(Double(intersection) / Double(union)), RGB=\(Double(difference) / Double(channels)), displaced beyond one pixel=\(displaced)")
        XCTAssertLessThan(Double(difference) / Double(channels), 2)
        XCTAssertEqual(try CharacterStickerStore.png(appearance), original)
        appearance.hairstyle = .curtains
        let changed = try await worker.image(for: CharacterPreviewRequest(appearance: appearance, framing: .body, width: 640, height: 800))
        XCTAssertNotEqual(changed.image.pngData(), first.image.pngData())
        let canceled = Task { try await worker.image(for: request) }
        canceled.cancel()
        do { _ = try await canceled.value; XCTFail("Canceled requests must not publish an image.") }
        catch is CancellationError {}
    }

    func testCurrentCatalogAndNewStylesPersistAsRealTransparentStickers() throws {
        let art = CharacterIllustrations.shared
        XCTAssertEqual(art.sprites.count, 127)
        XCTAssertEqual(Set(art.sprites.values.map(\.atlas)).count, 22)
        XCTAssertEqual(HairStyle.allCases.count, 34)
        XCTAssertEqual(HairStyle.additions.count, 8)
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CharacterPreferences(fileURL: directory.appending(path: "character.json"))
        var images: Set<Data> = []
        for hairstyle in HairStyle.additions {
            var a = CharacterAppearance(); a.hairstyle = hairstyle
            a.facialStructure = .defined; a.faceShape = .square
            try store.save(a); XCTAssertEqual(try store.load(), a)
            let data = try CharacterStickerStore.png(store.load())
            XCTAssertTrue(images.insert(data).inserted)
            let image = try XCTUnwrap(UIImage(data: data)?.cgImage)
            XCTAssertEqual(image.width, 640); XCTAssertEqual(image.height, 800)
            let corner = try XCTUnwrap(image.cropping(to: CGRect(x: 0, y: 0, width: 1, height: 1)))
            var pixel = [UInt8](repeating: 0, count: 4)
            let context = try XCTUnwrap(CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(corner, in: CGRect(x: 0, y: 0, width: 1, height: 1)); XCTAssertEqual(pixel[3], 0)
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
            attachment.name = "Synchronized native - \(hairstyle.rawValue)"; attachment.lifetime = .keepAlways; add(attachment)
        }
    }

    func testNewHairFitsAllHeadsWithExposedShortCutEarsAndClearEyes() throws {
        let art = CharacterIllustrations.shared, width = 224, height = 120
        var cases = 0, earCases = 0
        for style in HairStyle.additions {
            for structure in FacialStructure.allCases {
                for face in FaceShape.allCases {
                    var a = CharacterAppearance(); a.hairstyle = style; a.facialStructure = structure; a.faceShape = face; a.eyes = .wide; a.eyeSize = .large
                    let layers = art.layers(a), head = try XCTUnwrap(layers.first { $0.id.hasPrefix("head/") })
                    let front = try XCTUnwrap(layers.first { $0.hairPart == "front" }), rear = try XCTUnwrap(layers.first { $0.hairPart == "rear" })
                    XCTAssertTrue(layers.first!.rearHair); XCTAssertEqual(rear.frame, front.frame)
                    let h = try pixels([head]), f = try pixels([front]), e = try pixels(layers.filter { $0.id.hasPrefix("eyes/") })
                    var eyeOverlap = 0, ears = 0, earOverlap = 0, leftContact = 0, rightContact = 0
                    for y in 0..<height { for x in 0..<width {
                        let i = (y * width + x) * 4 + 3, worldY = 20 + Double(y) / 4, worldX = 52 + Double(x) / 4
                        if f[i] >= 128 && e[i] >= 128 { eyeOverlap += 1 }
                        if worldY >= 24 && worldY < 37 && h[i] >= 128 && f[i] >= 128 {
                            if x < width / 2 { leftContact += 1 } else { rightContact += 1 }
                        }
                        if front.templeCut {
                            let t = (worldY - head.frame.minY) / head.frame.height, side = (worldX - head.frame.minX) / head.frame.width
                            if t >= 0.48 && t < 0.69 && (side < 0.1 || side > 0.9) && h[i] >= 180 {
                                ears += 1; if f[i] >= 128 { earOverlap += 1 }
                            }
                        }
                    } }
                    let label = "\(style)/\(structure)/\(face)"
                    XCTAssertEqual(eyeOverlap, 0, "Covered large eye: \(label)")
                    XCTAssertGreaterThan(leftContact, 0, "Detached left temple: \(label)")
                    XCTAssertGreaterThan(rightContact, 0, "Detached right temple: \(label)")
                    if front.templeCut { XCTAssertGreaterThan(ears, 0); XCTAssertEqual(earOverlap, 0, "Hair covers ear: \(label)"); earCases += 1 }
                    cases += 1
                }
            }
        }
        XCTAssertEqual(cases, 192); XCTAssertEqual(earCases, 72)
    }

    func testDenseBeardsLeaveEveryMouthShapeVisible() throws {
        let art = CharacterIllustrations.shared
        var cases = 0
        for structure in [FacialStructure.soft, .defined] {
            for beard in [BeardStyle.shortBeard, .fullBeard, .longBeard] {
                for shape in MouthShape.allCases {
                    for fullness in LipShape.allCases {
                        var a = CharacterAppearance(); a.facialStructure = structure; a.faceShape = structure == .soft ? .oval : .square
                        a.beard = beard; a.mouth = shape; a.lips = fullness
                        let layers = art.layers(a), mouth = try XCTUnwrap(layers.first { $0.id.hasPrefix("mouth/") }), hair = try XCTUnwrap(layers.first { $0.id.hasPrefix("beard/") })
                        XCTAssertNotNil(hair.mouthAttachment)
                        let m = try pixels([mouth]), b = try pixels([hair]); var covered = 0
                        for i in stride(from: 3, to: m.count, by: 4) where m[i] >= 128 && b[i] >= 128 { covered += 1 }
                        XCTAssertEqual(covered, 0, "Beard covers mouth: \(structure)/\(beard)/\(shape)/\(fullness)")
                        cases += 1
                    }
                }
            }
        }
        XCTAssertEqual(cases, 144)
    }

    func testOriginalLayeredHairRemainsAttachedAcrossEveryHead() throws {
        let art = CharacterIllustrations.shared, width = 224
        let styles = HairStyle.allCases.filter { !HairStyle.additions.contains($0) && ![HairStyle.bald, .buzzCut, .shaved].contains($0) }
        var cases = 0
        for style in styles { for structure in FacialStructure.allCases { for face in FaceShape.allCases {
            var a = CharacterAppearance(); a.hairstyle = style; a.facialStructure = structure; a.faceShape = face; a.eyes = .wide; a.eyeSize = .large
            let layers = art.layers(a), head = try XCTUnwrap(layers.first { $0.id.hasPrefix("head/") }), front = try XCTUnwrap(layers.first { $0.hairPart == "front" })
            // The torso paints the neck behind the jaw, so inspect the assembled figure.
            let h = try pixels([head]), f = try pixels([front]), combined = try pixels(layers)
            var left = 0, right = 0
            for y in 16..<68 { for x in 0..<width {
                let i = (y * width + x) * 4 + 3
                if h[i] >= 128 && f[i] >= 128 { if x < width / 2 { left += 1 } else { right += 1 } }
            } }
            let label = "\(style)/\(structure)/\(face)"
            XCTAssertGreaterThan(left, 0, "Detached left temple: \(label)"); XCTAssertGreaterThan(right, 0, "Detached right temple: \(label)")
            if style == .shag || style == .straightFringe {
                let eye = try pixels(layers.filter { $0.id.hasPrefix("eyes/") })
                let covered = stride(from: 3, to: eye.count, by: 4).filter { eye[$0] >= 128 && f[$0] >= 128 }.count
                XCTAssertEqual(covered, 0, "Covered eye: \(label)")
            }
            // Match the approved above-ear check; tied tendrils retain open loops below it.
            let scalpHeight = 56
            var visited = [Bool](repeating: false, count: width * scalpHeight)
            for origin in 0..<(width * scalpHeight) where !visited[origin] && combined[origin * 4 + 3] < 96 {
                var queue = [origin], next = 0, border = false, nearHead = false
                visited[origin] = true
                while next < queue.count {
                    let p = queue[next], x = p % width, y = p / width; next += 1
                    if x == 0 || x == width - 1 || y == 0 || y == scalpHeight - 1 { border = true }
                    if !nearHead && x >= 4 && x < width - 4 && y >= 4 && y < scalpHeight - 4 {
                        nearHead = [p - 4, p + 4, p - width * 4, p + width * 4].contains { h[$0 * 4 + 3] >= 128 }
                    }
                    for (xx, yy) in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)] where xx >= 0 && xx < width && yy >= 0 && yy < scalpHeight {
                        let candidate = yy * width + xx
                        if !visited[candidate] && combined[candidate * 4 + 3] < 96 { visited[candidate] = true; queue.append(candidate) }
                    }
                }
                if !border && nearHead && queue.count >= 8 {
                    let top = 20 + Double(queue.map { $0 / width }.min()!) / 4, bottom = 20 + Double(queue.map { $0 / width }.max()!) / 4
                    XCTFail("Closed scalp/ear gap: \(label), \(queue.count) pixels at y=\(top)...\(bottom)")
                }
            }
            cases += 1
        } } }
        XCTAssertEqual(cases, 552)
    }

    func testNativeHairAndFaceReviewSheets() throws {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        for structure in FacialStructure.allCases {
            let sheet = UIGraphicsImageRenderer(size: CGSize(width: 1120, height: 620), format: format).image { _ in
                UIColor(white: 0.97, alpha: 1).setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 1120, height: 620))
                for (index, style) in HairStyle.additions.enumerated() {
                    var a = CharacterAppearance(); a.hairstyle = style; a.facialStructure = structure; a.faceShape = .square; a.eyes = .almond
                    let renderer = ImageRenderer(content: CharacterSticker(appearance: a, framing: .hair).frame(width: 260, height: 260))
                    renderer.scale = 1
                    let x = CGFloat(index % 4) * 280, y = CGFloat(index / 4) * 310
                    renderer.uiImage?.draw(in: CGRect(x: x + 10, y: y, width: 260, height: 260))
                    (style.title as NSString).draw(in: CGRect(x: x + 10, y: y + 270, width: 260, height: 30), withAttributes: [.font: UIFont.systemFont(ofSize: 16), .foregroundColor: UIColor.black])
                }
            }
            let attachment = XCTAttachment(image: sheet); attachment.name = "Native hair review - \(structure.rawValue)"; attachment.lifetime = .keepAlways; add(attachment)
        }
    }
}

@MainActor
final class JournalLayerRevisionTests: XCTestCase {
    private var directory: URL!
    private var database: ModelContainer!
    private var assets: AssetStore!

    override func setUpWithError() throws {
        directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        database = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self, JournalEntry.self, WearRecord.self, Brand.self,
            configurations: ModelConfiguration(url: directory.appending(path: "revision.store")))
        assets = AssetStore(baseURL: directory)
    }

    override func tearDownWithError() throws {
        database = nil
        try FileManager.default.removeItem(at: directory)
    }

    private func garment(_ name: String) throws -> Garment {
        let item = Garment(name: name, category: "T-shirt", brand: "Revision brand")
        let png = try ImageImportService.normalizedPNG(from: garmentFixture())
        try GarmentStore(context: database.mainContext, assets: assets).saveImages(original: png, cutout: png, on: item)
        return item
    }

    func testBrandWearNotesPersistAndDeletionPreservesGarments() throws {
        let garment = try garment("A")
        let store = BrandStore(context: database.mainContext, assets: assets)
        var draft = BrandDraft(name: "Revision brand")
        draft.notes = "Earlier free-form notes"
        draft.fitNotes = "Relaxed shoulders"
        draft.sizingNotes = "Size M fits; sleeves run long"
        draft.fabricNotes = "Cotton, gentle wash"
        let brand = try store.save(draft, inspirations: [garmentFixture()])
        let garmentID = garment.id
        let brandID = brand.id
        let image = try XCTUnwrap(brand.inspirationAsset)
        let imageURL = assets.url(for: image)
        let garmentImage = try XCTUnwrap(garment.originalAsset)
        let original = try assets.loadData(for: garmentImage)
        let reopened = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self, JournalEntry.self, WearRecord.self, Brand.self,
            configurations: ModelConfiguration(url: directory.appending(path: "revision.store")))
        let persisted = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<Brand>()).first { $0.id == brandID })
        XCTAssertEqual(persisted.fitNotes, draft.fitNotes)
        XCTAssertEqual(persisted.sizingNotes, draft.sizingNotes)
        XCTAssertEqual(persisted.fabricNotes, draft.fabricNotes)
        XCTAssertEqual(persisted.notes, "Earlier free-form notes")
        XCTAssertNil(try store.delete(brand))
        XCTAssertFalse(FileManager.default.fileExists(atPath: imageURL.path))
        XCTAssertTrue(try database.mainContext.fetch(FetchDescriptor<Brand>()).isEmpty)
        let retained = try XCTUnwrap(database.mainContext.fetch(FetchDescriptor<Garment>()).first { $0.id == garmentID })
        XCTAssertNil(retained.brandRecord)
        XCTAssertEqual(retained.brand, "Revision brand")
        XCTAssertEqual(try assets.loadData(for: XCTUnwrap(retained.originalAsset)), original)
        XCTAssertEqual(OwnedBrandGroup.groups(from: [retained]).first?.name, "Revision brand")
    }

    func testJournalSelectionCreatesAnIndependentRecordAndWearingRemainsExplicit() throws {
        let first = try garment("A"), second = try garment("B")
        let context = database.mainContext
        let journals = JournalStore(context: context, assets: assets)
        let outfits = OutfitStore(context: context, assets: assets)
        let layout = try journals.recordComposition([first, second])
        let outfit = try outfits.save(name: "Reusable collage", composition: layout)
        let entry = try journals.save(name: "Wore this", date: Date(), note: "Comfortable", composition: layout, from: outfit)
        let savedImage = try assets.loadData(for: XCTUnwrap(entry.renderedAsset))
        XCTAssertFalse(entry.wearingRecorded)
        XCTAssertTrue(first.wearRecords.isEmpty)
        var changed = layout
        try changed.resize(changed.layers[0].id, width: 0.7, height: 0.2)
        try outfits.save(name: outfit.name, composition: changed, updating: outfit)
        XCTAssertEqual(try entry.composition(), layout)
        XCTAssertEqual(try assets.loadData(for: XCTUnwrap(entry.renderedAsset)), savedImage)
        try journals.recordWearing(entry)
        try journals.recordWearing(entry)
        XCTAssertEqual(first.wearRecords.count, 1)
        XCTAssertEqual(second.wearRecords.count, 1)
        XCTAssertThrowsError(try journals.save(name: entry.name, date: entry.date, note: "Changed pieces", composition: journals.recordComposition([first]), updating: entry))
        try journals.reverseWearing(entry)
        XCTAssertTrue(first.wearRecords.isEmpty)
        let oldID = layout.layers.first { $0.garmentID == first.id }!.id
        try GarmentStore(context: context, assets: assets).retire(first)
        let retained = try journals.recordComposition([first], preserving: layout)
        XCTAssertEqual(retained.layers.first?.id, oldID)
        try journals.save(name: entry.name, date: entry.date, note: "One retained piece", composition: retained, updating: entry)
        XCTAssertEqual(entry.garments.map(\.id), [first.id])
    }

    func testOversizedLayersClipToTheArtboardAndIndependentHeightFillsItsFrame() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { context in
            UIColor.red.setFill(); context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        }
        let asset = UUID()
        let oversized = FlatlayComposition(width: 100, height: 125, layers: [CompositionLayer(assetID: asset, width: 2, height: 2)])
        let renderer = ImageRenderer(content: CompositionCanvas(composition: oversized, images: [asset: image])
            .frame(width: 100, height: 125).padding(20).background(Color.green))
        renderer.scale = 1
        let actual = try XCTUnwrap(renderer.uiImage?.cgImage)
        func pixel(_ image: CGImage, _ x: Int, _ y: Int) throws -> [UInt8] {
            var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
            try bytes.withUnsafeMutableBytes { storage in
                let context = try XCTUnwrap(CGContext(data: storage.baseAddress, width: image.width, height: image.height,
                    bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
                context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            }
            return Array(bytes[(y * image.width + x) * 4..<(y * image.width + x) * 4 + 4])
        }
        for point in [(5, 82), (135, 82), (70, 5), (70, 160)] {
            let color = try pixel(actual, point.0, point.1)
            XCTAssertGreaterThan(color[1], color[0])
        }
        let composition = FlatlayComposition(width: 100, height: 125, layers: [CompositionLayer(assetID: asset, width: 0.4, height: 0.6)])
        let exported = try XCTUnwrap(UIImage(data: FlatlayRenderer.png(composition: composition, images: [asset: image]))?.cgImage)
        let red = try pixel(exported, 50, 30)
        XCTAssertGreaterThan(red[0], 240)
        XCTAssertLessThan(red[1], 20)
    }
}

@MainActor
final class FlowRevisionTests: XCTestCase {
    private var directory: URL!
    private var database: ModelContainer!
    private var assets: AssetStore!

    override func setUpWithError() throws {
        directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        database = try open()
        assets = AssetStore(baseURL: directory.appending(path: "images"))
    }

    override func tearDownWithError() throws {
        database = nil
        try FileManager.default.removeItem(at: directory)
    }

    private func open(readOnly: Bool = false) throws -> ModelContainer {
        try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self, JournalEntry.self, WearRecord.self, Brand.self,
            configurations: ModelConfiguration(url: directory.appending(path: "flows.store"), allowsSave: !readOnly))
    }

    private func garment(_ name: String, status: String = GarmentStatus.owned) throws -> Garment {
        let item = Garment(name: name, category: "T-shirt", brand: "Example", status: status)
        let png = try ImageImportService.normalizedPNG(from: garmentFixture())
        try GarmentStore(context: database.mainContext, assets: assets).saveImages(original: png, cutout: png, on: item)
        return item
    }

    private func composition(_ garments: [Garment]) throws -> FlatlayComposition {
        try JournalStore(context: database.mainContext, assets: assets).recordComposition(garments)
    }

    func testJournalSaveEditAndDeleteSynchronizeSharedDailyWears() throws {
        let a = try garment("A"), b = try garment("B")
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let next = Calendar.current.date(byAdding: .day, value: 1, to: day)!
        let store = JournalStore(context: database.mainContext, assets: assets)
        let first = try store.saveRecord(name: "First", date: day, note: "", composition: composition([a]))
        let second = try store.saveRecord(name: "Second", date: day, note: "", composition: composition([a]))
        XCTAssertTrue(first.wearingRecorded)
        XCTAssertEqual(a.wearRecords.count, 1)
        XCTAssertEqual(first.wearRecords.first?.id, second.wearRecords.first?.id)
        try store.saveRecord(name: "Changed", date: next, note: "", composition: composition([b]), updating: first)
        XCTAssertEqual(a.wearRecords.count, 1)
        XCTAssertEqual(b.wearRecords.count, 1)
        XCTAssertTrue(Calendar.current.isDate(try XCTUnwrap(first.wearRecords.first).date, inSameDayAs: next))
        try store.deleteRecord(second)
        XCTAssertEqual(a.wearRecords.count, 0)
        XCTAssertEqual(b.wearRecords.count, 1)
        let reopened = try open()
        let retained = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<JournalEntry>()).first)
        XCTAssertEqual(retained.name, "Changed")
        XCTAssertEqual(retained.wearRecords.count, 1)
        try store.deleteRecord(first)
        XCTAssertEqual(b.wearRecords.count, 0)
        XCTAssertEqual(try database.mainContext.fetch(FetchDescriptor<WearRecord>()).count, 0)
    }

    func testJournalRejectsFutureAndShoppingPiecesWithoutPartialSaves() throws {
        let owned = try garment("Owned"), shopping = try garment("Candidate", status: GarmentStatus.candidate)
        let store = JournalStore(context: database.mainContext, assets: assets)
        let now = Date(), tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        let count = try database.mainContext.fetch(FetchDescriptor<AssetRecord>()).count
        XCTAssertThrowsError(try store.saveRecord(name: "Future", date: tomorrow, note: "", composition: composition([owned]), now: now))
        XCTAssertThrowsError(try store.saveRecord(name: "Shopping", date: now, note: "", composition: composition([shopping]), now: now))
        XCTAssertEqual(try database.mainContext.fetch(FetchDescriptor<JournalEntry>()).count, 0)
        XCTAssertEqual(try database.mainContext.fetch(FetchDescriptor<WearRecord>()).count, 0)
        XCTAssertEqual(try database.mainContext.fetch(FetchDescriptor<AssetRecord>()).count, count)
    }

    func testFailedRecordedEditRetainsOriginalImageDateAndWears() throws {
        let a = try garment("A"), b = try garment("B")
        let store = JournalStore(context: database.mainContext, assets: assets)
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = try store.saveRecord(name: "Original", date: day, note: "", composition: composition([a]))
        let imageID = entry.renderedAsset?.id, wearID = entry.wearRecords.first?.id
        let changed = try composition([b])
        let readOnly = try open(readOnly: true)
        let restored = try XCTUnwrap(readOnly.mainContext.fetch(FetchDescriptor<JournalEntry>()).first)
        XCTAssertThrowsError(try JournalStore(context: readOnly.mainContext, assets: assets).saveRecord(name: "Changed", date: Date(), note: "", composition: changed, updating: restored))
        XCTAssertEqual(restored.name, "Original")
        XCTAssertEqual(restored.date, day)
        XCTAssertEqual(restored.renderedAsset?.id, imageID)
        XCTAssertEqual(restored.wearRecords.map(\.id), [wearID!])
        XCTAssertEqual(restored.garments.map(\.id), [a.id])
        XCTAssertFalse(readOnly.mainContext.hasChanges)
    }

    func testOffersPersistEditValidateAndSurviveAcquisition() throws {
        let item = try garment("Candidate", status: GarmentStatus.candidate)
        let store = ShoppingStore(context: database.mainContext, assets: assets)
        try store.saveOffer(for: item, retailer: "Shop A", website: "https://example.com/a", price: "120.50", currency: "eur")
        let first = try XCTUnwrap(store.offers(for: item).first)
        try store.saveOffer(for: item, retailer: "Shop B", website: "https://example.org/b", price: "110", currency: "EUR")
        try store.saveOffer(for: item, id: first.id, retailer: "Shop A", website: "https://example.com/a", price: "105.50", currency: "EUR")
        XCTAssertEqual(try store.offers(for: item).count, 2)
        XCTAssertEqual(try store.offers(for: item).first?.amount, Decimal(string: "105.50"))
        let bytes = item.shoppingOffersData
        XCTAssertThrowsError(try store.saveOffer(for: item, retailer: "Invalid", website: "https://example.com", price: "-2", currency: "EUR"))
        XCTAssertEqual(item.shoppingOffersData, bytes)
        let reopened = try open()
        let restored = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<Garment>()).first)
        XCTAssertEqual(try ShoppingStore(context: reopened.mainContext, assets: assets).offers(for: restored).count, 2)
        try store.addToWardrobe(item, price: "105.50", currency: "EUR", acquired: Date())
        XCTAssertEqual(item.shoppingOffersData, bytes)
        XCTAssertEqual(item.status, GarmentStatus.owned)
    }

    func testBrandPriceNotesAndBrandFilterPersist() throws {
        let item = try garment("A")
        var draft = BrandDraft(name: "Example")
        draft.sizingNotes = "M"
        draft.fabricNotes = "Cotton"
        draft.priceNotes = "EUR 50–100"
        try BrandStore(context: database.mainContext, assets: assets).save(draft)
        XCTAssertTrue(WardrobeFilter(brand: "example").matches(item))
        XCTAssertFalse(WardrobeFilter(brand: "other").matches(item))
        XCTAssertFalse(WardrobeFilter(brand: "").matches(item))
        XCTAssertTrue(WardrobeFilter(brand: "example", colors: []).matches(item))
        let reopened = try open()
        XCTAssertEqual(try reopened.mainContext.fetch(FetchDescriptor<Brand>()).first?.priceNotes, "EUR 50–100")
    }
}

extension FlowRevisionTests {
    func testPastLegacyEntriesBackfillOnlyOnce() throws {
        let item = try garment("A")
        let store = JournalStore(context: database.mainContext, assets: assets)
        let now = Date(), future = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        let canvas = try composition([item])
        let first = try store.save(name: "Earlier snapshot", date: now, note: "", composition: canvas)
        let second = try store.save(name: "Same day", date: now, note: "", composition: canvas)
        let planned = try store.save(name: "Legacy future snapshot", date: future, note: "", composition: canvas)
        try store.recordExistingEntries(now: now)
        try store.recordExistingEntries(now: now)
        XCTAssertTrue(first.wearingRecorded)
        XCTAssertTrue(second.wearingRecorded)
        XCTAssertFalse(planned.wearingRecorded)
        XCTAssertEqual(item.wearRecords.count, 1)
    }

    func testReadOnlyOfferSaveAndJournalDeleteRollBack() throws {
        let item = try garment("Candidate", status: GarmentStatus.candidate)
        try ShoppingStore(context: database.mainContext, assets: assets).saveOffer(for: item, retailer: "Shop", website: "https://example.com", price: "100", currency: "EUR")
        let owned = try garment("Owned")
        let entry = try JournalStore(context: database.mainContext, assets: assets).saveRecord(name: "Worn", date: Date(), note: "", composition: composition([owned]))
        let bytes = item.shoppingOffersData, wearID = entry.wearRecords.first?.id
        let readOnly = try open(readOnly: true)
        let candidate = try XCTUnwrap(readOnly.mainContext.fetch(FetchDescriptor<Garment>()).first { $0.id == item.id })
        XCTAssertThrowsError(try ShoppingStore(context: readOnly.mainContext, assets: assets).saveOffer(for: candidate, retailer: "Other", website: "https://example.org", price: "90", currency: "EUR"))
        XCTAssertEqual(candidate.shoppingOffersData, bytes)
        XCTAssertFalse(readOnly.mainContext.hasChanges)
        let savedEntry = try XCTUnwrap(readOnly.mainContext.fetch(FetchDescriptor<JournalEntry>()).first)
        XCTAssertThrowsError(try JournalStore(context: readOnly.mainContext, assets: assets).deleteRecord(savedEntry))
        XCTAssertEqual(savedEntry.wearRecords.map(\.id), [wearID!])
        XCTAssertEqual(try readOnly.mainContext.fetch(FetchDescriptor<JournalEntry>()).count, 1)
        XCTAssertFalse(readOnly.mainContext.hasChanges)
    }
}

@MainActor
extension FlowRevisionTests {
    func testNumericPricesAndReferencesDoNotRequireCurrency() throws {
        let item = try garment("Unlabelled price")
        var draft = GarmentDraft(item)
        draft.price = "120"; draft.costReference = "4"; draft.currency = ""
        try GarmentStore(context: database.mainContext, assets: assets).update(item, draft: draft)
        XCTAssertEqual(item.amount, 120)
        XCTAssertEqual(item.costReference, 4)
        XCTAssertEqual(item.currency, "")
        var purchase = PurchaseDraft(garment: item)
        purchase.years = "1"; purchase.frequency = "1"; purchase.seasonsPerYear = 1; purchase.unit = .season
        XCTAssertEqual(try purchase.costPerWear(), 120)
        XCTAssertEqual(MoneyText.format(120, currency: ""), "120")
        XCTAssertEqual(MoneyText.format(120, currency: "SEK"), "120 SEK")
        let file = directory.appending(path: "settings.json")
        var preferences = PreferencesDraft(); preferences.costReference = "4"
        try PreferencesStore(fileURL: file).save(preferences)
        XCTAssertEqual(try PreferencesStore(fileURL: file).load().currency, "")
        XCTAssertEqual(try PreferencesStore(fileURL: file).load().costReference, 4)
    }

    func testShareTextUsesFirstHTTPLinkAndPreservesProductParameters() throws {
        let product = "https://www.bestsecret.com/product.htm?code=40855905&colorCode=001327605&share=pdp&client-hint-is-boutique=false"
        let share = "🧶 Cashmere jumper\nCheck out this item! \(product)\nRegister here: https://www.bestsecret.com/acquisition/viral-product-share?product_id=40855905_001327605"
        XCTAssertEqual(BrandStore.websiteAddress(share), product)
        XCTAssertEqual(BrandStore.websiteURL(share)?.absoluteString, product)
        var draft = BrandDraft(name: "Shared website")
        draft.website = share
        let brand = try BrandStore(context: database.mainContext, assets: assets).save(draft)
        XCTAssertEqual(brand.website, product)
        let candidate = try garment("Share text", status: GarmentStatus.candidate)
        let legacy = ShoppingOffer(retailer: "Legacy quote", website: share, amount: nil, currency: "")
        candidate.shoppingOffersData = try JSONEncoder().encode([legacy])
        try database.mainContext.save()
        let store = ShoppingStore(context: database.mainContext, assets: assets)
        XCTAssertEqual(BrandStore.websiteURL(try XCTUnwrap(store.offers(for: candidate).first).website)?.absoluteString, product)
        try store.saveOffer(for: candidate, retailer: "", website: share, price: "90", currency: "")
        let reopened = try open()
        let restored = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<Garment>()).first { $0.id == candidate.id })
        let offers = try ShoppingStore(context: reopened.mainContext, assets: assets).offers(for: restored)
        XCTAssertEqual(offers.count, 2)
        XCTAssertEqual(offers[0].website, share)
        XCTAssertEqual(offers[1].website, product)
        XCTAssertEqual(offers[1].retailer, "www.bestsecret.com")
        XCTAssertEqual(offers[1].amount, 90)
    }

    func testShareLinkDetectionKeepsBareAddressesAndPlainNotes() {
        let address = "http://example.com/product?id=12&color=navy#details"
        XCTAssertEqual(BrandStore.websiteAddress("See \(address) then https://example.org/invite"), address)
        XCTAssertEqual(BrandStore.websiteAddress("help@example.com — https://example.org/product"), "https://example.org/product")
        XCTAssertEqual(BrandStore.websiteAddress("  www.example.com/item  "), "www.example.com/item")
        XCTAssertEqual(BrandStore.websiteAddress("  Ask about the new collection  "), "Ask about the new collection")
        XCTAssertEqual(BrandStore.websiteAddress(""), "")
        XCTAssertNil(BrandStore.websiteURL("file:///tmp/image.png"))
    }

    func testWebsiteNotesAndQuotesAcceptBareAddresses() throws {
        var draft = BrandDraft(name: "Local notes")
        draft.website = "www.example.com"
        let brand = try BrandStore(context: database.mainContext, assets: assets).save(draft)
        XCTAssertEqual(brand.website, "www.example.com")
        draft.website = "Ask about the new collection"
        try BrandStore(context: database.mainContext, assets: assets).save(draft, updating: brand)
        XCTAssertEqual(brand.website, draft.website)
        let candidate = try garment("Compare", status: GarmentStatus.candidate)
        try ShoppingStore(context: database.mainContext, assets: assets).saveOffer(for: candidate,
            retailer: "Shop", website: "www.example.com/item", price: "90", currency: "")
        let reopened = try open()
        let restored = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<Garment>()).first { $0.id == candidate.id })
        let offer = try XCTUnwrap(ShoppingStore(context: reopened.mainContext, assets: assets).offers(for: restored).first)
        XCTAssertEqual(offer.website, "www.example.com/item")
        XCTAssertEqual(offer.amount, 90)
        XCTAssertEqual(offer.currency, "")
    }

    func testCanvasPinchAcceptsOneFingerOutsideWithoutResizingOtherLayers() throws {
        let size = CGSize(width: 300, height: 400)
        let selected = CompositionLayer(assetID: UUID(), width: 0.4, height: 0.5, rotation: 30)
        let other = CompositionLayer(assetID: UUID(), x: 0.8, width: 0.2, height: 0.3)
        XCTAssertTrue(CanvasHitGeometry.acceptsPinch([CGPoint(x: 150, y: 200), CGPoint(x: 290, y: 200)], layer: selected, size: size))
        XCTAssertTrue(CanvasHitGeometry.acceptsPinch([CGPoint(x: 290, y: 200), CGPoint(x: 150, y: 200)], layer: selected, size: size))
        XCTAssertFalse(CanvasHitGeometry.acceptsPinch([CGPoint(x: 5, y: 5), CGPoint(x: 290, y: 390)], layer: selected, size: size))
        var composition = FlatlayComposition(layers: [selected, other])
        try composition.transform(selected.id, translationX: 0.03, translationY: 0, magnification: 1.4, rotation: 15)
        XCTAssertEqual(composition.layers[0].width / composition.layers[0].height, selected.width / selected.height, accuracy: 0.00001)
        XCTAssertEqual(composition.layers[1], other)
        let upright = CompositionLayer(assetID: UUID(), width: 0.4, height: 0.5)
        XCTAssertEqual(CanvasHitGeometry.handle(at: CGPoint(x: 210, y: 200), layer: upright, size: size), .right)
        XCTAssertNil(CanvasHitGeometry.handle(at: CGPoint(x: 185, y: 200), layer: upright, size: size))
    }
}
