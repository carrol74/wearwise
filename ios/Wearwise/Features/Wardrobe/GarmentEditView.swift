import SwiftUI
import WearwiseCore

struct GarmentEditFields: View {
    @Environment(\.wearwiseCurrency) private var currency
    @Environment(\.wearwiseDefaults) private var defaults
    let garment: Garment
    @Binding var draft: GarmentDraft
    var editing = true

    var body: some View {
        Section("Attributes") {
            field("Name", value: garment.name) {
                TextField("Name", text: $draft.name).accessibilityIdentifier("garment.name")
            }
            field("Category", value: known(garment.category)) {
                GarmentCategoryPicker(selection: $draft.category).labelsHidden()
            }
            field("Brand", value: known(garment.brand)) {
                TextField("Brand", text: $draft.brand).multilineTextAlignment(.leading)
                    .accessibilityIdentifier("garment.brand")
            }
            field("Size", value: known(garment.size)) { TextField("Size", text: $draft.size) }
            field("Seasons", value: known(garment.seasons.map { $0.capitalized }.joined(separator: ", "))) {
                Menu {
                    ForEach(["spring", "summer", "autumn", "winter"], id: \.self) { season in
                        Toggle(season.capitalized, isOn: .init(get: { draft.seasons.contains(season) }, set: {
                            if $0 { draft.seasons.insert(season) } else { draft.seasons.remove(season) }
                        }))
                    }
                } label: { Text(draft.seasons.isEmpty ? "Unknown" : draft.seasons.sorted().map { $0.capitalized }.joined(separator: ", ")) }
                .menuActionDismissBehavior(.disabled)
            }
            field("Price", value: garment.amount.map { MoneyText.format($0, currency: currency) } ?? "Unknown") {
                TextField("Unknown", text: $draft.price).keyboardType(.decimalPad).accessibilityLabel("Price")
            }
            GarmentColorPicker(selection: editing ? $draft.colorTags : .constant(Set(garment.colorTags)), editing: editing)
            if garment.collection == .wardrobe {
                field("Condition", value: garment.condition.capitalized) {
                    Picker("Condition", selection: $draft.condition) {
                        ForEach(["unknown", "new", "good", "worn", "damaged"], id: \.self) { Text($0.capitalized).tag($0) }
                    }.labelsHidden()
                }
            }
        }
        if garment.collection == .wardrobe {
            Section("Wearing history") {
                field("Earlier wears", value: String(garment.openingWearCount)) {
                    TextField("Earlier wears", text: $draft.openingWearCount).keyboardType(.numberPad)
                }
                LabeledContent("Recorded wears", value: String(garment.wearRecords.count))
                switch Result(catching: { try WearMetrics.summary(price: garment.amount, openingWears: garment.openingWearCount,
                    openingIsEstimated: garment.openingWearIsEstimate, recordedWears: garment.wearRecords.count) }) {
                case .success(let summary):
                    LabeledContent(garment.openingWearIsEstimate ? "Estimated total wears" : "Total wears", value: String(summary.totalWears))
                    LabeledContent(garment.openingWearIsEstimate ? "Estimated cost per wear" : "Cost per wear", value: summary.costPerWear.map {
                        MoneyText.format($0, currency: currency)
                    } ?? "Unavailable")
                    if let reference = defaults.costReference, let cost = summary.costPerWear {
                        Text(cost < reference ? "Below your reference" : cost == reference ? "At your reference" : "Above your reference")
                            .foregroundStyle(Color.accentText)
                    }
                case .failure(let error): Text(error.localizedDescription).foregroundStyle(Color.accentText)
                }
            }
            if editing {
                Section("Dates") {
                    garmentDate("Acquired", date: $draft.acquisitionDate, precision: $draft.acquisitionPrecision)
                    garmentDate("First worn", date: $draft.firstUseDate, precision: $draft.firstUsePrecision)
                }
            } else if garment.acquisitionDate != nil || garment.firstUseDate != nil {
                Section("Time") {
                    if let date = garment.acquisitionDate {
                        LabeledContent("Owned for", value: durationLabel(date, precision: garment.acquisitionPrecision))
                    }
                    if let date = garment.firstUseDate {
                        LabeledContent("In use for", value: durationLabel(date, precision: garment.firstUsePrecision))
                    }
                }
            }
        }
        Section("Notes") {
            if editing { WearwiseNotesEditor(text: $draft.notes).accessibilityIdentifier("garment.notes") }
            else { Text(garment.notes.isEmpty ? "—" : garment.notes) }
        }
    }

    private func known(_ value: String) -> String { value.isEmpty ? "Unknown" : value }

    private func field<Content: View>(_ title: String, value: String, @ViewBuilder editor: () -> Content) -> some View {
        LabeledContent(title) {
            if editing { editor().multilineTextAlignment(.trailing) }
            else { Text(value).foregroundStyle(.secondary) }
        }.frame(minHeight: 32)
    }

    private func garmentDate(_ title: String, date: Binding<Date?>, precision: Binding<String>) -> some View {
        LabeledContent(title) {
            if let selected = date.wrappedValue {
                HStack {
                    DatePicker(title, selection: .init(get: { date.wrappedValue ?? selected }, set: { date.wrappedValue = $0 }), displayedComponents: .date).labelsHidden()
                    Menu {
                        Picker("Date accuracy", selection: precision) {
                            Text("Exact date").tag("exact")
                            Text("Month only").tag("month")
                            Text("Year only").tag("year")
                        }
                    } label: { Image(systemName: "slider.horizontal.3") }
                        .accessibilityLabel("\(title) date accuracy").accessibilityIdentifier("garment.dateAccuracy.\(title)")
                    Button("Clear date", systemImage: "xmark.circle") { date.wrappedValue = nil }.labelStyle(.iconOnly)
                }.buttonStyle(.borderless)
            } else {
                Button("Add date") { date.wrappedValue = Date() }
            }
        }.frame(minHeight: 32)
    }

    private func durationLabel(_ date: Date, precision: String) -> String {
        let label = elapsed(from: date)
        return precision == "exact" ? label : "About \(label)"
    }

    private func elapsed(from start: Date) -> String {
        if Calendar.current.isDateInToday(start) { return "0 days" }
        let formatter = DateComponentsFormatter()
        formatter.calendar = .current
        formatter.allowedUnits = [.year, .month, .day]
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 1
        return formatter.string(from: Calendar.current.startOfDay(for: start), to: Calendar.current.startOfDay(for: Date()))!
    }
}
