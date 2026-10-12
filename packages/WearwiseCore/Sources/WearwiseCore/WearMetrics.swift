import Foundation

public enum MetricsError: Error, Equatable {
    case negativePrice
    case negativeWearCount
    case negativeReference
    case futureStartDate
}

public enum ReferenceComparison: Equatable, Sendable {
    case below
    case equal
    case above
    case unavailable
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
        let total = openingWears + recordedWears
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

    public static func projectedCostPerWear(
        price: Decimal?,
        estimatedFutureWears: Int
    ) throws -> Decimal? {
        try costPerWear(price: price, wears: estimatedFutureWears)
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
        let anniversary = calendar.date(byAdding: .year, value: referenceYears, to: firstDay)!
        if lastDay < anniversary { return .below }
        if lastDay > anniversary { return .above }
        return .equal
    }
}
