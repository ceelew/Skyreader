import XCTest
@testable import BlueskyReader

final class URLNormalizerTests: XCTestCase {

    // MARK: - Tracking param stripping

    func testStripsUTMParams() {
        let normalized = URLNormalizer.normalize("https://example.com/article?utm_source=twitter&utm_medium=social&id=42")
        XCTAssertEqual(normalized, "https://example.com/article?id=42")
    }

    func testStripsKnownTrackingParamNames() {
        let normalized = URLNormalizer.normalize("https://example.com/article?fbclid=abc123&gclid=xyz&ref=homepage&id=42")
        XCTAssertEqual(normalized, "https://example.com/article?id=42")
    }

    func testStripsAllTrackingParamsLeavesNoQuery() {
        let normalized = URLNormalizer.normalize("https://example.com/article?utm_source=twitter&fbclid=abc")
        XCTAssertEqual(normalized, "https://example.com/article")
    }

    func testSortsRemainingQueryItems() {
        let normalized = URLNormalizer.normalize("https://example.com/article?zeta=1&alpha=2&utm_source=x")
        XCTAssertEqual(normalized, "https://example.com/article?alpha=2&zeta=1")
    }

    // MARK: - Host normalization

    func testStripsWWWPrefix() {
        XCTAssertEqual(URLNormalizer.normalize("https://www.nytimes.com/article"), "https://nytimes.com/article")
    }

    func testStripsMPrefix() {
        XCTAssertEqual(URLNormalizer.normalize("https://m.wikipedia.org/wiki/Cat"), "https://wikipedia.org/wiki/cat")
    }

    func testStripsAmpPrefix() {
        XCTAssertEqual(URLNormalizer.normalize("https://amp.example.com/story"), "https://example.com/story")
    }

    func testLowercasesHost() {
        XCTAssertEqual(URLNormalizer.normalize("https://EXAMPLE.com/Path"), "https://example.com/path")
    }

    // MARK: - Fragment handling

    func testStripsFragment() {
        XCTAssertEqual(URLNormalizer.normalize("https://example.com/article#section-2"), "https://example.com/article")
    }

    func testStripsFragmentWithQuery() {
        XCTAssertEqual(URLNormalizer.normalize("https://example.com/article?id=1#top"), "https://example.com/article?id=1")
    }

    // MARK: - Trailing slash

    func testStripsTrailingSlash() {
        XCTAssertEqual(URLNormalizer.normalize("https://example.com/article/"), "https://example.com/article")
    }

    func testKeepsRootSlash() {
        XCTAssertEqual(URLNormalizer.normalize("https://example.com/"), "https://example.com/")
    }

    // MARK: - Idempotence

    func testIdempotentOnAlreadyNormalizedURL() {
        let once = URLNormalizer.normalize("https://www.example.com/article/?utm_source=x&id=1#frag")
        let twice = URLNormalizer.normalize(once)
        XCTAssertEqual(once, twice)
    }

    func testIdempotentAcrossVariousInputs() {
        let inputs = [
            "https://EXAMPLE.com/a/b/",
            "https://m.example.com/story?ref=abc",
            "https://example.com/no-query-or-fragment",
        ]
        for input in inputs {
            let normalized = URLNormalizer.normalize(input)
            XCTAssertEqual(normalized, URLNormalizer.normalize(normalized), "not idempotent for \(input)")
        }
    }

    // MARK: - host(of:) and strippingPrefixes

    func testHostOfStripsPrefixesAndLowercases() {
        XCTAssertEqual(URLNormalizer.host(of: "https://WWW.Example.com/path"), "example.com")
    }

    func testHostOfReturnsNilForInvalidURL() {
        XCTAssertNil(URLNormalizer.host(of: "not a url"))
    }

    func testStrippingPrefixesOnlyStripsOnePrefix() {
        // "www.m.example.com" -> strips only the leading "www." per the documented behavior.
        XCTAssertEqual(URLNormalizer.strippingPrefixes(from: "www.m.example.com"), "m.example.com")
    }

    // MARK: - isShortener

    func testIsShortenerRecognizesKnownShorteners() {
        XCTAssertTrue(URLNormalizer.isShortener(host: "bit.ly"))
        XCTAssertTrue(URLNormalizer.isShortener(host: "www.bit.ly"))
    }

    func testIsShortenerFalseForRegularHost() {
        XCTAssertFalse(URLNormalizer.isShortener(host: "nytimes.com"))
    }
}
