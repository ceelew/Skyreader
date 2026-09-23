import XCTest
@testable import BlueskyReader

final class LinkExtractorTests: XCTestCase {

    func testExternalEmbedWithTitle() throws {
        let post = try FixtureLoader.feedViewPost(named: "external_embed_with_title")
        let links = LinkExtractor.extract(from: post)

        XCTAssertEqual(links.count, 1)
        let link = try XCTUnwrap(links.first)
        XCTAssertEqual(link.originalURL, "https://www.nytimes.com/2026/09/20/some-article.html?utm_source=twitter")
        XCTAssertEqual(link.headlineFromEmbed, "Some Article Title")
        XCTAssertEqual(link.sharedByHandle, "alice.bsky.social")
        XCTAssertEqual(link.sharedByDisplayName, "Alice")
        XCTAssertEqual(link.postURI, "at://did:plc:author1/app.bsky.feed.post/1")
    }

    func testRecordWithMediaNestedExternalEmbed() throws {
        let post = try FixtureLoader.feedViewPost(named: "record_with_media_nested_external")
        let links = LinkExtractor.extract(from: post)

        XCTAssertEqual(links.count, 1)
        let link = try XCTUnwrap(links.first)
        XCTAssertEqual(link.originalURL, "https://www.theverge.com/2026/09/20/nested-external.html")
        XCTAssertEqual(link.headlineFromEmbed, "Nested External Title")
    }

    func testFacetOnlyLinkInPostText() throws {
        let post = try FixtureLoader.feedViewPost(named: "facet_only_link")
        let links = LinkExtractor.extract(from: post)

        XCTAssertEqual(links.count, 1)
        let link = try XCTUnwrap(links.first)
        XCTAssertEqual(link.originalURL, "https://www.wired.com/story/some-story/")
        XCTAssertNil(link.headlineFromEmbed)
        XCTAssertEqual(link.postText, "Read this: https://www.wired.com/story/some-story/")
    }

    func testBskyAppLinkIsSkipped() throws {
        let post = try FixtureLoader.feedViewPost(named: "bsky_app_link_skipped")
        let links = LinkExtractor.extract(from: post)
        XCTAssertTrue(links.isEmpty)
    }

    func testNonHTTPLinkIsSkipped() throws {
        let post = try FixtureLoader.feedViewPost(named: "non_http_link_skipped")
        let links = LinkExtractor.extract(from: post)
        XCTAssertTrue(links.isEmpty)
    }

    func testRepostUsesReasonIndexedAtAndReposterAsSharer() throws {
        let post = try FixtureLoader.feedViewPost(named: "repost")
        let links = LinkExtractor.extract(from: post)

        XCTAssertEqual(links.count, 1)
        let link = try XCTUnwrap(links.first)

        // Sharer should be the reposter (Grace), not the original author (Frank).
        XCTAssertEqual(link.sharedByHandle, "grace.bsky.social")
        XCTAssertEqual(link.sharedByDisplayName, "Grace")

        // appearedAt should come from reason.indexedAt (2026-09-21), not post.indexedAt (2026-09-19).
        let expected = DateParsing.parse("2026-09-21T09:30:00.000Z")
        XCTAssertEqual(link.appearedAt, expected)
    }

    func testPostWithNoLinksYieldsEmpty() throws {
        let post = try FixtureLoader.feedViewPost(named: "no_links")
        let links = LinkExtractor.extract(from: post)
        XCTAssertTrue(links.isEmpty)
    }
}
