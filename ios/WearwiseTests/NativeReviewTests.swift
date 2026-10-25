import Photos
import SwiftData
import SwiftUI
import UIKit
import XCTest
import WearwiseCore
@testable import Wearwise

@MainActor
final class NativeReviewTests: XCTestCase {
    func testPrepareShoppingShareTextForPaste() throws {
        let database = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self,
            JournalEntry.self, WearRecord.self, Brand.self)
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "black-tshirt", withExtension: "jpg"))
        let image = try AssetStore.shared.savePNG(ImageImportService.normalizedPNG(from: Data(contentsOf: fixture)), id: UUID())
        let product = "https://www.bestsecret.com/product.htm?code=40855905&colorCode=001327605&share=pdp"
        let share = "Cashmere jumper. Check out this item! \(product) Register here: https://www.bestsecret.com/acquisition/viral-product-share?product_id=40855905_001327605"
        let item = Garment(name: "Shared link review", category: "T-shirt", status: GarmentStatus.candidate)
        item.originalAsset = image
        item.shoppingOffersData = try JSONEncoder().encode([ShoppingOffer(retailer: "Saved share", website: share, amount: nil, currency: "")])
        database.mainContext.insert(image)
        database.mainContext.insert(item)
        try database.mainContext.save()
        UIPasteboard.general.string = share
    }

    func testPrepareRealImageForPasteImport() throws {
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "black-tshirt", withExtension: "jpg"))
        let image = try XCTUnwrap(UIImage(data: Data(contentsOf: fixture)))
        UIPasteboard.general.image = image
        XCTAssertNotNil(UIPasteboard.general.image)
    }

    func testVerifyPhotoGridTapTargetsMatchSavedImages() async throws {
        let database = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self,
            JournalEntry.self, WearRecord.self, Brand.self)
        let reviews = try database.mainContext.fetch(FetchDescriptor<Brand>())
            .filter { $0.name.hasPrefix("Photo grid tap ") }.sorted { $0.updatedAt > $1.updatedAt }
        guard let latest = reviews.first else {
            throw XCTSkip("Run NavigationTests.testPhotoGridCornerTapsSaveTheVisiblePhotos first.")
        }
        let batch = try XCTUnwrap(latest.name.split(separator: " ").dropFirst(3).first)
        let current = reviews.filter { $0.name.hasPrefix("Photo grid tap \(batch) ") }
        XCTAssertEqual(current.count, 5)
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let photos = PHAsset.fetchAssets(with: .image, options: options)
        XCTAssertGreaterThanOrEqual(photos.count, 5)
        for review in current {
            let index = try XCTUnwrap(Int(review.name.split(separator: " ").last!))
            let asset = photos.object(at: index)
            let request = PHImageRequestOptions()
            request.deliveryMode = .highQualityFormat
            request.isNetworkAccessAllowed = true
            let source: Data = try await withCheckedThrowingContinuation { continuation in
                PHImageManager.default().requestImageDataAndOrientation(for: asset, options: request) { data, _, _, info in
                    if let data { continuation.resume(returning: data) }
                    else { continuation.resume(throwing: (info?[PHImageErrorKey] as? Error) ?? ImageImportError.undecodable) }
                }
            }
            let draftImage = try ImageImportService.normalizedPNG(from: source)
            let expected = try ImageImportService.normalizedPNG(from: draftImage)
            let record = try XCTUnwrap(review.inspirationAsset)
            let saved = try AssetStore.shared.loadData(for: record)
            if saved != expected {
                for (name, data) in [("Expected photo \(index + 1)", expected), ("Selected photo \(index + 1)", saved)] {
                    let attachment = XCTAttachment(image: try XCTUnwrap(UIImage(data: data)))
                    attachment.name = name
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
            }
            XCTAssertTrue(saved == expected, "Tap inside Photo \(index + 1) must return that exact photo's bytes.")
        }
    }

    func testPhotoLibraryManagementMethodIsLoaded() {
        let selector = NSSelectorFromString("presentLimitedLibraryPickerFromViewController:completionHandler:")
        XCTAssertTrue(PHPhotoLibrary.shared().responds(to: selector),
            "The app must load PhotosUI.framework to register the limited-library picker method.")
    }

    func testPrepareDeletionRegressionItems() throws {
        let database = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self,
            JournalEntry.self, WearRecord.self, Brand.self)
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "black-tshirt", withExtension: "jpg"))
        let png = try ImageImportService.normalizedPNG(from: Data(contentsOf: fixture))
        let store = GarmentStore(context: database.mainContext)
        let brand = try BrandStore(context: database.mainContext).save(BrandDraft(name: "Deletion review brand"))
        for (name, status) in [("Delete unique images", GarmentStatus.owned),
            ("Remove unique shopping images", GarmentStatus.candidate)] {
            let item = Garment(name: name, category: "T-shirt", brand: brand.name, status: status)
            item.brandRecord = brand
            try store.saveImages(original: png, cutout: png, on: item)
            XCTAssertNotEqual(item.originalAsset?.id, item.cutoutAsset?.id)
        }
    }

    func testDarkPaletteUsesBlackAndNeutralSurfaces() throws {
        let dark = UITraitCollection(userInterfaceStyle: .dark)
        for (color, expected) in [(Color.wardrobeBackground, CGFloat(0)),
            (Color.paperSurface, CGFloat(20) / 255), (Color.imageMount, CGFloat(20) / 255),
            (Color.cutoutSurface, CGFloat(1))] {
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            XCTAssertTrue(UIColor(color).resolvedColor(with: dark).getRed(&red, green: &green, blue: &blue, alpha: &alpha))
            XCTAssertEqual(red, expected, accuracy: 0.001)
            XCTAssertEqual(green, expected, accuracy: 0.001)
            XCTAssertEqual(blue, expected, accuracy: 0.001)
            XCTAssertEqual(alpha, 1)
        }
    }

    func testPrepareGridAlignmentGarments() throws {
        let database = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self,
            JournalEntry.self, WearRecord.self, Brand.self)
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "black-tshirt", withExtension: "jpg"))
        let image = try AssetStore.shared.savePNG(ImageImportService.normalizedPNG(from: Data(contentsOf: fixture)), id: UUID())
        database.mainContext.insert(image)
        let short = Garment(name: "Grid review coat", category: "Coat", colorTags: ["black"])
        let long = Garment(name: "Grid review everyday shoulder bag", category: "Bag", colorTags: GarmentColorOption.all.map(\.id))
        short.originalAsset = image; long.originalAsset = image
        database.mainContext.insert(short); database.mainContext.insert(long)
        try database.mainContext.save()
    }

    func testPrepareRealGarmentForInlineInterfaceReview() throws {
        let database = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self,
            JournalEntry.self, WearRecord.self, Brand.self)
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "black-tshirt", withExtension: "jpg"))
        let image = try AssetStore.shared.savePNG(ImageImportService.normalizedPNG(from: Data(contentsOf: fixture)), id: UUID())
        let item = Garment(name: "Inline review tee", category: "T-shirt", colorTags: ["black"], brand: "Review brand")
        item.originalAsset = image
        database.mainContext.insert(image)
        database.mainContext.insert(item)
        let candidate = Garment(name: "Inline shopping review", category: "T-shirt", brand: "Review brand", status: GarmentStatus.candidate)
        candidate.originalAsset = image
        database.mainContext.insert(candidate)
        try database.mainContext.save()
        XCTAssertEqual(try AssetStore.shared.loadData(for: image), try ImageImportService.normalizedPNG(from: Data(contentsOf: fixture)))
    }

    func testPrepareRealJournalForToastReview() throws {
        let database = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self,
            JournalEntry.self, WearRecord.self, Brand.self)
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "black-tshirt", withExtension: "jpg"))
        let image = try AssetStore.shared.savePNG(ImageImportService.normalizedPNG(from: Data(contentsOf: fixture)), id: UUID())
        let item = Garment(name: "Toast journal tee", category: "T-shirt")
        item.originalAsset = image
        database.mainContext.insert(image); database.mainContext.insert(item)
        try database.mainContext.save()
        let outfits = OutfitStore(context: database.mainContext)
        var composition = FlatlayComposition()
        composition.layers = [try outfits.layer(for: item, in: composition)]
        try outfits.save(name: "Toast review outfit", composition: composition)
        try JournalStore(context: database.mainContext).saveRecord(name: "Toast review diary", date: Date(), note: "", composition: composition)
    }

    func testPrepareSimplifiedGarmentDetails() throws {
        let database = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self,
            JournalEntry.self, WearRecord.self, Brand.self)
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "black-tshirt", withExtension: "jpg"))
        let image = try AssetStore.shared.savePNG(ImageImportService.normalizedPNG(from: Data(contentsOf: fixture)), id: UUID())
        let garment = Garment(name: "Details review tee", category: "T-shirt")
        garment.originalAsset = image
        garment.acquisitionDate = Calendar.current.date(byAdding: .month, value: -15, to: Date())
        garment.acquisitionPrecision = "month"
        garment.firstUseDate = Calendar.current.date(byAdding: .month, value: -12, to: Date())
        garment.firstUsePrecision = "exact"
        garment.costReference = 99; garment.durationReferenceYears = 3
        database.mainContext.insert(image); database.mainContext.insert(garment)
        try database.mainContext.save()
    }

    func testPopulatedNativeReviewAttachments() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try! FileManager.default.removeItem(at: directory) }
        let container = try ModelContainer(for: Garment.self, AssetRecord.self, Outfit.self,
            JournalEntry.self, WearRecord.self, Brand.self,
            configurations: ModelConfiguration(url: directory.appending(path: "review.store")))
        let context = container.mainContext
        let assets = AssetStore.shared
        var writtenFiles: [URL] = []
        defer { for file in writtenFiles { if FileManager.default.fileExists(atPath: file.path) { try! FileManager.default.removeItem(at: file) } } }
        let photoURL = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "black-tshirt", withExtension: "jpg"))
        let photo = try assets.saveJPEG(Data(contentsOf: photoURL), id: UUID())
        writtenFiles.append(assets.url(for: photo))
        context.insert(photo)
        let owned = Garment(name: "Black T-shirt", category: "T-shirt", colorTags: ["black"],
            brand: "Test brand", amount: 120, currency: "SEK")
        owned.originalAsset = photo
        owned.seasons = ["spring", "summer"]
        owned.openingWearCount = 12
        owned.openingWearIsEstimate = true
        owned.costReference = 5
        owned.durationReferenceYears = 2
        owned.acquisitionDate = Calendar.current.date(byAdding: .year, value: -3, to: Date())
        owned.firstUseDate = owned.acquisitionDate
        owned.firstUsePrecision = "month"
        let candidate = Garment(name: "Shopping T-shirt", category: "T-shirt", status: GarmentStatus.candidate,
            amount: 1490, currency: "SEK")
        candidate.originalAsset = photo
        context.insert(owned)
        context.insert(candidate)
        try context.save()
        let outfits = OutfitStore(context: context, assets: assets)
        var composition = FlatlayComposition()
        composition.layers = [try outfits.layer(for: owned, in: composition), try outfits.layer(for: candidate, in: composition)]
        try composition.move(composition.layers[0].id, x: 0.3, y: 0.35)
        try composition.move(composition.layers[1].id, x: 0.7, y: 0.6)
        let sticker = try CharacterStickerStore(context: context, assets: assets).create(CharacterAppearance())
        writtenFiles.append(assets.url(for: sticker))
        composition.layers.append(CompositionLayer(assetID: sticker.id, garmentID: nil, x: 0.8, y: 0.8,
            width: 0.2, height: 0.25))
        let outfit = try outfits.save(name: "T-shirt composition", composition: composition)
        let journal = JournalStore(context: context, assets: assets)
        let journalComposition = try journal.recordComposition([owned])
        let entry = try journal.saveRecord(name: outfit.name,
            date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, note: "",
            composition: journalComposition)
        writtenFiles.append(assets.url(for: try XCTUnwrap(entry.renderedAsset)))
        let wornEntry = try journal.saveRecord(name: outfit.name, date: Date(), note: "", composition: journalComposition)
        writtenFiles.append(assets.url(for: try XCTUnwrap(wornEntry.renderedAsset)))
        _ = try BrandStore(context: context, assets: assets).save(BrandDraft(name: "Test brand"))
        let feedback = AppFeedback()
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = try XCTUnwrap(scenes.first)
        let previousKey = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        defer { window.isHidden = true; window.rootViewController = nil; previousKey?.makeKey() }
        let screens: [(String, AnyView)] = [
            ("Wardrobe", AnyView(WardrobeView())),
            ("Garment", AnyView(NavigationStack { GarmentDetailView(garment: owned) })),
            ("Edit", AnyView(NavigationStack { GarmentDetailView(garment: owned, initiallyEditing: true) })),
            ("Shopping", AnyView(ShoppingView())),
            ("Shopping details", AnyView(NavigationStack { ShoppingDetailView(item: candidate) })),
            ("Purchase", AnyView(PurchaseCalculatorView(garment: candidate))),
            ("Journal", AnyView(JournalView())),
            ("Journal editor", AnyView(JournalRecordEditor(entry: entry))),
            ("Flatlay", AnyView(FlatlayEditorView(outfit: outfit))),
            ("Brands", AnyView(BrandsView())),
            ("Character", AnyView(CharacterView())),
            ("Preferences", AnyView(PreferencesView())),
            ("Import choices", AnyView(ImportView()))
        ]
        let variants: [(String, CGSize, UIUserInterfaceStyle, DynamicTypeSize)] = [
            ("Light", CGSize(width: 375, height: 812), .light, .large),
            ("Compact dark", CGSize(width: 320, height: 568), .dark, .large),
            ("Large text", CGSize(width: 375, height: 812), .light, .accessibility3)
        ]
        for (variant, size, style, typeSize) in variants {
            for (name, view) in screens {
                let host = UIHostingController(rootView: view.modelContainer(container).environment(feedback).tint(.accentText)
                    .environment(\.dynamicTypeSize, typeSize))
                window.rootViewController = host
                window.frame = CGRect(origin: .zero, size: size)
                window.overrideUserInterfaceStyle = style
                window.makeKeyAndVisible()
                host.view.frame = window.bounds
                host.view.setNeedsLayout()
                host.view.layoutIfNeeded()
                try await Task.sleep(for: .milliseconds(180))
                host.view.layoutIfNeeded()
                let renderer = UIGraphicsImageRenderer(size: size)
                let image = renderer.image { _ in
                    XCTAssertTrue(host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true))
                }
                let attachment = XCTAttachment(image: image)
                attachment.name = "\(variant) - \(name)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
        XCTAssertEqual(try context.fetch(FetchDescriptor<Garment>()).count, 2)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Outfit>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<JournalEntry>()).count, 2)
        XCTAssertEqual(try context.fetch(FetchDescriptor<WearRecord>()).count, 2)
        XCTAssertTrue(wornEntry.wearingRecorded)
        XCTAssertTrue(entry.wearingRecorded)
        XCTAssertEqual(owned.status, GarmentStatus.owned)
        XCTAssertEqual(candidate.status, GarmentStatus.candidate)
    }
}
