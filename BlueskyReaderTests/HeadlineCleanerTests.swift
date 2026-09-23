import XCTest
@testable import BlueskyReader

final class HeadlineCleanerTests: XCTestCase {
    func testStripsMatchingPublicationSuffix() {
        XCTAssertEqual(
            HeadlineCleaner.clean("DOJ lawyer wrote a paper - The Boston Globe", publication: "BostonGlobe.com"),
            "DOJ lawyer wrote a paper"
        )
    }

    func testStripsPipeSuffixMatchingHost() {
        XCTAssertEqual(
            HeadlineCleaner.clean("Big news | WIRED", publication: "Wired", host: "wired.com"),
            "Big news"
        )
    }

    func testKeepsUnrelatedSuffix() {
        XCTAssertEqual(
            HeadlineCleaner.clean("ALERTCalifornia - Mount McDill 2", publication: "ops.alertcalifornia.org"),
            "ALERTCalifornia - Mount McDill 2"
        )
    }

    func testNeverReturnsEmpty() {
        XCTAssertEqual(HeadlineCleaner.clean(" - The Verge", publication: "The Verge"), "- The Verge")
    }

    func testSquash() {
        XCTAssertEqual(HeadlineCleaner.squash("The Boston Globe"), "bostonglobe")
        XCTAssertEqual(HeadlineCleaner.squash("www.BostonGlobe.com"), "bostonglobe")
    }
}
