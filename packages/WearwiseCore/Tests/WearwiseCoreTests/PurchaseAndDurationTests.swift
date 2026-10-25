import Foundation
import Testing
@testable import WearwiseCore

@Suite("Seasonal purchase inputs and date precision")
struct PurchaseAndDurationTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        return value
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    @Test func seasonalUnitsProduceAgreedWearCountsAndCosts() throws {
        let weekly = try PurchaseEstimate.wears(years: 3, seasonsPerYear: 2, frequency: 1, unit: .week)
        let monthly = try PurchaseEstimate.wears(years: 3, seasonsPerYear: 2, frequency: 1, unit: .month)
        let seasonal = try PurchaseEstimate.wears(years: 3, seasonsPerYear: 2, frequency: 1, unit: .season)
        #expect(weekly == 78)
        #expect(monthly == 18)
        #expect(seasonal == 6)
        #expect(try WearMetrics.costPerWear(price: 1490, wears: weekly)?.formatted(.number.locale(Locale(identifier: "en_US")).precision(.fractionLength(2))) == "19.10")
        #expect(try WearMetrics.costPerWear(price: 1490, wears: monthly)?.formatted(.number.locale(Locale(identifier: "en_US")).precision(.fractionLength(2))) == "82.78")
        #expect(try WearMetrics.costPerWear(price: 1490, wears: seasonal)?.formatted(.number.locale(Locale(identifier: "en_US")).precision(.fractionLength(2))) == "248.33")
        #expect(try PurchaseEstimate.wears(years: 1, seasonsPerYear: 4, frequency: 1, unit: .week) == 52)
        #expect(try PurchaseEstimate.wears(years: 1, seasonsPerYear: 4, frequency: 1, unit: .month) == 12)
    }

    @Test func invalidAssumptionsAndOverflowAreRejected() {
        #expect(throws: PurchaseEstimateError.invalidYears) { try PurchaseEstimate.wears(years: 0, seasonsPerYear: 2, frequency: 1, unit: .week) }
        #expect(throws: PurchaseEstimateError.invalidYears) { try PurchaseEstimate.wears(years: -1, seasonsPerYear: 2, frequency: 1, unit: .week) }
        #expect(throws: PurchaseEstimateError.invalidSeasons) { try PurchaseEstimate.wears(years: 1, seasonsPerYear: 5, frequency: 1, unit: .week) }
        #expect(throws: PurchaseEstimateError.invalidSeasons) { try PurchaseEstimate.wears(years: 1, seasonsPerYear: 0, frequency: 1, unit: .week) }
        #expect(throws: PurchaseEstimateError.invalidFrequency) { try PurchaseEstimate.wears(years: 1, seasonsPerYear: 1, frequency: 0, unit: .week) }
        #expect(throws: PurchaseEstimateError.overflow) { try PurchaseEstimate.wears(years: Int.max, seasonsPerYear: 4, frequency: 2, unit: .week) }
        #expect(throws: MetricsError.wearCountOverflow) { try WearMetrics.summary(price: 120, openingWears: Int.max, openingIsEstimated: true, recordedWears: 1) }
    }

    @Test func localizedAmountsPreserveUnknownAndZero() throws {
        #expect(try ValueInput.amount("  ") == nil)
        #expect(try ValueInput.amount("0") == 0)
        #expect(try ValueInput.amount(" 129,50 ", locale: Locale(identifier: "sv_SE")) == Decimal(string: "129.5"))
        #expect(try ValueInput.amount("129.50", locale: Locale(identifier: "en_US")) == Decimal(string: "129.5"))
        #expect(try ValueInput.amount("1,290.50", locale: Locale(identifier: "en_US")) == Decimal(string: "1290.5"))
        #expect(try ValueInput.currency(" sek ") == "SEK")
    }

    @Test(arguments: ["-1", "abc", "12abc", "12.30.40", "NaN", "∞"])
    func invalidAmountsAreRejectedEntirely(_ input: String) {
        #expect(throws: (any Error).self) { try ValueInput.amount(input, locale: Locale(identifier: "en_US")) }
    }

    @Test(arguments: ["", "12", "123", "EURO", "S€K"])
    func malformedCurrencyIsRejected(_ input: String) {
        #expect(throws: (any Error).self) { try ValueInput.currency(input) }
    }

    @Test func monthRangeKeepsAnAmbiguousAnniversary() throws {
        let value = try #require(try WearMetrics.duration(from: date(2024, 3, 18), precision: .month, through: date(2026, 3, 15), referenceYears: 2, calendar: calendar))
        #expect(value.earliestStart == calendar.startOfDay(for: date(2024, 3, 1)))
        #expect(value.latestStart == calendar.startOfDay(for: date(2024, 3, 31)))
        #expect(value.comparison == .uncertain)
        #expect(value.maximumDays - value.minimumDays == 30)
    }

    @Test func fullYearPrecisionAndKnownBoundaries() throws {
        let before = try #require(try WearMetrics.duration(from: date(2024, 6, 10), precision: .year, through: date(2025, 12, 31), referenceYears: 2, calendar: calendar))
        #expect(before.comparison == .below)
        let after = try #require(try WearMetrics.duration(from: date(2024, 6, 10), precision: .year, through: date(2027, 1, 1), referenceYears: 2, calendar: calendar))
        #expect(after.comparison == .above)
        #expect(after.maximumDays - after.minimumDays == 365)
    }

    @Test func currentPartialPeriodExcludesFutureDates() throws {
        let value = try #require(try WearMetrics.duration(from: date(2026, 10, 28), precision: .month, through: date(2026, 10, 15), referenceYears: 1, calendar: calendar))
        #expect(value.minimumDays == 0)
        #expect(value.maximumDays == 14)
        #expect(value.comparison == .below)
    }

    @Test func exactDateUsesCalendarAcrossDSTAndLeapDay() throws {
        let dst = try #require(try WearMetrics.duration(from: date(2026, 3, 28), precision: .exact, through: date(2026, 3, 30), referenceYears: nil, calendar: calendar))
        #expect(dst.minimumDays == 2)
        #expect(dst.maximumDays == 2)
        let leap = try #require(try WearMetrics.duration(from: date(2024, 2, 29), precision: .exact, through: date(2025, 2, 28), referenceYears: 1, calendar: calendar))
        #expect(leap.comparison == .equal)
    }

    @Test func unknownAndInvalidDurationInputsStayExplicit() throws {
        #expect(try WearMetrics.duration(from: nil, precision: .year, through: date(2026, 10, 15), referenceYears: 2, calendar: calendar) == nil)
        #expect(throws: MetricsError.futureStartDate) { try WearMetrics.duration(from: date(2027, 1, 1), precision: .year, through: date(2026, 10, 15), referenceYears: nil, calendar: calendar) }
        #expect(throws: MetricsError.negativeReference) { try WearMetrics.duration(from: nil, precision: .exact, through: date(2026, 10, 15), referenceYears: -1, calendar: calendar) }
    }
}
