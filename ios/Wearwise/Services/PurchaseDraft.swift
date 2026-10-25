import Foundation
import WearwiseCore

struct PurchaseDraft {
    var price: String
    var currency: String
    var years = ""
    var seasonsPerYear = 2
    var frequency = ""
    var unit: WearingFrequencyUnit = .week

    init(garment: Garment) {
        price = garment.amount?.formatted(.number.precision(.fractionLength(0...38)).grouping(.never)) ?? ""
        currency = garment.currency
    }

    func estimatedWears() throws -> Int {
        try PurchaseEstimate.wears(years: positive(years, error: .invalidYears), seasonsPerYear: seasonsPerYear,
            frequency: positive(frequency, error: .invalidFrequency), unit: unit)
    }

    func costPerWear() throws -> Decimal? {
        let count = try estimatedWears()
        let amount = try ValueInput.amount(price)
        if !currency.isEmpty { _ = try ValueInput.currency(currency) }
        return try WearMetrics.costPerWear(price: amount, wears: count)
    }

    func preview() throws -> (wears: Int, cost: Decimal?)? {
        let hasYears = !years.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasFrequency = !frequency.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hasYears { _ = try positive(years, error: .invalidYears) }
        if hasFrequency { _ = try positive(frequency, error: .invalidFrequency) }
        guard (1...4).contains(seasonsPerYear) else { throw PurchaseEstimateError.invalidSeasons }
        let amount = try ValueInput.amount(price)
        if !currency.isEmpty { _ = try ValueInput.currency(currency) }
        guard hasYears, hasFrequency else { return nil }
        let wears = try estimatedWears()
        return (wears, try WearMetrics.costPerWear(price: amount, wears: wears))
    }

    private func positive(_ text: String, error: PurchaseEstimateError) throws -> Int {
        guard let value = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)), value > 0 else { throw error }
        return value
    }
}
