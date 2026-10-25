import SwiftData
import SwiftUI
import Observation

@MainActor @Observable
final class AppFeedback {
    var message: String?
}

@main
struct WearwiseApp: App {
    @State private var defaults = WardrobeDefaults()
    @State private var destination = "Wardrobe"
    @State private var feedback = AppFeedback()
    var body: some Scene {
        WindowGroup {
            TabView(selection: $destination) {
                WardrobeView().tabItem { Image(systemName: destination == "Wardrobe" ? "tshirt.fill" : "tshirt").environment(\.symbolVariants, .none).accessibilityLabel("Wardrobe") }.tag("Wardrobe")
                ShoppingView().tabItem { Image(systemName: destination == "Shopping" ? "bag.fill" : "bag").environment(\.symbolVariants, .none).accessibilityLabel("Shopping") }.tag("Shopping")
                JournalView().tabItem { Image(systemName: destination == "Journal" ? "book.closed.fill" : "book.closed").environment(\.symbolVariants, .none).accessibilityLabel("Journal") }.tag("Journal")
                BrandsView().tabItem { Image(systemName: destination == "Brands" ? "bookmark.fill" : "bookmark").environment(\.symbolVariants, .none).accessibilityLabel("Brands") }.tag("Brands")
            }
            .tint(.accentText)
            .environment(feedback)
            .environment(\.wearwiseCurrency, defaults.currency)
            .environment(\.wearwiseDefaults, defaults)
            .onReceive(NotificationCenter.default.publisher(for: .wearwiseDefaultsChanged)) { _ in
                do { defaults = try PreferencesStore().load() }
                catch { feedback.message = error.localizedDescription }
            }
            .task {
                do { defaults = try PreferencesStore().load(); try TemporaryOutfitExports.removeAbandoned() }
                catch { feedback.message = "Could not remove temporary share images from an earlier session: \(error.localizedDescription)" }
            }
            .wearwiseErrorToast("Could not complete the operation", message: $feedback.message)
        }
        .modelContainer(for: [Garment.self, AssetRecord.self, Outfit.self, JournalEntry.self, WearRecord.self, Brand.self])
    }
}
