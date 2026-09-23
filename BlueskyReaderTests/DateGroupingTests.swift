import XCTest
@testable import BlueskyReader

final class DateGroupingTests: XCTestCase {
    private var calendar: Calendar!
    private var now: Date!

    override func setUp() {
        super.setUp()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        calendar = cal
        // Fixed "now": 2026-09-23T12:00:00Z
        now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 12))!
    }

    func testToday() {
        let date = calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 8))!
        XCTAssertEqual(DateGrouping.sectionLabel(for: date, calendar: calendar, now: now), "Today")
    }

    func testYesterday() {
        let date = calendar.date(from: DateComponents(year: 2026, month: 9, day: 22, hour: 20))!
        XCTAssertEqual(DateGrouping.sectionLabel(for: date, calendar: calendar, now: now), "Yesterday")
    }

    func testOlderDateSameYearOmitsYear() {
        let date = calendar.date(from: DateComponents(year: 2026, month: 8, day: 8, hour: 10))!
        XCTAssertEqual(DateGrouping.sectionLabel(for: date, calendar: calendar, now: now), "Saturday, August 8")
    }

    func testOlderDateDifferentYearIncludesYear() {
        let date = calendar.date(from: DateComponents(year: 2025, month: 8, day: 8, hour: 10))!
        XCTAssertEqual(DateGrouping.sectionLabel(for: date, calendar: calendar, now: now), "Friday, August 8, 2025")
    }

    func testDayKeyBucketsSameDayDifferentTimes() {
        let morning = calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 6))!
        let evening = calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 23))!
        XCTAssertEqual(
            DateGrouping.dayKey(for: morning, calendar: calendar),
            DateGrouping.dayKey(for: evening, calendar: calendar)
        )
    }

    func testDayKeyDiffersAcrossDays() {
        let day1 = calendar.date(from: DateComponents(year: 2026, month: 9, day: 22, hour: 23))!
        let day2 = calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 1))!
        XCTAssertNotEqual(
            DateGrouping.dayKey(for: day1, calendar: calendar),
            DateGrouping.dayKey(for: day2, calendar: calendar)
        )
    }

    func testDayKeyIsStartOfDay() {
        let date = calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 15, minute: 30))!
        let expected = calendar.startOfDay(for: date)
        XCTAssertEqual(DateGrouping.dayKey(for: date, calendar: calendar), expected)
    }
}
