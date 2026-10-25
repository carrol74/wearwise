import SwiftData
import SwiftUI

struct ShoppingView: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @Query(filter: #Predicate<Garment> { $0.status == "candidate" }, sort: \Garment.createdAt, order: .reverse) private var items: [Garment]
    @State private var adding = false
    @State private var search = ""
    private var visibleItems: [Garment] { items.filter { $0.matches(search: search) } }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    WearwiseEmptyState(title: "Considering something new?", systemImage: "bag",
                        description: "Save pieces, compare website prices, and assess a purchase.",
                        actionTitle: "Add shopping item", action: { adding = true })
                } else if visibleItems.isEmpty {
                    WearwiseEmptyState(title: "No matching shopping items", systemImage: "magnifyingglass",
                        actionTitle: "Clear search", action: { search = "" })
                } else {
                    ScrollView {
                        LazyVGrid(columns: typeSize.isAccessibilitySize ? [GridItem(.flexible(), alignment: .top)] : [GridItem(.adaptive(minimum: 150), spacing: 12, alignment: .top)], spacing: 12) {
                            ForEach(visibleItems) { item in
                                NavigationLink(value: item.id) { GarmentCard(garment: item) }.buttonStyle(WearwisePressStyle())
                            }
                        }.padding()
                    }
                }
            }
            .background(Color.wardrobeBackground)
            .navigationTitle("Shopping").wearwiseKeyboardDismissal()
            .searchable(text: $search, prompt: "Find a shopping item")
            .submitLabel(.done).onSubmit(of: .search) { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
            .navigationDestination(for: UUID.self) { GarmentDestination(id: $0, shopping: true) }
            .labelStyle(.iconOnly)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { adding = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add shopping item")
                        .accessibilityIdentifier("shopping.add")
                }
            }
            .sheet(isPresented: $adding) { ImportView(collection: .shopping) }
        }
    }
}

struct ShoppingDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppFeedback.self) private var feedback
    @Bindable var item: Garment
    @Environment(\.wearwiseCurrency) private var currency
    @State private var calculating = false
    @State private var editing = false
    @State private var draft: GarmentDraft
    @State private var discarding = false
    @State private var offers: [ShoppingOffer] = []
    @State private var addingOffer = false
    @State private var editingOffer: ShoppingOffer?
    @State private var transferring = false
    @State private var removing = false
    @State private var errorText: String?

    init(item: Garment) {
        self.item = item
        _draft = State(initialValue: GarmentDraft(item))
    }

    var body: some View {
        Group {
            if item.modelContext != nil && !item.isDeleted { details }
        }
    }

    private var details: some View {
        List {
            Section {
                GarmentImagePanel(garment: item, allowsReplacement: editing)
            }
            if !editing {
                Section {
                    Button("Add to wardrobe", systemImage: "tshirt") { transferring = true }
                        .accessibilityIdentifier("shopping.acquire")
                    Button("Purchase estimate", systemImage: "plus.forwardslash.minus") { calculating = true }
                        .accessibilityIdentifier("shopping.estimate")
                }.labelStyle(.titleAndIcon)
                Section("Websites and prices") {
                    ForEach(offers) { offer in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(offer.retailer).font(.headline)
                                Text(offer.amount.map { MoneyText.format($0, currency: currency) } ?? "Price not recorded")
                                let comparable = offers.filter { $0.currency == offer.currency && $0.amount != nil }
                                if let amount = offer.amount, comparable.count > 1, amount == comparable.compactMap(\.amount).min() {
                                    Text("Lowest price").font(.caption).foregroundStyle(Color.accentText)
                                }
                                if let url = BrandStore.websiteURL(offer.website) { Link("Open website", destination: url).font(.caption) }
                                else { Text(offer.website).font(.caption) }
                            }
                            Spacer()
                            HStack(spacing: 4) {
                                Button { editingOffer = offer } label: {
                                    Image(systemName: "pencil").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                                }.accessibilityLabel("Edit website: \(offer.retailer)")
                                Button(role: .destructive) {
                                    do { try ShoppingStore(context: context).deleteOffer(offer.id, from: item) }
                                    catch { errorText = error.localizedDescription }
                                } label: {
                                    Image(systemName: "trash").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                                }.accessibilityLabel("Delete website: \(offer.retailer)")
                            }.labelStyle(.iconOnly).buttonStyle(.borderless).controlSize(.large)
                        }.padding(.vertical, 5)
                    }
                    Button("Add website", systemImage: "plus") { addingOffer = true }
                        .labelStyle(.titleAndIcon).accessibilityIdentifier("shopping.add-website")
                }
            }
            GarmentEditFields(garment: item, draft: $draft, editing: editing)
        }
        .scrollDismissesKeyboard(.interactively).scrollContentBackground(.hidden)
            .background(Color.wardrobeBackground)
            .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline).wearwiseKeyboardDismissal()
        .navigationBarBackButtonHidden(editing)
        .labelStyle(.iconOnly)
            .toolbar {
                if editing {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", systemImage: "xmark") {
                            if draft == GarmentDraft(item) { editing = false } else { discarding = true }
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save", systemImage: "checkmark") {
                            do { draft.currency = currency; try GarmentStore(context: context).update(item, draft: draft); editing = false }
                            catch { errorText = error.localizedDescription }
                        }.disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } else {
                    ToolbarItem(placement: .primaryAction) {
                        HStack {
                            Button("Edit", systemImage: "pencil") { draft = GarmentDraft(item); editing = true }
                            Button("Remove shopping item", systemImage: "trash", role: .destructive) { removing = true }
                        }
                    }
                }
            }
        .task(id: item.shoppingOffersData) {
            do { offers = try ShoppingStore(context: context).offers(for: item) }
            catch { errorText = error.localizedDescription }
        }
        .sheet(isPresented: $addingOffer) { ShoppingOfferEditor(item: item) }
        .sheet(item: $editingOffer) { ShoppingOfferEditor(item: item, offer: $0) }
        .sheet(isPresented: $calculating) { PurchaseCalculatorView(garment: item) }
        .wearwiseDiscardConfirmation(isPresented: $discarding) { editing = false }
        .sheet(isPresented: $transferring) {
            AddToWardrobeView(item: item) {
                transferring = false
                dismiss()
            }
        }
        .wearwiseConfirmationToast("Remove this shopping item?", isPresented: $removing,
            message: "Saved outfits keep their images.") {
            do { try ShoppingStore(context: context).remove(item); dismiss() }
            catch GarmentStoreError.assetCleanupFailed(let detail) {
                dismiss()
                feedback.message = GarmentStoreError.assetCleanupFailed(detail).localizedDescription
            }
            catch { errorText = error.localizedDescription }
        }
        .wearwiseErrorToast("Could not update shopping item", message: $errorText)
    }
}

private struct AddToWardrobeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let item: Garment
    var onAdded: () -> Void
    @State private var price: String
    @Environment(\.wearwiseCurrency) private var currency
    @State private var date = Date()
    @State private var dateKnown = true
    @State private var errorText: String?

    init(item: Garment, onAdded: @escaping () -> Void) {
        self.item = item
        self.onAdded = onAdded
        _price = State(initialValue: item.amount?.formatted(.number) ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section { Text(item.name).font(.headline) }
                Section("Confirm your record") {
                    TextField("Paid price (leave empty if unknown)", text: $price).keyboardType(.decimalPad)
                    Toggle("Acquisition date known", isOn: $dateKnown)
                    if dateKnown { DatePicker("Acquired", selection: $date, displayedComponents: .date) }
                }
            }
            .scrollDismissesKeyboard(.interactively).scrollContentBackground(.hidden)
            .background(Color.wardrobeBackground)
            .navigationTitle("Add to Wardrobe")
            .navigationBarTitleDisplayMode(.inline).wearwiseKeyboardDismissal()
            .labelStyle(.iconOnly)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", systemImage: "plus") {
                        do {
                            try ShoppingStore(context: context).addToWardrobe(item, price: price, currency: currency, acquired: dateKnown ? date : nil, defaults: PreferencesStore().load())
                            onAdded()
                        } catch { errorText = error.localizedDescription }
                    }
                }
            }
            .wearwiseErrorToast("Could not add item", message: $errorText)
        }
    }
}


private struct ShoppingOfferEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let item: Garment
    let offer: ShoppingOffer?
    @State private var retailer: String
    @State private var website: String
    @State private var price: String
    @Environment(\.wearwiseCurrency) private var currency
    @State private var errorText: String?
    @State private var discarding = false

    init(item: Garment, offer: ShoppingOffer? = nil) {
        self.item = item
        self.offer = offer
        _retailer = State(initialValue: offer?.retailer ?? "")
        _website = State(initialValue: BrandStore.websiteAddress(offer?.website ?? ""))
        _price = State(initialValue: offer?.amount?.formatted(.number.precision(.fractionLength(0...38)).grouping(.never)) ?? "")
    }

    private var changed: Bool {
        retailer != (offer?.retailer ?? "") || website != BrandStore.websiteAddress(offer?.website ?? "")
            || price != (offer?.amount?.formatted(.number.precision(.fractionLength(0...38)).grouping(.never)) ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Website") {
                    TextField("Store name", text: $retailer).accessibilityIdentifier("offer.retailer")
                    TextField("Product URL", text: $website).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityIdentifier("offer.website")
                }
                Section {
                    TextField("Price (optional)", text: $price).keyboardType(.decimalPad).accessibilityIdentifier("offer.price")
                } header: { Text("Quoted price") } footer: { Text("Record the website's current price.") }
            }.scrollDismissesKeyboard(.interactively).scrollContentBackground(.hidden).background(Color.wardrobeBackground)
                .navigationTitle(offer == nil ? "Add website" : "Edit website").navigationBarTitleDisplayMode(.inline).wearwiseKeyboardDismissal()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { if changed { discarding = true } else { dismiss() } }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            do {
                                try ShoppingStore(context: context).saveOffer(for: item, id: offer?.id, retailer: retailer, website: website, price: price, currency: currency)
                                dismiss()
                            } catch { errorText = error.localizedDescription }
                        }.disabled(website.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .interactiveDismissDisabled(changed)
                .wearwiseDiscardConfirmation(isPresented: $discarding) { dismiss() }
                .wearwiseErrorToast("Could not save website", message: $errorText)
        }
    }
}
