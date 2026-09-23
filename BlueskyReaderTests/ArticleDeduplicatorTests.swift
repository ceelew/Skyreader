import XCTest
@testable import BlueskyReader

private struct TestArticle: DedupableArticle {
    let headline: String
    let publication: String
    let originalURL: String
}

final class ArticleDeduplicatorTests: XCTestCase {

    func testDistinctArticlesSameHostBothPlaceholdersAreBothKept() {
        // Two unresolved headlines that both fell back to the bare host — must not
        // collapse into one, since they're almost certainly different articles.
        let a = TestArticle(headline: "example.com", publication: "example.com", originalURL: "https://example.com/article-a")
        let b = TestArticle(headline: "example.com", publication: "example.com", originalURL: "https://example.com/article-b")

        let result = ArticleDeduplicator.dedupe([a, b])

        XCTAssertEqual(result.count, 2)
    }

    func testSameHeadlineDifferentPublicationsAreBothKept() {
        let a = TestArticle(headline: "Big News Today", publication: "The Times", originalURL: "https://times.example/a")
        let b = TestArticle(headline: "Big News Today", publication: "The Post", originalURL: "https://post.example/b")

        let result = ArticleDeduplicator.dedupe([a, b])

        XCTAssertEqual(result.count, 2)
    }

    func testSameHeadlineSamePublicationKeepsNewestOnly() {
        // Input is newest-first.
        let newest = TestArticle(headline: "Big News Today", publication: "The Times", originalURL: "https://times.example/newest")
        let older = TestArticle(headline: "big news today", publication: "the times", originalURL: "https://times.example/older")

        let result = ArticleDeduplicator.dedupe([newest, older])

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.originalURL, "https://times.example/newest")
    }

    func testEmptyHeadlineIsTreatedAsPlaceholder() {
        let a = TestArticle(headline: "", publication: "example.com", originalURL: "https://example.com/a")
        let b = TestArticle(headline: "", publication: "example.com", originalURL: "https://example.com/b")

        let result = ArticleDeduplicator.dedupe([a, b])

        XCTAssertEqual(result.count, 2)
    }

    func testJunkTitlesAreNeverCollapsed() {
        let a = TestArticle(headline: "Just a moment...", publication: "example.com", originalURL: "https://example.com/a")
        let b = TestArticle(headline: "JUST A MOMENT...", publication: "example.com", originalURL: "https://example.com/b")

        let result = ArticleDeduplicator.dedupe([a, b])

        XCTAssertEqual(result.count, 2)
    }

    func testHeadlineEqualToPublicationIsTreatedAsPlaceholder() {
        let a = TestArticle(headline: "The Times", publication: "The Times", originalURL: "https://times.example/a")
        let b = TestArticle(headline: "The Times", publication: "The Times", originalURL: "https://times.example/b")

        let result = ArticleDeduplicator.dedupe([a, b])

        XCTAssertEqual(result.count, 2)
    }

    func testRealDuplicateAcrossDifferentURLsCollapses() {
        // Same publication + headline via two different normalized URLs (e.g. a
        // shortener resolved on one share and not the other) — this is the case
        // dedup exists for.
        let newest = TestArticle(headline: "A Real Headline", publication: "Example Times", originalURL: "https://example.com/story")
        let older = TestArticle(headline: "A Real Headline", publication: "Example Times", originalURL: "https://bit.ly/xyz")

        let result = ArticleDeduplicator.dedupe([newest, older])

        XCTAssertEqual(result.count, 1)
    }
}
