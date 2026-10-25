import SwiftUI
import SwiftData

struct WardrobeView: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @Query(filter: #Predicate<Garment> { $0.status == "owned" }, sort: \Garment.createdAt, order: .reverse) private var garments: [Garment]
    @State private var showingImporter = false
    @State private var search = ""
    @State private var category = ""
    @State private var season = ""
    @State private var brand: String? = nil
    @State private var colors: Set<String> = []
    @State private var filtering = false
    @State private var settings = false
    @State private var character = false

    private var visibleGarments: [Garment] {
        garments.filter { WardrobeFilter(search: search, category: category, season: season, brand: brand, colors: colors).matches($0) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if garments.isEmpty {
                    WearwiseEmptyState(title: "Empty wardrobe", systemImage: "tshirt",
                        description: "Import your first garment image to start your wardrobe.",
                        actionTitle: "Import garment", action: { showingImporter = true })
                } else if visibleGarments.isEmpty {
                    WearwiseEmptyState(title: "No matching garments", systemImage: "magnifyingglass",
                        description: "Change your search or filters to find your clothes.",
                        actionTitle: "Clear search and filters", action: clearFilters)
                } else {
                    ScrollView {
                        LazyVGrid(columns: typeSize.isAccessibilitySize ? [GridItem(.flexible(), alignment: .top)] : [GridItem(.adaptive(minimum: 150), spacing: 12, alignment: .top)], spacing: 12) {
                            ForEach(visibleGarments) { garment in
                                NavigationLink(value: garment.id) {
                                    GarmentCard(garment: garment)
                                }
                                .buttonStyle(WearwisePressStyle())
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(Color.wardrobeBackground)
            .navigationTitle("Wardrobe").wearwiseKeyboardDismissal()
            .searchable(text: $search, prompt: "Name, brand, category, or color")
            .submitLabel(.done).onSubmit(of: .search) { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
            .navigationDestination(for: UUID.self) { GarmentDestination(id: $0) }
            .labelStyle(.iconOnly)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { character = true } label: { Image(systemName: "person.crop.circle") }
                        .accessibilityLabel("My character").accessibilityIdentifier("wardrobe.character")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { settings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings").accessibilityIdentifier("wardrobe.settings")
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { filtering = true } label: {
                        Label("Filters", systemImage: category.isEmpty && season.isEmpty && brand == nil && colors.isEmpty ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }
                    .accessibilityIdentifier("wardrobe.filters")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingImporter = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Import garment image")
                }
            }
            .sheet(isPresented: $showingImporter) {
                ImportView()
            }
            .sheet(isPresented: $filtering) {
                WardrobeFilterPanel(category: category, season: season, brand: brand, colors: colors, brands: OwnedBrandGroup.groups(from: garments)) { category, season, brand, colors in
                    self.category = category
                    self.season = season
                    self.brand = brand
                    self.colors = colors
                }
            }
            .sheet(isPresented: $settings) { PreferencesView() }
            .sheet(isPresented: $character) { CharacterView() }
        }
    }

    private func clearFilters() {
        search = ""
        category = ""
        season = ""
        brand = nil
        colors = []
    }
}

private struct WardrobeFilterPanel: View {
    @Environment(\.dismiss) private var dismiss
    @State var category: String
    @State var season: String
    @State var brand: String?
    @State var colors: Set<String>
    let brands: [OwnedBrandGroup]
    let apply: (String, String, String?, Set<String>) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Category", selection: $category) {
                        Text("All categories").tag("")
                        ForEach(GarmentCategory.groups) { group in
                            Section(group.title) {
                                ForEach(group.categories, id: \.self) { Text($0).tag($0) }
                            }
                        }
                    }
                    Picker("Brand", selection: $brand) {
                        Text("All brands").tag(Optional<String>.none)
                        ForEach(brands) { group in Text(group.name).tag(Optional(group.id)) }
                    }.accessibilityIdentifier("filter.brand")
                    Picker("Season", selection: $season) {
                        Text("All seasons").tag("")
                        ForEach(["spring", "summer", "autumn", "winter"], id: \.self) { Text($0.capitalized).tag($0) }
                    }
                }
                Section { GarmentColorPicker(selection: $colors) }
            }
            .scrollDismissesKeyboard(.interactively).scrollContentBackground(.hidden)
            .background(Color.wardrobeBackground)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .labelStyle(.iconOnly)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Apply", systemImage: "checkmark") { apply(category, season, brand, colors); dismiss() } }
                ToolbarItem(placement: .bottomBar) { Button("Clear filters") { category = ""; season = ""; brand = nil; colors = [] }.buttonStyle(.borderless) }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct GarmentCard: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let garment: Garment

    var body: some View {
        Group {
            if garment.modelContext != nil && !garment.isDeleted { card }
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 6) {
            GarmentImageView(record: garment.cutoutAsset ?? garment.originalAsset)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: WearwiseRadius.medium, style: .continuous))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(garment.name) image")
                .accessibilityIdentifier("garment.card.image.\(garment.id)")

            Text(garment.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(typeSize.isAccessibilitySize ? nil : 2)

            Text(garment.category.isEmpty ? "Unknown category" : garment.category)
                .font(.caption)
                .foregroundStyle(.secondary)
            GarmentColorTags(colors: garment.colorTags)

        }
        .padding(.bottom, 8)
        .contentShape(Rectangle())
    }
}
