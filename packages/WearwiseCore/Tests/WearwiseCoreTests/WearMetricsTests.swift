import Foundation
import Testing
@testable import WearwiseCore

@Suite("Wear costs and calendar durations")
struct WearMetricsTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    @Test func knownPriceAndWears() throws {
        #expect(try WearMetrics.costPerWear(price: 120, wears: 12) == 10)
        #expect(try WearMetrics.costPerWear(price: Decimal(string: "99.99")!, wears: 3) == Decimal(string: "33.33")!)
    }

    @Test func zeroWearsAndUnknownPriceRemainUnavailable() throws {
        #expect(try WearMetrics.costPerWear(price: 120, wears: 0) == nil)
        #expect(try WearMetrics.costPerWear(price: nil, wears: 12) == nil)
        #expect(try WearMetrics.costPerWear(price: 0, wears: 12) == 0)
    }

    @Test func invalidValuesAreRejected() {
        #expect(throws: MetricsError.negativePrice) {
            try WearMetrics.costPerWear(price: -1, wears: 12)
        }
        #expect(throws: MetricsError.negativeWearCount) {
            try WearMetrics.costPerWear(price: 120, wears: -1)
        }
        #expect(throws: MetricsError.negativeWearCount) {
            try WearMetrics.costPerWear(price: nil, wears: -1)
        }
    }

    @Test func estimatedOpeningCountStaysIdentifiable() throws {
        let summary = try WearMetrics.summary(
            price: 100, openingWears: 20, openingIsEstimated: true, recordedWears: 5
        )
        #expect(summary.totalWears == 25)
        #expect(summary.estimatedWears == 20)
        #expect(summary.recordedWears == 5)
        #expect(summary.costPerWear == 4)
    }

    @Test func exactOpeningCountIsNotLabeledEstimated() throws {
        let summary = try WearMetrics.summary(
            price: 120, openingWears: 10, openingIsEstimated: false, recordedWears: 2
        )
        #expect(summary.totalWears == 12)
        #expect(summary.estimatedWears == 0)
    }

    @Test func referenceComparisonKeepsBoundaryDistinct() throws {
        #expect(try WearMetrics.compareCost(9, reference: 10) == .below)
        #expect(try WearMetrics.compareCost(10, reference: 10) == .equal)
        #expect(try WearMetrics.compareCost(11, reference: 10) == .above)
        #expect(try WearMetrics.compareCost(nil, reference: 10) == .unavailable)
        #expect(try WearMetrics.compareCost(10, reference: nil) == .unavailable)
    }

    @Test func comparisonUsesUnroundedCost() throws {
        let cost = try WearMetrics.costPerWear(price: 100, wears: 3)
        #expect(try WearMetrics.compareCost(cost, reference: Decimal(string: "33.33")!) == .above)
    }

    @Test func invalidReferencesAreRejected() {
        #expect(throws: MetricsError.negativeReference) {
            try WearMetrics.compareCost(nil, reference: -1)
        }
        #expect(throws: MetricsError.negativeReference) {
            try WearMetrics.compareDuration(from: nil, through: date(2026, 10, 12), referenceYears: -1, calendar: calendar)
        }
    }

    @Test func purchaseProjectionDoesNotChangeActualUse() throws {
        let actual = try WearMetrics.summary(
            price: 100, openingWears: 0, openingIsEstimated: false, recordedWears: 0
        )
        #expect(try WearMetrics.projectedCostPerWear(price: 100, estimatedFutureWears: 20) == 5)
        #expect(actual.totalWears == 0)
        #expect(actual.costPerWear == nil)
    }

    @Test func durationCountsCalendarDays() throws {
        #expect(try WearMetrics.elapsedDays(from: date(2024, 2, 28), through: date(2024, 3, 1), calendar: calendar) == 2)
        #expect(try WearMetrics.elapsedDays(from: date(2026, 10, 12, hour: 1), through: date(2026, 10, 12, hour: 23), calendar: calendar) == 0)
        #expect(try WearMetrics.elapsedDays(from: nil, through: date(2026, 10, 12), calendar: calendar) == nil)
    }

    @Test func futureStartDatesAreRejected() {
        #expect(throws: MetricsError.futureStartDate) {
            try WearMetrics.elapsedDays(from: date(2026, 10, 13), through: date(2026, 10, 12), calendar: calendar)
        }
    }

    @Test func leapYearAnniversaryUsesCalendar() throws {
        let start = date(2024, 2, 29)
        #expect(try WearMetrics.compareDuration(from: start, through: date(2025, 2, 27), referenceYears: 1, calendar: calendar) == .below)
        #expect(try WearMetrics.compareDuration(from: start, through: date(2025, 2, 28), referenceYears: 1, calendar: calendar) == .equal)
        #expect(try WearMetrics.compareDuration(from: start, through: date(2025, 3, 1), referenceYears: 1, calendar: calendar) == .above)
    }

    @Test func unknownDurationReferenceRemainsUnavailable() throws {
        #expect(try WearMetrics.compareDuration(from: nil, through: date(2026, 10, 12), referenceYears: 2, calendar: calendar) == .unavailable)
        #expect(try WearMetrics.compareDuration(from: date(2024, 10, 12), through: date(2026, 10, 12), referenceYears: nil, calendar: calendar) == .unavailable)
    }
}
