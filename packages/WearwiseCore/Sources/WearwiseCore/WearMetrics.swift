import Foundation

public enum MetricsError: LocalizedError, Equatable {
    case negativePrice
    case negativeWearCount
    case negativeReference
    case futureStartDate
    case wearCountOverflow
    case invalidDateRange

    public var errorDescription: String? {
        switch self {
        case .negativePrice: "Enter an amount of zero or more."
        case .negativeWearCount: "Enter a wear count of zero or more."
        case .negativeReference: "Enter a reference value of zero or more."
        case .futureStartDate: "Choose a start date that is today or earlier."
        case .wearCountOverflow: "The total wear count is too large. Enter a smaller earlier count."
        case .invalidDateRange: "This date range cannot be calculated. Check the date and year reference."
        }
    }
}

public enum ReferenceComparison: Equatable, Sendable {
    case below
    case equal
    case above
    case unavailable
    case uncertain
}

public struct WearSummary: Equatable, Sendable {
    public let totalWears: Int
    public let estimatedWears: Int
    public let recordedWears: Int
    public let costPerWear: Decimal?
}

public enum WearMetrics {
    public static func costPerWear(price: Decimal?, wears: Int) throws -> Decimal? {
        guard wears >= 0 else { throw MetricsError.negativeWearCount }
        guard let price else { return nil }
        guard price >= 0 else { throw MetricsError.negativePrice }
        guard wears > 0 else { return nil }
        return price / Decimal(wears)
    }

    public static func summary(
        price: Decimal?,
        openingWears: Int,
        openingIsEstimated: Bool,
        recordedWears: Int
    ) throws -> WearSummary {
        guard openingWears >= 0, recordedWears >= 0 else {
            throw MetricsError.negativeWearCount
        }
        let addition = openingWears.addingReportingOverflow(recordedWears)
        guard !addition.overflow else { throw MetricsError.wearCountOverflow }
        let total = addition.partialValue
        return WearSummary(
            totalWears: total,
            estimatedWears: openingIsEstimated ? openingWears : 0,
            recordedWears: recordedWears,
            costPerWear: try costPerWear(price: price, wears: total)
        )
    }

    public static func compareCost(
        _ cost: Decimal?,
        reference: Decimal?
    ) throws -> ReferenceComparison {
        if let cost, cost < 0 { throw MetricsError.negativePrice }
        if let reference, reference < 0 { throw MetricsError.negativeReference }
        guard let cost, let reference else { return .unavailable }
        if cost < reference { return .below }
        if cost > reference { return .above }
        return .equal
    }

    public static func elapsedDays(
        from start: Date?,
        through end: Date,
        calendar: Calendar
    ) throws -> Int? {
        guard let start else { return nil }
        let firstDay = calendar.startOfDay(for: start)
        let lastDay = calendar.startOfDay(for: end)
        guard firstDay <= lastDay else { throw MetricsError.futureStartDate }
        return calendar.dateComponents([.day], from: firstDay, to: lastDay).day!
    }

    public static func compareDuration(
        from start: Date?,
        through end: Date,
        referenceYears: Int?,
        calendar: Calendar
    ) throws -> ReferenceComparison {
        if let referenceYears, referenceYears < 0 {
            throw MetricsError.negativeReference
        }
        guard let start, let referenceYears else { return .unavailable }
        let firstDay = calendar.startOfDay(for: start)
        let lastDay = calendar.startOfDay(for: end)
        guard firstDay <= lastDay else { throw MetricsError.futureStartDate }
        guard let anniversary = calendar.date(byAdding: .year, value: referenceYears, to: firstDay), anniversary >= firstDay else {
            throw MetricsError.invalidDateRange
        }
        if lastDay < anniversary { return .below }
        if lastDay > anniversary { return .above }
        return .equal
    }
}

public enum DatePrecision: String, CaseIterable, Sendable {
    case exact, month, year
}

public struct DurationEvidence: Equatable, Sendable {
    public let earliestStart: Date
    public let latestStart: Date
    public let minimumDays: Int
    public let maximumDays: Int
    public let comparison: ReferenceComparison
}

extension WearMetrics {
    public static func duration(
        from start: Date?, precision: DatePrecision, through end: Date,
        referenceYears: Int?, calendar: Calendar
    ) throws -> DurationEvidence? {
        if let referenceYears, referenceYears < 0 { throw MetricsError.negativeReference }
        guard let start else { return nil }
        let endDay = calendar.startOfDay(for: end)
        let earliest: Date
        let latest: Date
        if precision == .exact {
            earliest = calendar.startOfDay(for: start)
            latest = earliest
        } else {
            guard let interval = calendar.dateInterval(of: precision == .month ? .month : .year, for: start),
                  let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end) else {
                throw MetricsError.invalidDateRange
            }
            earliest = interval.start
            latest = min(lastDay, endDay)
        }
        guard earliest <= endDay else { throw MetricsError.futureStartDate }
        let minimum = try elapsedDays(from: latest, through: endDay, calendar: calendar)!
        let maximum = try elapsedDays(from: earliest, through: endDay, calendar: calendar)!
        let earliestComparison = try compareDuration(from: earliest, through: endDay, referenceYears: referenceYears, calendar: calendar)
        let latestComparison = try compareDuration(from: latest, through: endDay, referenceYears: referenceYears, calendar: calendar)
        return DurationEvidence(earliestStart: earliest, latestStart: latest, minimumDays: minimum, maximumDays: maximum,
                                comparison: earliestComparison == latestComparison ? earliestComparison : .uncertain)
    }
}
