import XCTest
@testable import BlueskyReader

final class PublicationMapperTests: XCTestCase {

    func testKnownOutletMapping() {
        XCTAssertEqual(PublicationMapper.publication(ogSiteName: nil, finalURLHost: "nytimes.com"), "The New York Times")
        XCTAssertEqual(PublicationMapper.publication(ogSiteName: nil, finalURLHost: "theverge.com"), "The Verge")
        XCTAssertEqual(PublicationMapper.publication(ogSiteName: nil, finalURLHost: "bbc.co.uk"), "BBC")
    }

    func testOGSiteNameWinsOverKnownMapping() {
        XCTAssertEqual(
            PublicationMapper.publication(ogSiteName: "Custom Name", finalURLHost: "nytimes.com"),
            "Custom Name"
        )
    }

    func testBlankOGSiteNameFallsBackToMapping() {
        XCTAssertEqual(
            PublicationMapper.publication(ogSiteName: "   ", finalURLHost: "nytimes.com"),
            "The New York Times"
        )
    }

    func testUnknownHostFallsBackToBareHost() {
        XCTAssertEqual(
            PublicationMapper.publication(ogSiteName: nil, finalURLHost: "some-unknown-blog.example"),
            "some-unknown-blog.example"
        )
    }

    // Note: PublicationMapper.publication expects the host to already have
    // www./m./amp. stripped (that's URLNormalizer's job). We verify the
    // integration here: stripping happens before lookup.
    func testWWWStrippingHappensBeforeLookup() {
        let strippedHost = URLNormalizer.strippingPrefixes(from: "www.nytimes.com")
        XCTAssertEqual(
            PublicationMapper.publication(ogSiteName: nil, finalURLHost: strippedHost),
            "The New York Times"
        )
    }

    func testMPrefixStrippingHappensBeforeLookup() {
        let strippedHost = URLNormalizer.strippingPrefixes(from: "m.espn.com")
        XCTAssertEqual(
            PublicationMapper.publication(ogSiteName: nil, finalURLHost: strippedHost),
            "ESPN"
        )
    }

    func testAmpPrefixStrippingHappensBeforeLookup() {
        let strippedHost = URLNormalizer.strippingPrefixes(from: "amp.reuters.com")
        XCTAssertEqual(
            PublicationMapper.publication(ogSiteName: nil, finalURLHost: strippedHost),
            "Reuters"
        )
    }
}
