import SwiftUI
import SwiftData
import WearwiseCore

struct GarmentDestination: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var garments: [Garment]
    private let shopping: Bool

    init(id: UUID, shopping: Bool = false) {
        _garments = Query(filter: #Predicate<Garment> { $0.id == id })
        self.shopping = shopping
    }

    var body: some View {
        if let garment = garments.first, garment.modelContext != nil, !garment.isDeleted {
            if shopping { ShoppingDetailView(item: garment) }
            else { GarmentDetailView(garment: garment) }
        } else {
            Color.clear.task { dismiss() }
        }
    }
}

struct GarmentDetailView: View {
    @Environment(\.wearwiseCurrency) private var currency
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppFeedback.self) private var feedback
    @Bindable var garment: Garment
    @State private var editing = false
    @State private var draft: GarmentDraft
    private enum Confirmation { case discard, delete, retire }
    @State private var confirmation: Confirmation?
    @State private var errorText: String?

    private var canDelete: Bool { garment.openingWearCount == 0 && garment.outfits.isEmpty && garment.journalEntries.isEmpty && garment.wearRecords.isEmpty }

    init(garment: Garment, initiallyEditing: Bool = false) {
        self.garment = garment
        _draft = State(initialValue: GarmentDraft(garment))
        _editing = State(initialValue: initiallyEditing)
    }

    var body: some View {
        Group {
            if garment.modelContext != nil && !garment.isDeleted { details }
        }
    }

    private var details: some View {
        List {
            Section {
                GarmentImagePanel(garment: garment, allowsReplacement: editing)
            }
            GarmentEditFields(garment: garment, draft: $draft, editing: editing)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if editing {
                HStack {
                    Button { confirmation = .retire } label: {
                        Image(systemName: "archivebox").frame(width: 44, height: 44).contentShape(Rectangle())
                    }.accessibilityLabel("Retire garment").accessibilityIdentifier("garment.retire")
                    Spacer()
                    Button(role: .destructive) { confirmation = .delete } label: {
                        Image(systemName: "trash").frame(width: 44, height: 44).contentShape(Rectangle())
                    }.accessibilityLabel("Delete garment").accessibilityIdentifier("garment.delete")
                }.buttonStyle(.plain).labelStyle(.iconOnly).frame(minHeight: 44)
                .padding(.horizontal, 20).padding(.vertical, 8)
                .background(Color.paperSurface)
            }
        }
        .scrollDismissesKeyboard(.interactively).scrollContentBackground(.hidden)
        .background(Color.wardrobeBackground)
        .navigationTitle(garment.name)
        .navigationBarTitleDisplayMode(.inline).wearwiseKeyboardDismissal()
        .navigationBarBackButtonHidden(editing)
        .labelStyle(.iconOnly)
            .toolbar {
            if editing {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") {
                        if draft == GarmentDraft(garment) { editing = false } else { confirmation = .discard }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") {
                        do { draft.currency = currency; try GarmentStore(context: context).update(garment, draft: draft); editing = false }
                        catch { errorText = error.localizedDescription }
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } else {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit", systemImage: "pencil") { draft = GarmentDraft(garment); editing = true }
                }
            }
        }
        .wearwiseConfirmationToast(confirmationTitle,
            isPresented: .init(get: { confirmation != nil }, set: { if !$0 { confirmation = nil } }),
            message: confirmationMessage, onConfirm: confirm)
        .wearwiseErrorToast("Could not update garment", message: $errorText)
    }

    private var confirmationTitle: String {
        switch confirmation {
        case .discard: "Discard your changes?"
        case .delete: "Delete \(garment.name)?"
        case .retire: "Retire \(garment.name)?"
        case nil: ""
        }
    }

    private var confirmationMessage: String? {
        switch confirmation {
        case .delete: canDelete
            ? "This permanently removes the garment. This action cannot be undone."
            : "This removes the garment from your wardrobe. Saved outfits, journal images, and wearing history will remain."
        case .retire: "The garment will leave your wardrobe. Its saved images and history will remain."
        default: nil
        }
    }

    private func confirm() {
        switch confirmation {
        case .discard: editing = false
        case .delete:
            do {
                if canDelete { try GarmentStore(context: context).delete(garment) }
                else { try GarmentStore(context: context).retire(garment) }
                dismiss()
            } catch GarmentStoreError.assetCleanupFailed(let detail) {
                dismiss()
                feedback.message = GarmentStoreError.assetCleanupFailed(detail).localizedDescription
            } catch { errorText = error.localizedDescription }
        case .retire:
            do {
                try GarmentStore(context: context).retire(garment)
                dismiss()
            } catch { errorText = error.localizedDescription }
        case nil: break
        }
    }

}

struct GarmentImageView: View {
    private let assetID: UUID?
    private let imageURL: URL?
    @State private var image: UIImage?
    @State private var errorText: String?

    init(record: AssetRecord?) {
        assetID = record?.id
        imageURL = record.map { AssetStore.shared.url(for: $0) }
    }

    var body: some View {
        ZStack {
            Color.cutoutSurface
            Group {
                if let errorText {
                    Label(errorText, systemImage: "exclamationmark.triangle")
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                        .foregroundStyle(Color.primaryFill)
                } else if let image {
                    Image(uiImage: image).resizable().scaledToFit()
                } else {
                    Image(systemName: "photo").foregroundStyle(Color.primaryFill)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task(id: assetID) {
            image = nil
            errorText = nil
            guard let imageURL else { return }
            do {
                let data = try Data(contentsOf: imageURL)
                guard let decoded = UIImage(data: data) else { throw ImageImportError.undecodable }
                image = decoded
            } catch { errorText = "Image could not be loaded: \(error.localizedDescription)" }
        }
    }
}
