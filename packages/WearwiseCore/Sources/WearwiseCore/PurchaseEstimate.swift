import Foundation

public enum WearingFrequencyUnit: String, CaseIterable, Sendable {
    case week, month, season

    public var occurrencesPerSeason: Int {
        switch self {
        case .week: 13
        case .month: 3
        case .season: 1
        }
    }
}

public enum PurchaseEstimateError: LocalizedError, Equatable {
    case invalidYears, invalidSeasons, invalidFrequency, overflow

    public var errorDescription: String? {
        switch self {
        case .invalidYears: "Enter a whole number greater than zero for years of use."
        case .invalidSeasons: "Choose one to four seasons per year."
        case .invalidFrequency: "Enter a whole number greater than zero for wearing frequency."
        case .overflow: "These assumptions produce too many wears. Enter smaller values."
        }
    }
}

public enum PurchaseEstimate {
    public static func wears(years: Int, seasonsPerYear: Int, frequency: Int, unit: WearingFrequencyUnit) throws -> Int {
        guard years > 0 else { throw PurchaseEstimateError.invalidYears }
        guard (1...4).contains(seasonsPerYear) else { throw PurchaseEstimateError.invalidSeasons }
        guard frequency > 0 else { throw PurchaseEstimateError.invalidFrequency }
        var total = years
        for factor in [seasonsPerYear, frequency, unit.occurrencesPerSeason] {
            let result = total.multipliedReportingOverflow(by: factor)
            guard !result.overflow else { throw PurchaseEstimateError.overflow }
            total = result.partialValue
        }
        return total
    }
}

public enum ValueInputError: LocalizedError {
    case invalidAmount, invalidCurrency, invalidReferenceYears

    public var errorDescription: String? {
        switch self {
        case .invalidAmount: "Enter an amount of zero or more, or leave it empty if unknown."
        case .invalidCurrency: "Enter a three-letter currency code, such as SEK, EUR, or CNY."
        case .invalidReferenceYears: "Enter a whole number of zero or more for the year reference, or leave it empty."
        }
    }
}

public enum ValueInput {
    public static func amount(_ text: String, locale: Locale = .current) throws -> Decimal? {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        guard let parsed = try Decimal.FormatStyle.number.locale(locale).consuming(clean, startingAt: clean.startIndex, in: clean.startIndex..<clean.endIndex),
              parsed.upperBound == clean.endIndex, parsed.output >= 0 else {
            throw ValueInputError.invalidAmount
        }
        return parsed.output
    }

    public static func currency(_ text: String) throws -> String {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard clean.utf8.count == 3, clean.utf8.allSatisfy({ (65...90).contains($0) }) else {
            throw ValueInputError.invalidCurrency
        }
        return clean
    }
}
