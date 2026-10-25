import SwiftUI
import WearwiseCore

struct PurchaseCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    let garment: Garment
    @State private var draft: PurchaseDraft
    @Environment(\.wearwiseCurrency) private var currency
    @FocusState private var focusedField: String?

    init(garment: Garment) {
        self.garment = garment
        _draft = State(initialValue: PurchaseDraft(garment: garment))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 16) {
                        GarmentImageView(record: garment.cutoutAsset ?? garment.originalAsset)
                            .frame(width: 64, height: 84)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(garment.name).font(.headline)
                            if !garment.brand.isEmpty { Text(garment.brand).foregroundStyle(.secondary) }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(18)
                    .background(Color.imageMount, in: RoundedRectangle(cornerRadius: WearwiseRadius.medium, style: .continuous))
                    VStack(alignment: .leading, spacing: 16) {
                        field("Price", text: $draft.price, identifier: "purchase.price", keyboard: .decimalPad)
                        field("Years of use", text: $draft.years, identifier: "purchase.years")
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Seasons per year").font(.subheadline.weight(.medium))
                            Picker("Seasons per year", selection: $draft.seasonsPerYear) {
                                ForEach(1...4, id: \.self) { Text(String($0)).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .accessibilityIdentifier("purchase.seasons")
                        }
                        field("Wears per \(draft.unit.rawValue)", text: $draft.frequency, identifier: "purchase.frequency")
                        Picker("Frequency unit", selection: $draft.unit) {
                            Text("Week").tag(WearingFrequencyUnit.week)
                            Text("Month").tag(WearingFrequencyUnit.month)
                            Text("Season").tag(WearingFrequencyUnit.season)
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("purchase.unit")
                    }
                    result

                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.wardrobeBackground)
            .navigationTitle("Worth a wear?")
            .navigationBarTitleDisplayMode(.inline).wearwiseKeyboardDismissal()
            .labelStyle(.iconOnly)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark") { dismiss() } }
            }
            .onAppear { draft.currency = currency }
            .onChange(of: currency) { draft.currency = currency }
        }
    }

    private func field(_ title: String, text: Binding<String>, identifier: String, keyboard: UIKeyboardType = .numberPad) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.weight(.medium))
            TextField(title, text: text)
                .focused($focusedField, equals: identifier)
                .keyboardType(keyboard).autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
                .padding(12).frame(minHeight: 48)
                .background(Color.paperSurface, in: RoundedRectangle(cornerRadius: WearwiseRadius.small, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: WearwiseRadius.small, style: .continuous)
                        .strokeBorder(focusedField == identifier ? Color.wearwiseBlue : Color.subtleBorder)
                }
                .overlay {
                    if focusedField == identifier {
                        RoundedRectangle(cornerRadius: WearwiseRadius.small + 3, style: .continuous)
                            .stroke(Color.accentSurface, lineWidth: 3).padding(-3)
                    }
                }
                .accessibilityIdentifier(identifier)
        }
    }

    private var result: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Estimated cost per wear").font(.subheadline)
            switch Result(catching: { try draft.preview() }) {
            case .success(let result):
                if let result {
                    Text(result.cost.map { MoneyText.format($0, currency: currency) } ?? "Price unknown")
                        .font(.title.weight(.semibold)).accessibilityIdentifier("purchase.result")
                    Text("\(result.wears) estimated wears").accessibilityIdentifier("purchase.wears")
                } else { Text("—").font(.largeTitle.weight(.semibold)) }
            case .failure(let error):
                Text(error.localizedDescription).foregroundStyle(Color.accentText).accessibilityIdentifier("purchase.error")
            }
        }
        .foregroundStyle(Color.accentText)
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentSurface, in: RoundedRectangle(cornerRadius: WearwiseRadius.large, style: .continuous))
        .wearwiseShadow()
        .accessibilityElement(children: .contain)
    }
}
