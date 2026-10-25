import SwiftData
import SwiftUI
import WearwiseCore

struct FlatlayEditorView: View {
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss
  @Query private var garments: [Garment]
  var outfit: Outfit? = nil
  var initialShoppingItem: Garment? = nil
  var journalEntry: JournalEntry? = nil
  var saveToDiary = false
  @State private var savedEntry: JournalEntry?
  @State private var date = Date()
  @State private var baselineDate = Date()
  @State private var note = ""
  @State private var baselineNote = ""
  @State private var tool: EditorTool?
  @State private var pendingStickers: [AssetRecord] = []
  @State private var saved: Outfit?
  @State private var name = "New outfit"
  @State private var composition = FlatlayComposition()
  @State private var history = CompositionHistory()
  @State private var adjustmentBaseline: FlatlayComposition?
  @State private var baseline = FlatlayComposition()
  @State private var baselineName = "New outfit"
  @State private var selectedID: UUID?
  @State private var images: [UUID: UIImage] = [:]
  @State private var loaded = false
  @State private var addingGarment = false
  @State private var addingShoppingItem = false
  @State private var discard = false
  @State private var errorText: String?
  @State private var shareURL: URL?
  @State private var sharing = false
  @FocusState private var nameFocused: Bool

  private var selected: CompositionLayer? { composition.layers.first { $0.id == selectedID } }
  private var hasChanges: Bool {
    name != baselineName || composition != baseline || note != baselineNote
      || (saveToDiary && date != baselineDate)
  }

  private var editorContent: some View {
      VStack(spacing: 12) {
        if loaded {
          TextField("Outfit name", text: $name).textFieldStyle(.roundedBorder)
            .focused($nameFocused).submitLabel(.done)
            .onSubmit { nameFocused = false }
            .accessibilityIdentifier("outfit.name")
          if saveToDiary {
            Button(date.formatted(date: .abbreviated, time: .omitted)) { tool = .diary }
              .font(.caption)
              .accessibilityLabel("Edit day and note")
              .accessibilityIdentifier("diary.details")
          }
          GeometryReader { geometry in
            let width = min(
              max(1, geometry.size.width), max(1, geometry.size.height) * composition.width / composition.height)
            CompositionCanvas(
              composition: composition, images: images, selectedID: selectedID, interactive: true,
              layerLabels: Dictionary(uniqueKeysWithValues: composition.layers.enumerated().map { index, layer in
                let title = garments.first { $0.id == layer.garmentID }?.name ?? "Your character"
                return (layer.id, "\(title), layer \(index + 1)")
              }),
              onSelect: { nameFocused = false; selectedID = $0 },
              onTransform: { id, x, y, scale, angle in
                guard selectedID == id else { return }
                modify { try $0.transform(id, translationX: x, translationY: y, magnification: scale, rotation: angle) }
              },
              onResize: { id, handle, x, y in
                guard selectedID == id else { return }
                modify { try $0.resize(id, handle: handle, translationX: x, translationY: y) }
              },
              onDelete: removeLayer
            )
            .frame(width: width, height: width * composition.height / composition.width)
            .overlay { Rectangle().strokeBorder(Color.subtleBorder, lineWidth: 1) }
            .wearwiseShadow()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
          }
          // A scrolling parent gives GeometryReader no height; reserve room for direct manipulation.
          .frame(minHeight: typeSize.isAccessibilitySize ? 240 : nil)
          .padding(12)
          .background(Color.imageMount, in: RoundedRectangle(cornerRadius: WearwiseRadius.large, style: .continuous))
          .accessibilityElement(children: .contain)
          HStack {
            Button("Undo", systemImage: "arrow.uturn.backward") { composition = history.undo(composition); restoreSelection() }
              .disabled(!history.canUndo).accessibilityIdentifier("outfit.undo")
            Button("Redo", systemImage: "arrow.uturn.forward") { composition = history.redo(composition); restoreSelection() }
              .disabled(!history.canRedo).accessibilityIdentifier("outfit.redo")
            Spacer()

          }
          .labelStyle(.iconOnly)
          .buttonStyle(.borderless)
          .controlSize(.large)
          .frame(minHeight: 44)
          Group {
            if typeSize >= .xxxLarge {
              LazyVGrid(columns: typeSize >= .accessibility4 ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                editorActions
              }.font(.title3).labelStyle(.iconOnly)
            } else {
              HStack { editorActions }.labelStyle(.iconOnly)
            }
          }
          .padding(6)
          .background(.regularMaterial, in: RoundedRectangle(cornerRadius: WearwiseRadius.large, style: .continuous))
          .overlay { RoundedRectangle(cornerRadius: WearwiseRadius.large, style: .continuous).strokeBorder(Color.subtleBorder, lineWidth: 1) }
          .wearwiseShadow(.floating)
        } else {
          ProgressView("Opening outfit…")
        }
      }
  }

  var body: some View {
    NavigationStack {
      Group {
        if typeSize.isAccessibilitySize {
          ScrollView { editorContent }
            .scrollDismissesKeyboard(.interactively)
        } else {
          editorContent
        }
      }
      .padding()
      .onChange(of: tool) { nameFocused = false }
      .onChange(of: addingGarment) { nameFocused = false }
      .onChange(of: addingShoppingItem) { nameFocused = false }
      .task(id: composition.assetIDs) {
        do { images = try OutfitStore(context: context).images(for: composition) } catch {
          errorText = error.localizedDescription
        }
      }
      .background(Color.wardrobeBackground)
      .navigationTitle(saveToDiary ? "Diary Entry" : "Outfit")
      .navigationBarTitleDisplayMode(.inline).wearwiseKeyboardDismissal()
      .labelStyle(.iconOnly)
            .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", systemImage: "xmark") {
            if hasChanges { discard = true } else { close() }
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save", systemImage: "checkmark") { save() }
            .disabled(
              !loaded || composition.layers.isEmpty
                || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || images.count != composition.assetIDs.count)
        }
      }
      .labelStyle(.iconOnly)
      .interactiveDismissDisabled(hasChanges || !pendingStickers.isEmpty)
      .task {
        guard !loaded else { return }
        do {
          saved = outfit
          savedEntry = journalEntry
          date = journalEntry?.date ?? Date()
          baselineDate = date
          note = journalEntry?.note ?? ""
          baselineNote = note
          composition =
            try journalEntry?.composition() ?? outfit?.composition() ?? FlatlayComposition()
          name = journalEntry?.name ?? outfit?.name ?? "New outfit"
          baseline = composition
          baselineName = name
          if outfit == nil, let initialShoppingItem {
            guard initialShoppingItem.collection == .shopping else {
              throw ShoppingError.notShoppingItem
            }
            composition.layers.append(
              try OutfitStore(context: context).layer(for: initialShoppingItem, in: composition))
            name = "Try \(initialShoppingItem.name)"
          }
          selectedID = composition.layers.last?.id
          loaded = true
        } catch { errorText = error.localizedDescription }
      }
      .sheet(isPresented: $addingGarment) {
        GarmentLayerPicker { garment in
          do {
            let layer = try OutfitStore(context: context).layer(for: garment, in: composition)
            modify { $0.layers.append(layer) }
            selectedID = layer.id
          } catch { errorText = error.localizedDescription }
        }
      }
      .sheet(isPresented: $addingShoppingItem) {
        GarmentLayerPicker(collection: .shopping) { garment in
          do {
            let layer = try OutfitStore(context: context).layer(for: garment, in: composition)
            modify { $0.layers.append(layer) }
            selectedID = layer.id
          } catch { errorText = error.localizedDescription }
        }
      }
      .sheet(
        item: $tool
      ) { selectedTool in
        NavigationStack {
          Group {
            switch selectedTool {
            case .layers:
              List {
                Section {
                  ForEach(composition.layers.reversed()) { layer in
                    Button { selectedID = layer.id } label: {
                      HStack(spacing: 12) {
                        if let image = images[layer.assetID] {
                          Image(uiImage: image).resizable().scaledToFit().frame(width: 40, height: 48)
                        }
                        Text(garments.first { $0.id == layer.garmentID }?.name ?? "Your character")
                          .foregroundStyle(Color.charcoalText)
                        Spacer()
                        if selectedID == layer.id { Image(systemName: "checkmark.circle.fill") }
                      }.contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("layers.row.\(layer.id.uuidString)")
                  }
                  .onMove { indices, destination in
                    var ordered = Array(composition.layers.reversed())
                    ordered.move(fromOffsets: indices, toOffset: destination)
                    modify { $0.layers = Array(ordered.reversed()) }
                  }
                } footer: { Text("Touch and hold a layer’s handle to change its order.") }
                if let layer = selected { Section("Selected layer") { layerControls(layer) } }
              }.environment(\.editMode, .constant(.active))
            case .diary:
              Form {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                if let wornDate = savedEntry?.wearRecords.first?.date {
                  LabeledContent("Recorded wearing", value: wornDate.formatted(date: .abbreviated, time: .omitted))
                }
                WearwiseNotesEditor(text: $note, label: "Note")
                  .accessibilityIdentifier("diary.note")
              }
            }
          }
          .scrollDismissesKeyboard(.interactively).scrollContentBackground(.hidden)
          .background(Color.wardrobeBackground)
          .navigationTitle(selectedTool.rawValue).navigationBarTitleDisplayMode(.inline).wearwiseKeyboardDismissal()
          .labelStyle(.iconOnly)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done", systemImage: "checkmark") { tool = nil }.labelStyle(.iconOnly) } }
        }
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(WearwiseRadius.extraLarge)
      }
      .sheet(isPresented: $sharing, onDismiss: clearExport) {
        if let shareURL { OutfitShareSheet(url: shareURL) }
      }
      .wearwiseDiscardConfirmation(isPresented: $discard, title: "Discard outfit changes?") { close() }
      .wearwiseErrorToast("Could not complete this action", message: $errorText)
    }
  }

  private var editorActions: some View {
    Group {
      Menu {
        Button("Wardrobe") { addingGarment = true }.accessibilityIdentifier("outfit.addGarment")
        Button("Shopping") { addingShoppingItem = true }.accessibilityIdentifier("outfit.tryShoppingItem")
      } label: { Label("Add", systemImage: "plus") }
        .accessibilityIdentifier("outfit.add")
        .disabled(savedEntry?.wearingRecorded == true)
      Button { insertCharacter() } label: { Label("Character", systemImage: "person.crop.square") }
      Button { tool = .layers } label: { Label("Layers", systemImage: "square.3.layers.3d") }
      if !saveToDiary {
        Button("Share image", systemImage: "square.and.arrow.up") { export() }
          .disabled(composition.layers.isEmpty || images.count != composition.assetIDs.count)
      }
    }
    .frame(maxWidth: .infinity, minHeight: 44)
  }

  private func layerControls(_ layer: CompositionLayer) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(garments.first { $0.id == layer.garmentID }?.name ?? "Selected image").font(.headline)
        Spacer()
        Button("Remove", systemImage: "trash", role: .destructive) {
          removeLayer(layer.id)
        }
        .disabled(savedEntry?.wearingRecorded == true && layer.garmentID != nil)
      }
      Text("Size").font(.subheadline)
      Slider(
        value: Binding(
          get: { layer.width }, set: { width in modify { try $0.resize(layer.id, width: width) } }),
        in: 0.05...1.5, onEditingChanged: trackAdjustment
      )
      .accessibilityLabel("Layer size")
      Text("Width").font(.subheadline)
      Slider(value: Binding(get: { layer.width }, set: { width in modify { try $0.resize(layer.id, width: width, height: layer.height) } }),
             in: 0.05...1.5, onEditingChanged: trackAdjustment).accessibilityLabel("Layer width")
      Text("Height").font(.subheadline)
      Slider(value: Binding(get: { layer.height }, set: { height in modify { try $0.resize(layer.id, width: layer.width, height: height) } }),
             in: 0.05...1.5, onEditingChanged: trackAdjustment).accessibilityLabel("Layer height")
      Text("Rotation · \(Int(layer.rotation))°").font(.subheadline)
      Slider(
        value: Binding(
          get: { layer.rotation },
          set: { angle in modify { try $0.rotate(layer.id, degrees: angle) } }), in: -180...180,
        onEditingChanged: trackAdjustment
      )
      .accessibilityLabel("Layer rotation")
      HStack {
        Button("Send backward", systemImage: "square.3.layers.3d.bottom.filled") { modify { try $0.reorder(layer.id, steps: -1) } }
        Button("Bring forward", systemImage: "square.3.layers.3d.top.filled") { modify { try $0.reorder(layer.id, steps: 1) } }
      }.labelStyle(.titleAndIcon).buttonStyle(.borderless)
    }
    .padding()
    .background(Color.paperSurface, in: RoundedRectangle(cornerRadius: 12))
  }

  private func removeLayer(_ id: UUID) {
    guard let layer = composition.layers.first(where: { $0.id == id }),
          !(savedEntry?.wearingRecorded == true && layer.garmentID != nil) else { return }
    modify { try $0.remove(id) }
    selectedID = composition.layers.last?.id
  }

  private func close() {
    do {
      try CharacterStickerStore(context: context).removeUnused(pendingStickers)
      pendingStickers = []
      dismiss()
    } catch { errorText = error.localizedDescription }
  }

  private func modify(_ action: (inout FlatlayComposition) throws -> Void) {
    do {
      var updated = composition
      try action(&updated)
      try updated.validate()
      if adjustmentBaseline == nil { history.record(before: composition, after: updated) }
      composition = updated
    } catch { errorText = error.localizedDescription }
  }

  private func restoreSelection() {
    if !composition.layers.contains(where: { $0.id == selectedID }) { selectedID = composition.layers.last?.id }
  }

  private func trackAdjustment(_ active: Bool) {
    if active { adjustmentBaseline = composition }
    else if let before = adjustmentBaseline {
      history.record(before: before, after: composition)
      adjustmentBaseline = nil
    }
  }

  private func insertCharacter() {
    nameFocused = false
    do {
      let appearance = try CharacterPreferences().load()
      let record = try CharacterStickerStore(context: context).create(appearance)
      pendingStickers.append(record)
      let width = 0.28
      let layer = CompositionLayer(assetID: record.id, width: width,
        height: width * composition.width / composition.height * Double(record.pixelHeight) / Double(record.pixelWidth))
      modify { $0.layers.append(layer) }
      selectedID = layer.id
    } catch { errorText = error.localizedDescription }
  }

  private func save() {
    do {
      if saveToDiary {
        savedEntry = try JournalStore(context: context).save(
          name: name, date: date, note: note, composition: composition, updating: savedEntry)
      } else {
        saved = try OutfitStore(context: context).save(
          name: name, composition: composition, updating: saved)
      }
      baseline = composition
      baselineName = name
      baselineDate = date
      baselineNote = note
      try CharacterStickerStore(context: context).removeUnused(pendingStickers)
      pendingStickers = []
      dismiss()
    } catch { errorText = error.localizedDescription }
  }

  private func export() {
    do {
      let data = try FlatlayRenderer.png(composition: composition, images: images)
      let url = URL.temporaryDirectory.appending(path: "\(TemporaryOutfitExports.prefix)\(UUID().uuidString).png")
      try data.write(to: url, options: .atomic)
      shareURL = url
      sharing = true
    } catch { errorText = error.localizedDescription }
  }

  private func clearExport() {
    guard let url = shareURL else { return }
    do { try FileManager.default.removeItem(at: url) } catch {
      errorText = "Could not remove the temporary share image: \(error.localizedDescription)"
    }
    shareURL = nil
  }
}

enum TemporaryOutfitExports {
  static let prefix = "wearwise-outfit-"

  static func removeAbandoned(in directory: URL = .temporaryDirectory) throws {
    let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
    for file in files where file.lastPathComponent.hasPrefix(prefix) && file.pathExtension == "png" {
      try FileManager.default.removeItem(at: file)
    }
  }
}

struct OutfitShareSheet: UIViewControllerRepresentable {
  let url: URL
  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: [url], applicationActivities: nil)
  }
  func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private struct GarmentLayerPicker: View {
  @Environment(\.dismiss) private var dismiss
  @Query(sort: \Garment.name) private var garments: [Garment]
  var collection: GarmentCollection = .wardrobe
  var onSelect: (Garment) -> Void
  @State private var search = ""
  @State private var importing = false

  var body: some View {
    NavigationStack {
      List {
        if garments.filter({ collection.matches($0) }).isEmpty {
          WearwiseEmptyState(title: collection == .wardrobe ? "No garments yet" : "No shopping items yet",
            systemImage: "tshirt", description: "Add an image to use it in your outfit.",
            actionTitle: "Import image", action: { importing = true })
        }
        ForEach(garments.filter { collection.matches($0, search: search) }) { garment in
          Button {
            onSelect(garment)
            dismiss()
          } label: {
            HStack {
              GarmentImageView(record: garment.cutoutAsset ?? garment.originalAsset).frame(
                width: 50, height: 60)
              VStack(alignment: .leading) {
                Text(garment.name)
                Text(garment.category).font(.caption).foregroundStyle(.secondary)
              }
            }
          }
          .foregroundStyle(.primary)
        }
      }
      .scrollDismissesKeyboard(.interactively).scrollContentBackground(.hidden)
          .background(Color.wardrobeBackground)
          .navigationTitle(collection.pickerTitle)
      .searchable(text: $search, prompt: "Find a garment")
      .labelStyle(.iconOnly)
            .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel", systemImage: "xmark") { dismiss() } }
        ToolbarItem(placement: .primaryAction) { Button("Import", systemImage: "photo.badge.plus") { importing = true } }
      }
      .sheet(isPresented: $importing) { ImportView(collection: collection) }
    }
  }
}

private enum EditorTool: String, Identifiable {
  case layers = "Layers"
  case diary = "Day and note"
  var id: String { rawValue }
}
