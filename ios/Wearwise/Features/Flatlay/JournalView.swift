import Observation
import SwiftData
import SwiftUI
import WearwiseCore

struct JournalView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]
    @Query(sort: \Outfit.updatedAt, order: .reverse) private var outfits: [Outfit]
    @State private var section = "Diary"
    @State private var creating = false
    @State private var previewOutfit: Outfit?
    @State private var previewEntry: JournalEntry?
    @State private var deletingOutfit: Outfit?
    @State private var deletingEntry: JournalEntry?
    @State private var errorText: String?
    @State private var share = SavedLookShare()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Journal collection", selection: $section) {
                    Text("Journal").tag("Diary")
                    Text("Outfits").tag("Saved outfits")
                }.pickerStyle(.segmented).padding()
                if section == "Diary" { diary } else { savedOutfits }
            }
            .background(Color.wardrobeBackground)
            .navigationTitle(section == "Diary" ? "Journal" : "Outfits")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { creating = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel(section == "Diary" ? "Create diary entry" : "Create outfit")
                        .accessibilityIdentifier("journal.create")
                }
            }
            .sheet(isPresented: $creating) {
                if section == "Diary" { JournalRecordEditor() }
                else { FlatlayEditorView() }
            }
            .sheet(item: $previewOutfit) { OutfitPreview(outfit: $0) }
            .sheet(item: $previewEntry) { JournalEntryPreview(entry: $0) }
            .wearwiseConfirmationToast("Delete this saved outfit?", isPresented: .init(get: { deletingOutfit != nil }, set: { if !$0 { deletingOutfit = nil } }),
                message: "Journal entries keep their saved compositions.") {
                if let outfit = deletingOutfit { perform { try OutfitStore(context: context).delete(outfit) } }
                deletingOutfit = nil
            }
            .wearwiseConfirmationToast("Delete this journal entry?", isPresented: .init(get: { deletingEntry != nil }, set: { if !$0 { deletingEntry = nil } }),
                message: "Your other journal entries stay unchanged.") {
                if let entry = deletingEntry { perform { try JournalStore(context: context).deleteRecord(entry) } }
                deletingEntry = nil
            }
            .savedLookSharing(share)
            .task { perform { try JournalStore(context: context).recordExistingEntries() } }
            .wearwiseErrorToast("Could not complete this action", message: $errorText)
        }
    }

    @ViewBuilder private var diary: some View {
        if entries.isEmpty {
            WearwiseEmptyState(title: "What did you wear?", systemImage: "book.closed",
                description: "Record the pieces or outfit you wore.",
                actionTitle: "Create diary entry", action: { creating = true })
        } else {
            ScrollView {
              LazyVStack(spacing: 0) {
               ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(entry.date.formatted(date: .abbreviated, time: .omitted)).font(.headline)
                        }
                        Spacer()
                        Menu {
                            Button("Share image", systemImage: "square.and.arrow.up") { share.open(entry: entry, context: context) }
                            Button("Delete entry", systemImage: "trash", role: .destructive) { deletingEntry = entry }
                        } label: {
                            Label("Diary actions: \(entry.name)", systemImage: "ellipsis")
                                .labelStyle(.iconOnly).frame(width: 44, height: 44).contentShape(Rectangle())
                        }.buttonStyle(.borderless).frame(width: 44, height: 44)
                    }
                    Group {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(entry.name).font(.subheadline.weight(.semibold))
                            ScrollView(.horizontal) {
                                HStack(spacing: 10) {
                                    ForEach(entry.garments.sorted { $0.name < $1.name }) { garment in
                                        GarmentImageView(record: garment.cutoutAsset ?? garment.originalAsset)
                                            .frame(width: 66, height: 78).padding(6)
                                            .background(Color.imageMount, in: RoundedRectangle(cornerRadius: 12))
                                    }
                                    if entry.garments.isEmpty, let image = entry.renderedAsset {
                                        GarmentImageView(record: image).frame(width: 100, height: 100)
                                    }
                                }
                            }.scrollIndicators(.hidden)
                            if !entry.note.isEmpty { Text(entry.note).font(.subheadline).foregroundStyle(.secondary).lineLimit(3) }
                        }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                    }.foregroundStyle(Color.charcoalText)
                        .simultaneousGesture(TapGesture().onEnded { previewEntry = entry })
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel("View diary entry: \(entry.name)")
                        .accessibilityAction { previewEntry = entry }
                }.padding(.vertical, 18)
                    .overlay(alignment: .bottom) { if entry.id != entries.last?.id { Divider() } }
               }
              }.padding(.horizontal, 20)
            }
        }
    }

    @ViewBuilder private var savedOutfits: some View {
        if outfits.isEmpty {
            WearwiseEmptyState(title: "Build your outfits", systemImage: "square.grid.2x2",
                description: "Arrange clothes and stickers into reusable collages.", actionTitle: "Create outfit", action: { creating = true })
        } else {
            ScrollView {
                LazyVStack(spacing: 22) {
                    ForEach(outfits) { outfit in
                        VStack(alignment: .leading, spacing: 10) {
                            Button { previewOutfit = outfit } label: {
                                CompositionPreview(data: outfit.compositionData).frame(height: 250).frame(maxWidth: .infinity)
                                    .background(Color.imageMount, in: RoundedRectangle(cornerRadius: WearwiseRadius.large))
                                    .clipShape(RoundedRectangle(cornerRadius: WearwiseRadius.large))
                            }.buttonStyle(WearwisePressStyle()).accessibilityLabel("View outfit: \(outfit.name)")
                            HStack {
                                Text(outfit.name).font(.headline)
                                Spacer()
                                Menu {
                                    Button("Share image", systemImage: "square.and.arrow.up") { share.open(data: outfit.compositionData, context: context) }
                                    Button("Delete outfit", systemImage: "trash", role: .destructive) { deletingOutfit = outfit }
                                } label: {
                                    Label("Outfit actions: \(outfit.name)", systemImage: "ellipsis")
                                        .labelStyle(.iconOnly).frame(width: 44, height: 44).contentShape(Rectangle())
                                }.buttonStyle(.borderless)
                            }
                        }
                    }
                }.padding()
            }
        }
    }

    private func perform(_ action: () throws -> Void) {
        do { try action() } catch { errorText = error.localizedDescription }
    }
}

private struct OutfitPreview: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let outfit: Outfit
    @State private var editing = false
    @State private var share = SavedLookShare()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    CompositionPreview(data: outfit.compositionData).frame(height: 400).frame(maxWidth: .infinity)
                        .background(Color.imageMount, in: RoundedRectangle(cornerRadius: WearwiseRadius.large))
                        .clipShape(RoundedRectangle(cornerRadius: WearwiseRadius.large))
                    Text(outfit.name).font(.title2.weight(.semibold))
                    Text("\(outfit.garments.count) pieces").foregroundStyle(.secondary)
                }.padding()
            }.background(Color.wardrobeBackground)
                .navigationTitle("Outfit preview").navigationBarTitleDisplayMode(.inline).wearwiseKeyboardDismissal()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark") { dismiss() } }
                    ToolbarItem(placement: .primaryAction) { Button("Edit", systemImage: "pencil") { editing = true }.accessibilityIdentifier("outfit.preview.edit") }
                    ToolbarItem(placement: .primaryAction) {
                        Menu { Button("Share image", systemImage: "square.and.arrow.up") { share.open(data: outfit.compositionData, context: context) } }
                        label: { Label("Outfit actions", systemImage: "ellipsis").frame(minWidth: 44, minHeight: 44) }
                    }
                }.labelStyle(.iconOnly)
                .sheet(isPresented: $editing) { FlatlayEditorView(outfit: outfit) }
                .savedLookSharing(share)
        }
    }
}

private struct JournalEntryPreview: View {
    @Environment(AppFeedback.self) private var feedback
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let entry: JournalEntry
    @State private var editing = false
    @State private var share = SavedLookShare()
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(entry.name).font(.title2.weight(.semibold))
                    LabeledContent("Date", value: entry.date.formatted(date: .abbreviated, time: .omitted))
                }
                Section("Pieces") {
                    ForEach(entry.garments.sorted { $0.name < $1.name }) { garment in
                        HStack(spacing: 14) {
                            GarmentImageView(record: garment.cutoutAsset ?? garment.originalAsset).frame(width: 64, height: 78)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(garment.name)
                                Text(garment.brand).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if !entry.note.isEmpty { Section("Note") { Text(entry.note) } }
                Section("Saved look") {
                    if let image = entry.renderedAsset { GarmentImageView(record: image).frame(height: 220).frame(maxWidth: .infinity) }
                    else { CompositionPreview(data: entry.compositionData).frame(height: 220) }
                }

            }.scrollDismissesKeyboard(.interactively).scrollContentBackground(.hidden).background(Color.wardrobeBackground)
                .navigationTitle("Journal entry").navigationBarTitleDisplayMode(.inline).wearwiseKeyboardDismissal()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark") { dismiss() } }
                    ToolbarItem(placement: .primaryAction) { Button("Edit", systemImage: "pencil") { editing = true }.accessibilityIdentifier("journal.preview.edit") }
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button("Share image", systemImage: "square.and.arrow.up") { share.open(entry: entry, context: context) }
                        }
                        label: { Label("Diary actions", systemImage: "ellipsis").frame(minWidth: 44, minHeight: 44) }
                    }
                }.labelStyle(.iconOnly)
                .sheet(isPresented: $editing) { JournalRecordEditor(entry: entry) }
                .savedLookSharing(share)
                .wearwiseErrorToast("Could not complete this action", message: $errorText)
        }
    }
}

struct JournalRecordEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Garment.name) private var garments: [Garment]
    @Query(sort: \Outfit.updatedAt, order: .reverse) private var outfits: [Outfit]
    var entry: JournalEntry? = nil
    @State private var name = ""
    @State private var date = Date()
    @State private var note = ""
    @State private var ids: Set<UUID> = []
    @State private var originalIDs: Set<UUID> = []
    @State private var chosenOutfit: UUID?
    @State private var chosenComposition: FlatlayComposition?
    @State private var originalComposition: FlatlayComposition?
    @State private var baselineName = ""
    @State private var baselineDate = Date()
    @State private var baselineNote = ""
    @FocusState private var titleFocused: Bool
    @State private var loaded = false
    @State private var discarding = false
    @State private var errorText: String?
    @State private var choosingPieces = false

    private var changed: Bool { name != baselineName || note != baselineNote || date != baselineDate || ids != originalIDs || chosenOutfit != nil }
    private var available: [Garment] { garments.filter { $0.status == GarmentStatus.owned || originalIDs.contains($0.id) || ids.contains($0.id) } }

    var body: some View {
        NavigationStack {
            Form {
                Section("Day") {
                    DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                    TextField("Title (optional)", text: $name).focused($titleFocused).submitLabel(.done)
                        .onSubmit { titleFocused = false }.accessibilityIdentifier("journal.name")
                }
                Section("Outfit") {
                    Picker("Saved outfit", selection: $chosenOutfit) {
                        Text("None").tag(Optional<UUID>.none)
                        ForEach(outfits.filter { !$0.garments.isEmpty && $0.garments.allSatisfy { $0.status == GarmentStatus.owned || originalIDs.contains($0.id) } }) { Text($0.name).tag(Optional($0.id)) }
                    }
                }
                Section("Pieces") {
                    ForEach(available.filter { ids.contains($0.id) }) { garment in
                        HStack(spacing: 12) {
                            GarmentImageView(record: garment.cutoutAsset ?? garment.originalAsset).frame(width: 42, height: 50)
                            Text(garment.name)
                            Spacer()
                            Button {
                                ids.remove(garment.id)
                                chosenOutfit = nil
                                chosenComposition = nil
                            } label: { Image(systemName: "minus.circle") .frame(width: 44, height: 44) }
                            .buttonStyle(.borderless).accessibilityLabel("Remove \(garment.name)")
                            .accessibilityIdentifier("journal.remove.\(garment.id.uuidString)")
                        }
                    }
                    Button("Add pieces", systemImage: "plus") { choosingPieces = true }
                        .labelStyle(.titleAndIcon).accessibilityIdentifier("journal.add-pieces")
                    if ids.isEmpty { Text("Choose the pieces you wore.").foregroundStyle(.secondary) }
                }
                Section("Note") {
                    WearwiseNotesEditor(text: $note, label: "Note").accessibilityIdentifier("diary.note")
                }
            }.scrollDismissesKeyboard(.interactively).scrollContentBackground(.hidden).background(Color.wardrobeBackground)
                .navigationTitle(entry == nil ? "New journal entry" : "Edit journal entry").navigationBarTitleDisplayMode(.inline).wearwiseKeyboardDismissal()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel", systemImage: "xmark") { if changed { discarding = true } else { dismiss() } } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save", systemImage: "checkmark") { save() }
                            .disabled(!loaded || (ids.isEmpty && originalComposition?.layers.isEmpty != false))
                    }
                }.labelStyle(.iconOnly)
                .interactiveDismissDisabled(changed)
                .task {
                    guard !loaded else { return }
                    do {
                        originalComposition = try entry?.composition()
                        name = entry?.name ?? ""
                        date = entry?.date ?? Date()
                        note = entry?.note ?? ""
                        ids = Set(entry?.garments.map(\.id) ?? [])
                        originalIDs = ids
                        baselineName = name; baselineDate = date; baselineNote = note
                        loaded = true
                    } catch { errorText = error.localizedDescription }
                }
                .onChange(of: ids) {
                    if let chosenComposition, ids != chosenComposition.garmentIDs {
                        chosenOutfit = nil
                        self.chosenComposition = nil
                    }
                }
                .onChange(of: chosenOutfit) {
                    guard let selected = outfits.first(where: { $0.id == chosenOutfit }) else { chosenComposition = nil; return }
                    do {
                        chosenComposition = try selected.composition()
                        ids = Set(selected.garments.map(\.id))
                        if name.isEmpty { name = selected.name }
                    } catch { errorText = error.localizedDescription }
                }
                .sheet(isPresented: $choosingPieces) {
                    JournalPiecePicker(garments: available, selection: $ids)
                }
                .wearwiseDiscardConfirmation(isPresented: $discarding) { dismiss() }
                .wearwiseErrorToast("Could not save journal entry", message: $errorText)
        }
    }

    private func save() {
        do {
            let source = outfits.first { $0.id == chosenOutfit }
            let composition: FlatlayComposition
            if let chosenComposition, ids == chosenComposition.garmentIDs { composition = chosenComposition }
            else if let originalComposition, ids == originalIDs { composition = originalComposition }
            else {
                let pieces = garments.filter { ids.contains($0.id) }
                guard pieces.count == ids.count else { throw OutfitStoreError.missingGarment }
                composition = try JournalStore(context: context).recordComposition(pieces, preserving: originalComposition)
            }
            let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
            try JournalStore(context: context).saveRecord(name: title.isEmpty ? date.formatted(date: .abbreviated, time: .omitted) : title,
                date: date, note: note, composition: composition, updating: entry, from: source)
            dismiss()
        } catch { errorText = error.localizedDescription }
    }
}

private struct JournalPiecePicker: View {
    @Environment(\.dismiss) private var dismiss
    let garments: [Garment]
    @Binding var selection: Set<UUID>
    @State private var draft: Set<UUID>
    @State private var search = ""

    init(garments: [Garment], selection: Binding<Set<UUID>>) {
        self.garments = garments
        _selection = selection
        _draft = State(initialValue: selection.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(garments.filter { $0.matches(search: search) }) { garment in
                    Button {
                        if draft.contains(garment.id) { draft.remove(garment.id) } else { draft.insert(garment.id) }
                    } label: {
                        HStack(spacing: 12) {
                            GarmentImageView(record: garment.cutoutAsset ?? garment.originalAsset).frame(width: 42, height: 50)
                            VStack(alignment: .leading) {
                                Text(garment.name).foregroundStyle(Color.charcoalText)
                                Text(garment.brand).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: draft.contains(garment.id) ? "checkmark.circle.fill" : "circle")
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityLabel(garment.name)
                        .accessibilityValue(draft.contains(garment.id) ? "Selected" : "Not selected")
                        .accessibilityIdentifier("journal.piece.\(garment.id.uuidString)")
                }
            }.searchable(text: $search, prompt: "Name, brand, or category")
            .submitLabel(.done).onSubmit(of: .search) { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                .scrollDismissesKeyboard(.interactively).scrollContentBackground(.hidden).background(Color.wardrobeBackground)
                .navigationTitle("Choose pieces").navigationBarTitleDisplayMode(.inline).wearwiseKeyboardDismissal()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { selection = draft; dismiss() } }
                }
        }
    }
}

struct CompositionPreview: View {
    @Environment(\.modelContext) private var context
    let data: Data
    @State private var composition: FlatlayComposition?
    @State private var images: [UUID: UIImage] = [:]
    @State private var errorText: String?

    var body: some View {
        Group {
            if let errorText { Label(errorText, systemImage: "exclamationmark.triangle").labelStyle(.titleAndIcon).font(.caption) }
            else if let composition { CompositionCanvas(composition: composition, images: images) }
            else { ProgressView() }
        }.task(id: data) {
            do {
                let saved = try FlatlayComposition.decode(data)
                images = try OutfitStore(context: context).images(for: saved)
                composition = saved
                errorText = nil
            } catch { errorText = error.localizedDescription }
        }
    }
}

@MainActor @Observable
private final class SavedLookShare {
    var url: URL?
    var showing = false
    var errorText: String?

    func open(entry: JournalEntry, context: ModelContext) {
        do {
            if let image = entry.renderedAsset { try write(AssetStore.shared.loadData(for: image)) }
            else { open(data: entry.compositionData, context: context) }
        } catch { errorText = error.localizedDescription }
    }

    func open(data: Data, context: ModelContext) {
        do {
            let composition = try FlatlayComposition.decode(data)
            try write(FlatlayRenderer.png(composition: composition, images: OutfitStore(context: context).images(for: composition)))
        } catch { errorText = error.localizedDescription }
    }

    private func write(_ data: Data) throws {
        guard UIImage(data: data) != nil else { throw OutfitStoreError.missingImage }
        let file = URL.temporaryDirectory.appending(path: "\(TemporaryOutfitExports.prefix)\(UUID().uuidString).png")
        try data.write(to: file, options: .atomic)
        url = file
        showing = true
    }

    func clear() {
        guard let url else { return }
        do { try FileManager.default.removeItem(at: url) }
        catch { errorText = "Could not remove the temporary share image: \(error.localizedDescription)" }
        self.url = nil
    }
}

private struct SavedLookSharing: ViewModifier {
    @Bindable var share: SavedLookShare
    func body(content: Content) -> some View {
        content.sheet(isPresented: $share.showing, onDismiss: share.clear) {
            if let url = share.url { OutfitShareSheet(url: url) }
        }
        .wearwiseErrorToast("Could not share image", message: $share.errorText)
    }
}

private extension View {
    func savedLookSharing(_ share: SavedLookShare) -> some View { modifier(SavedLookSharing(share: share)) }
}
