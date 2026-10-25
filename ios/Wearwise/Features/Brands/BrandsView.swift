import SwiftData
import SwiftUI

struct BrandsView: View {
    @Query(sort: \Garment.name) private var garments: [Garment]
    @Query(sort: \Brand.name) private var brands: [Brand]
    @State private var search = ""
    @State private var adding = false

    private var names: [String] {
        var values: [String: String] = [:]
        for group in OwnedBrandGroup.groups(from: garments) where !group.id.isEmpty { values[group.id] = group.name }
        for brand in brands { values[brand.normalizedName] = brand.name }
        return values.values.filter { search.isEmpty || $0.localizedStandardContains(search) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            Group {
                if names.isEmpty {
                    WearwiseEmptyState(title: search.isEmpty ? "Your brand notes" : "No matching brands", systemImage: "bookmark",
                        description: "Keep your usual sizes, materials, fit, and price ranges together.",
                        actionTitle: "Add brand", action: { adding = true })
                } else {
                    List(names, id: \.self) { name in
                        NavigationLink(value: name) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(name).font(.headline).foregroundStyle(Color.charcoalText)
                                if let brand = brands.first(where: { $0.normalizedName == Brand.key(name) }) {
                                    let summary = [brand.sizingNotes, brand.fabricNotes, brand.priceNotes].filter { !$0.isEmpty }.joined(separator: " · ")
                                    if !summary.isEmpty { Text(summary).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                                }
                            }.padding(.vertical, 8)
                        }.accessibilityIdentifier("brands.profile.\(Brand.key(name))")
                    }.scrollDismissesKeyboard(.interactively).scrollContentBackground(.hidden)
                }
            }.background(Color.wardrobeBackground)
                .navigationTitle("Brands").wearwiseKeyboardDismissal()
                .searchable(text: $search)
            .submitLabel(.done).onSubmit(of: .search) { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                .navigationDestination(for: String.self) { BrandProfileView(name: $0) }
                .navigationDestination(for: UUID.self) { GarmentDestination(id: $0) }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button { adding = true } label: { Image(systemName: "plus") }
                            .accessibilityLabel("Add brand").accessibilityIdentifier("brands.add")
                    }
                }
                .sheet(isPresented: $adding) { BrandEditView() }
        }
    }
}

private struct BrandProfileView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppFeedback.self) private var feedback
    @Query private var brands: [Brand]
    @Query private var garments: [Garment]
    @State var name: String
    @State private var editing = false
    @State private var deleting = false
    @State private var errorText: String?
    private var brand: Brand? { brands.first { $0.normalizedName == Brand.key(name) } }
    private var owned: [Garment] { garments.filter { $0.status == GarmentStatus.owned && Brand.key($0.brand) == Brand.key(name) } }

    var body: some View {
        Group {
          if editing {
            BrandEditView(brand: brand, name: name, embedded: true, onCancel: { editing = false }) {
                name = $0.name; editing = false
            }
          } else {
          List {
            Section("Your usual choices") {
                LabeledContent("Size", value: brand?.sizingNotes.isEmpty == false ? brand!.sizingNotes : "Not added")
                LabeledContent("Materials", value: brand?.fabricNotes.isEmpty == false ? brand!.fabricNotes : "Not added")
                LabeledContent("Price range", value: brand?.priceNotes.isEmpty == false ? brand!.priceNotes : "Not added")
                LabeledContent("Fit", value: brand?.fitNotes.isEmpty == false ? brand!.fitNotes : "Not added")
            }
            if let brand, !brand.notes.isEmpty { Section("Notes") { Text(brand.notes) } }
            if let website = brand?.website, !website.isEmpty, let url = BrandStore.websiteURL(website) {
                Section { Link("Open website", destination: url) }
            } else if let website = brand?.website, !website.isEmpty {
                Section("Website") { Text(website) }
            }
            if let photos = brand?.inspirations, !photos.isEmpty {
                Section {
                    DisclosureGroup("Inspirations (\(photos.count))") {
                        BrandInspirationGrid(photos: photos.map { BrandInspirationPhoto(asset: $0) })
                    }
                }
            }
            if !owned.isEmpty {
                Section {
                    DisclosureGroup("Owned pieces (\(owned.count))") {
                        ForEach(owned) { garment in
                            NavigationLink(value: garment.id) {
                                HStack {
                                    GarmentImageView(record: garment.cutoutAsset ?? garment.originalAsset).frame(width: 42, height: 50)
                                    Text(garment.name)
                                }
                            }
                        }
                    }
                }
            }
          }.scrollDismissesKeyboard(.interactively).scrollContentBackground(.hidden).background(Color.wardrobeBackground)
          }
        }
            .navigationTitle(name).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if !editing { Button("Edit", systemImage: "pencil") { editing = true }.labelStyle(.iconOnly) }
                }
                ToolbarItem(placement: .primaryAction) {
                    if brand != nil && !editing {
                        Button("Delete brand", systemImage: "trash", role: .destructive) { deleting = true }
                            .labelStyle(.iconOnly).accessibilityIdentifier("brand.delete")
                    }
                }
            }
            .wearwiseConfirmationToast("Delete this brand's saved notes?", isPresented: $deleting,
                message: "Your garments keep their brand names, images, and history.") {
                guard let brand else { return }
                do {
                    if let message = try BrandStore(context: context).delete(brand) { feedback.message = message }
                    dismiss()
                } catch { errorText = error.localizedDescription }
            }
            .wearwiseErrorToast("Could not delete brand", message: $errorText)
    }
}

private struct BrandEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let brand: Brand?
    var onSaved: ((Brand) -> Void)?
    var embedded: Bool
    var onCancel: (() -> Void)?
    private let original: BrandDraft
    @State private var draft: BrandDraft
    @State private var choosingPhoto = false
    @State private var photos: [BrandInspirationPhoto]
    @State private var inspirationsExpanded = true
    @Environment(AppFeedback.self) private var feedback
    @State private var errorText: String?
    @State private var discarding = false

    init(brand: Brand? = nil, name: String = "", embedded: Bool = false, onCancel: (() -> Void)? = nil, onSaved: ((Brand) -> Void)? = nil) {
        self.embedded = embedded
        self.onCancel = onCancel
        self.onSaved = onSaved
        self.brand = brand
        let draft = BrandDraft(brand, name: name)
        original = draft
        _draft = State(initialValue: draft)
        _photos = State(initialValue: (brand?.inspirations ?? []).map { BrandInspirationPhoto(asset: $0) })
    }

    private var changed: Bool { draft != original || photos.map(\.id) != (brand?.inspirations ?? []).map(\.id) }

    private func close() { if embedded { onCancel?() } else { dismiss() } }

    var body: some View {
        Group {
            if embedded { editor }
            else { NavigationStack { editor } }
        }
    }

    private var editor: some View {
            Form {
                Section("Brand") {
                    TextField("Name", text: $draft.name).accessibilityIdentifier("brand.name")
                    TextField("Website (optional)", text: $draft.website).keyboardType(.URL)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityIdentifier("brand.website")
                }
                Section("Wear notes") {
                    BrandNoteField(title: "Fit", text: $draft.fitNotes, identifier: "brand.fit")
                    BrandNoteField(title: "Sizing", text: $draft.sizingNotes, identifier: "brand.sizing")
                    BrandNoteField(title: "Fabric", text: $draft.fabricNotes, identifier: "brand.fabric")
                    BrandNoteField(title: "Price range", text: $draft.priceNotes, identifier: "brand.price")
                    BrandNoteField(title: "Notes", text: $draft.notes, identifier: "brand.notes")
                }
                Section {
                    DisclosureGroup("Inspirations (\(photos.count))", isExpanded: $inspirationsExpanded) {
                        BrandInspirationGrid(photos: photos, remove: { id in photos.removeAll { $0.id == id } }, add: { choosingPhoto = true })
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively).scrollContentBackground(.hidden)
          .background(Color.wardrobeBackground)
          .navigationTitle(brand == nil ? "Add brand" : "Edit brand")
            .navigationBarTitleDisplayMode(.inline).wearwiseKeyboardDismissal()
            .interactiveDismissDisabled(changed)
            .navigationBarBackButtonHidden(embedded)
            .labelStyle(.iconOnly)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", systemImage: "xmark") { if changed { discarding = true } else { close() } } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") {
                        do {
                            let removed = Set((brand?.inspirations ?? []).map(\.id)).subtracting(photos.map(\.id))
                            let saved = try BrandStore(context: context).save(draft, updating: brand, inspirations: photos.compactMap(\.data), removing: removed)
                            onSaved?(saved)
                            if !embedded { dismiss() }
                        } catch BrandError.assetCleanupFailed(let detail) {
                            if let brand { onSaved?(brand) }
                            if !embedded { dismiss() }
                            feedback.message = "The brand was saved. Some unused inspiration files could not be removed: \(detail)"
                        } catch { errorText = error.localizedDescription }
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationDestination(isPresented: $choosingPhoto) {
                PhotoLibraryView { data in
                    choosingPhoto = false
                    do {
                        photos.append(BrandInspirationPhoto(data: try ImageImportService.normalizedPNG(from: data)))
                    } catch { errorText = error.localizedDescription }
                }
            }
            .wearwiseDiscardConfirmation(isPresented: $discarding) { close() }
            .wearwiseErrorToast("Could not save brand", message: $errorText)
    }
}


private struct BrandInspirationPhoto: Identifiable {
    let id: UUID
    let asset: AssetRecord?
    let data: Data?

    init(asset: AssetRecord) { id = asset.id; self.asset = asset; data = nil }
    init(data: Data) { id = UUID(); asset = nil; self.data = data }
}

private struct BrandInspirationGrid: View {
    let photos: [BrandInspirationPhoto]
    var remove: ((UUID) -> Void)?
    var add: (() -> Void)?

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
            ForEach(photos) { photo in
                ZStack {
                    Color.cutoutSurface
                    if let asset = photo.asset { GarmentImageView(record: asset) }
                    else if let data = photo.data, let image = UIImage(data: data) {
                        Image(uiImage: image).resizable().scaledToFit()
                    }
                }
                .aspectRatio(1, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityElement(children: .ignore).accessibilityAddTraits(.isImage)
                .accessibilityLabel("Inspiration image").accessibilityIdentifier("brand.inspiration")
                .overlay(alignment: .topTrailing) {
                    if let remove {
                        Button { remove(photo.id) } label: {
                            Image(systemName: "xmark").font(.caption.weight(.semibold))
                                .frame(width: 28, height: 28).background(Color.paperSurface, in: Circle())
                                .frame(width: 44, height: 44).contentShape(Rectangle())
                        }.buttonStyle(.borderless)
                            .accessibilityLabel("Remove inspiration image").accessibilityIdentifier("brand.inspiration.remove.\(photo.id)")
                    }
                }
            }
            if let add {
                Button(action: add) {
                    Image(systemName: "plus").font(.title2).frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit).background(Color.paperSurface, in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                }.buttonStyle(.borderless)
                    .accessibilityLabel("Add inspiration image").accessibilityIdentifier("brand.inspiration.add")
            }
        }.padding(.vertical, 8)
    }
}
