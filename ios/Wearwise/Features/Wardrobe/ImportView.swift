import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportView: View {
    var collection: GarmentCollection = .wardrobe
    var replacing: Garment? = nil
    var initialImageData: Data? = nil
    var startInLibrary = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.wearwiseCurrency) private var currency

    @State private var showingPhotoLibrary = false
    @State private var openedLibrary = false
    @State private var pickedData: Data?
    @State private var phase: ImportPhase = .selecting
    @State private var errorText: String?
    @State private var processed: ProcessedImport?
    @State private var attributes = ImportAttributes()
    @State private var showingFilePicker = false
    @State private var updateColors = false
    @State private var confirmingDiscard = false
    @State private var operation: Task<Void, Never>?
    @State private var sourceProgress: Progress?
    @State private var showingOriginal = false

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .selecting: selectingView
                case .processing: ProgressView("Processing image…")
                case .review: reviewView
                }
            }
            .navigationTitle(replacing == nil ? collection.importTitle : "Replace Image")
            .navigationBarTitleDisplayMode(.inline).wearwiseKeyboardDismissal()
            .interactiveDismissDisabled(phase != .selecting)
            .labelStyle(.iconOnly)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") {
                        if phase == .selecting { dismiss() } else { confirmingDiscard = true }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if phase == .review {
                        Button("Save", systemImage: "checkmark") { save() }
                            .disabled(replacing == nil && attributes.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .navigationDestination(isPresented: $showingPhotoLibrary) {
                PhotoLibraryView { data in
                    showingPhotoLibrary = false
                    startImport { data }
                }
            }
            .wearwiseDiscardConfirmation(isPresented: $confirmingDiscard) { dismiss() }
            .wearwiseErrorToast("Import failed", message: $errorText)
            .fileImporter(isPresented: $showingFilePicker, allowedContentTypes: [.image]) { result in
                switch result {
                case .success(let url):
                    startImport {
                        let access = url.startAccessingSecurityScopedResource()
                        defer { if access { url.stopAccessingSecurityScopedResource() } }
                        return try Data(contentsOf: url)
                    }
                case .failure(let error):
                    if (error as? CocoaError)?.code != .userCancelled { fail(with: error) }
                }
            }
        }
        .task {
            if startInLibrary && !openedLibrary { openedLibrary = true; showingPhotoLibrary = true }
            if let initialImageData, pickedData == nil {
                pickedData = initialImageData
                startImport { initialImageData }
            }
        }
        // Cancel only when the whole import flow closes, not when its content or destination changes.
        .onDisappear { operation?.cancel(); sourceProgress?.cancel() }
    }

    private var selectingView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Choose an image")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color.charcoalText)
                    Text("Select a photo of a standalone garment.")
                        .font(.subheadline)
                        .foregroundStyle(Color.supportingText)
                }
                VStack(spacing: 12) {
                    Button { showingPhotoLibrary = true } label: {
                        sourceLabel("Choose from Library", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(WearwiseButtonStyle())
                    Button { showingFilePicker = true } label: {
                        sourceLabel("Choose a file", systemImage: "folder")
                    }
                    .buttonStyle(WearwiseButtonStyle(filled: false))
                    Button {
                        guard let data = ClipboardImageReader.read() else {
                            errorText = "Copy an image before using Paste image."
                            return
                        }
                        startImport { data }
                    } label: {
                        sourceLabel("Paste image", systemImage: "doc.on.clipboard")
                    }
                    .buttonStyle(WearwiseButtonStyle(filled: false))
                    if let data = pickedData {
                        Button { startImport { data } } label: {
                            sourceLabel("Retry selected image", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(WearwiseButtonStyle(filled: false))
                    }
                }
                .labelStyle(.titleAndIcon)
            }
            .frame(maxWidth: 360)
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(Color.wardrobeBackground)
        .onDrop(of: [UTType.image.identifier], isTargeted: nil) { providers in
            guard let provider = providers.first,
                  let type = provider.registeredTypeIdentifiers.first(where: { UTType($0)?.conforms(to: .image) == true })
            else { return false }
            startImport {
                try await withCheckedThrowingContinuation { continuation in
                    sourceProgress = provider.loadDataRepresentation(forTypeIdentifier: type) { data, error in
                        if let data { continuation.resume(returning: data) }
                        else { continuation.resume(throwing: error ?? ImageImportError.undecodable) }
                    }
                }
            }
            return true
        }
    }

    nonisolated private func sourceLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var reviewView: some View {
        if let p = processed {
            List {
                Section("Image") {
                    Picker("Image preview", selection: $showingOriginal) {
                        Text("Cutout").tag(false)
                        Text("Original").tag(true)
                    }.pickerStyle(.segmented).accessibilityIdentifier("import.preview")
                    if let uiImage = UIImage(data: showingOriginal ? p.original.originalPNG : p.cutoutPNG) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 240)
                            .frame(maxWidth: .infinity)
                            .background(Color.cutoutSurface,
                                in: RoundedRectangle(cornerRadius: WearwiseRadius.large, style: .continuous))
                            .listRowBackground(Color.clear)
                    }
                }
                if replacing == nil {
                    Section("Attributes") {
                        TextField("Name", text: $attributes.name).accessibilityIdentifier("import.name")
                        GarmentCategoryPicker(selection: $attributes.category)
                        LabeledContent("Brand") {
                            TextField("", text: $attributes.brand).multilineTextAlignment(.leading)
                                .accessibilityLabel("Brand").accessibilityIdentifier("import.brand")
                        }
                        LabeledContent("Size") {
                            TextField("", text: $attributes.size).multilineTextAlignment(.trailing)
                                .accessibilityLabel("Size").accessibilityIdentifier("import.size")
                        }
                        Menu {
                            ForEach(["spring", "summer", "autumn", "winter"], id: \.self) { season in
                                Button {
                                    if attributes.seasons.contains(season) { attributes.seasons.remove(season) }
                                    else { attributes.seasons.insert(season) }
                                } label: {
                                    if attributes.seasons.contains(season) { Label(season.capitalized, systemImage: "checkmark") }
                                    else { Text(season.capitalized) }
                                }
                            }
                        } label: {
                            LabeledContent("Seasons", value: attributes.seasons.sorted().map(\.capitalized).joined(separator: ", "))
                        }.labelStyle(.titleAndIcon).accessibilityIdentifier("import.seasons")
                        LabeledContent("Price") {
                            HStack {
                                TextField("", text: $attributes.price).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                    .accessibilityLabel("Price").accessibilityIdentifier("import.price")
                                if !currency.isEmpty { Text(currency).foregroundStyle(.secondary) }
                            }
                        }
                        GarmentColorPicker(selection: $attributes.colors)
                    }
                    Section("Notes") {
                        WearwiseNotesEditor(text: $attributes.notes).accessibilityIdentifier("import.notes")
                    }
                } else {
                    Section {
                        Toggle("Update colors from this image", isOn: $updateColors)
                    }
                }
                if replacing != nil && updateColors {
                    Section {
                        GarmentColorPicker(selection: $attributes.colors)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively).scrollContentBackground(.hidden)
            .background(Color.wardrobeBackground)
        }
    }

    private func startImport(_ source: @escaping @MainActor () async throws -> Data) {
        operation?.cancel()
        sourceProgress?.cancel()
        phase = .processing
        operation = Task {
            do {
                try Task.checkCancellation()
                let data = try await source()
                try Task.checkCancellation()
                pickedData = data
                let result = try await ImageImportService.process(data)
                try Task.checkCancellation()
                processed = result
                showingOriginal = false
                attributes.colors = Set(result.suggestedColors)
                if attributes.name.isEmpty {
                    attributes.name = collection == .wardrobe ? "New garment" : "New shopping item"
                }
                phase = .review
            } catch {
                if !Task.isCancelled { fail(with: error) }
            }
        }
    }

    private func fail(with error: Error) {
        errorText = error.localizedDescription
        phase = .selecting
    }

    private func save() {
        guard let p = processed else { return }
        do {
            let garment: Garment
            if let replacing { garment = replacing }
            else { garment = try attributes.makeGarment(collection: collection, defaults: PreferencesStore().load()) }
            let previousColors = garment.colorTags
            if replacing != nil && updateColors {
                garment.colorTags = Array(attributes.colors).sorted()
            }
            do {
                try GarmentStore(context: modelContext).saveImages(original: p.original.originalPNG, cutout: p.cutoutPNG, on: garment)
            } catch {
                garment.colorTags = previousColors
                throw error
            }
            dismiss()
        } catch {
            errorText = "Saving failed: \(error.localizedDescription)"
        }
    }
}

struct ImportAttributes {
    var name = ""
    var category = ""
    var colors: Set<String> = []
    var brand = ""
    var size = ""
    var seasons: Set<String> = []
    var price = ""
    var notes = ""

    func makeGarment(collection: GarmentCollection, defaults: WardrobeDefaults) throws -> Garment {
        let garment = Garment(name: name, category: category, colorTags: colors.sorted(), brand: brand,
            size: size, seasons: seasons.sorted(), status: collection.recordStatus)
        defaults.applyToNewGarment(garment, collection: collection)
        var draft = GarmentDraft(garment)
        draft.price = price
        draft.notes = notes
        try draft.apply(to: garment)
        return garment
    }
}

enum ImportPhase {
    case selecting
    case processing
    case review
}

enum ClipboardImageReader {
    static func read() -> Data? {
        UIPasteboard.general.images?.first?.pngData()
    }
}
