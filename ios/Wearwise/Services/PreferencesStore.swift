import Foundation
import WearwiseCore

struct WardrobeDefaults: Codable, Equatable, Sendable {
    var currency = ""
    var costReference: Decimal?
    var yearReference: Int?

    func validate() throws {
        if !currency.isEmpty { _ = try ValueInput.currency(currency) }
        if let costReference, costReference < 0 { throw MetricsError.negativeReference }
        if let yearReference, yearReference < 0 { throw MetricsError.negativeReference }
    }

    func applyToNewGarment(_ garment: Garment, collection: GarmentCollection) {
        garment.currency = currency
        if collection == .wardrobe {
            garment.costReference = costReference
            garment.durationReferenceYears = yearReference
        }
    }
}

struct PreferencesDraft: Equatable {
    var currency: String
    var costReference: String
    var yearReference: String

    init(_ defaults: WardrobeDefaults = WardrobeDefaults()) {
        currency = defaults.currency
        costReference = defaults.costReference?.formatted(.number.precision(.fractionLength(0...38)).grouping(.never)) ?? ""
        yearReference = defaults.yearReference.map(String.init) ?? ""
    }

    func values() throws -> WardrobeDefaults {
        let amount = try ValueInput.amount(costReference)
        let code = currency.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanYears = yearReference.trimmingCharacters(in: .whitespacesAndNewlines)
        let years: Int?
        if cleanYears.isEmpty { years = nil }
        else {
            guard let value = Int(cleanYears), value >= 0 else { throw ValueInputError.invalidReferenceYears }
            years = value
        }
        let defaults = WardrobeDefaults(currency: code.isEmpty ? "" : try ValueInput.currency(code),
            costReference: amount, yearReference: years)
        try defaults.validate()
        return defaults
    }
}

struct PreferencesStore {
    var fileURL = URL.applicationSupportDirectory.appending(path: "WearwiseDefaults.json")

    func load() throws -> WardrobeDefaults {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return WardrobeDefaults() }
        let defaults = try JSONDecoder().decode(WardrobeDefaults.self, from: Data(contentsOf: fileURL))
        try defaults.validate()
        return defaults
    }

    func save(_ draft: PreferencesDraft) throws {
        let values = try draft.values()
        let data = try JSONEncoder().encode(values)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
        NotificationCenter.default.post(name: .wearwiseDefaultsChanged, object: nil)
    }
}

struct CurrencyOption: Identifiable, Sendable {
    let code: String
    let name: String
    let localizedName: String
    var id: String { code }
    static let all = catalog()

    static func catalog(locale: Locale = .current) -> [CurrencyOption] {
        let english = Locale(identifier: "en")
        return Locale.commonISOCurrencyCodes.sorted().map { code in
                CurrencyOption(code: code, name: english.localizedString(forCurrencyCode: code) ?? code,
                    localizedName: locale.localizedString(forCurrencyCode: code) ?? code)
            }
    }

    func matches(_ query: String) -> Bool {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return search.isEmpty || [code, name, localizedName].contains { $0.localizedStandardContains(search) }
    }
}
