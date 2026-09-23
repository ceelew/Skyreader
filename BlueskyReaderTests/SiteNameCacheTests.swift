import XCTest
@testable import BlueskyReader

final class SiteNameCacheTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "SiteNameCacheTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testUnknownHostHasNoSiteNameAndIsNotTried() {
        let cache = SiteNameCache(defaults: defaults)
        XCTAssertNil(cache.siteName(forHost: "example.com"))
        XCTAssertFalse(cache.hasTried(host: "example.com"))
    }

    func testRecordStoresSiteNameAndMarksTried() {
        let cache = SiteNameCache(defaults: defaults)
        cache.record(siteName: "Example Times", forHost: "example.com")

        XCTAssertEqual(cache.siteName(forHost: "example.com"), "Example Times")
        XCTAssertTrue(cache.hasTried(host: "example.com"))
    }

    func testMarkTriedWithoutSiteNameLeavesSiteNameNilButTried() {
        let cache = SiteNameCache(defaults: defaults)
        cache.markTried(host: "example.com")

        XCTAssertNil(cache.siteName(forHost: "example.com"))
        XCTAssertTrue(cache.hasTried(host: "example.com"))
    }

    func testValuesPersistAcrossInstancesSharingDefaults() {
        let first = SiteNameCache(defaults: defaults)
        first.record(siteName: "Example Times", forHost: "example.com")

        let second = SiteNameCache(defaults: defaults)
        XCTAssertEqual(second.siteName(forHost: "example.com"), "Example Times")
        XCTAssertTrue(second.hasTried(host: "example.com"))
    }

    func testDifferentHostsAreIndependent() {
        let cache = SiteNameCache(defaults: defaults)
        cache.record(siteName: "Example Times", forHost: "example.com")

        XCTAssertNil(cache.siteName(forHost: "other.com"))
        XCTAssertFalse(cache.hasTried(host: "other.com"))
    }
}
