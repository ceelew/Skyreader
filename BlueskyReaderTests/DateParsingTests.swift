import XCTest
@testable import BlueskyReader

final class DateParsingTests: XCTestCase {

    func testParsesISO8601WithFractionalSeconds() {
        let date = DateParsing.parse("2026-09-20T12:34:56.789Z")
        XCTAssertNotNil(date)

        let calendar = Calendar(identifier: .gregorian)
        var utcCalendar = calendar
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let components = utcCalendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date!)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 9)
        XCTAssertEqual(components.day, 20)
        XCTAssertEqual(components.hour, 12)
        XCTAssertEqual(components.minute, 34)
        XCTAssertEqual(components.second, 56)
    }

    func testParsesISO8601WithoutFractionalSeconds() {
        let date = DateParsing.parse("2026-09-20T12:34:56Z")
        XCTAssertNotNil(date)

        let calendar = Calendar(identifier: .gregorian)
        var utcCalendar = calendar
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let components = utcCalendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date!)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 9)
        XCTAssertEqual(components.day, 20)
        XCTAssertEqual(components.hour, 12)
        XCTAssertEqual(components.minute, 34)
        XCTAssertEqual(components.second, 56)
    }

    func testReturnsNilForGarbage() {
        XCTAssertNil(DateParsing.parse("not a date"))
    }

    func testReturnsNilForEmptyString() {
        XCTAssertNil(DateParsing.parse(""))
    }
}
