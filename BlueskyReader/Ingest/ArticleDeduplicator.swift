import Foundation

/// The minimal surface `ArticleDeduplicator` needs. Kept as a protocol (rather than
/// operating on `LinkItem` directly) so it can be unit tested with plain structs and
/// doesn't need a ModelContainer.
protocol DedupableArticle {
    var headline: String { get }
    var publication: String { get }
    var originalURL: String { get }
}

extension LinkItem: DedupableArticle {}

/// Collapses `LinkItem`s that represent the same article under different normalized
/// URLs (e.g. a shortener resolved on one share but not another), while never
/// collapsing items whose headline is a failed-resolution placeholder — those are
/// almost certainly distinct articles that happen to share a domain.
enum ArticleDeduplicator {
    /// Generic titles a page can return instead of a real headline (bot walls,
    /// interstitials, missing-page pages). Shared with HeadlineResolver, which treats
    /// a fetched title matching this set as a failed fetch.
    static let junkTitles: Set<String> = [
        "home", "just a moment...", "access denied", "attention required!",
        "403 forbidden", "404 not found", "page not found", "untitled",
    ]

    /// Keeps the newest occurrence (input order is assumed newest-first) of each
    /// (publication, headline) pair, except placeholder/junk headlines, which are
    /// always kept since collapsing them would hide distinct articles.
    static func dedupe<T: DedupableArticle>(_ items: [T]) -> [T] {
        var seenKeys = Set<String>()
        var result: [T] = []
        for item in items {
            guard !isPlaceholderOrJunk(item) else {
                result.append(item)
                continue
            }
            guard seenKeys.insert(dedupKey(for: item)).inserted else { continue }
            result.append(item)
        }
        return result
    }

    static func dedupKey<T: DedupableArticle>(for item: T) -> String {
        let publication = item.publication.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let headline = item.headline.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return publication + "\u{1F}" + headline
    }

    static func isPlaceholderOrJunk<T: DedupableArticle>(_ item: T) -> Bool {
        let headline = item.headline.trimmingCharacters(in: .whitespacesAndNewlines)
        if headline.isEmpty { return true }

        let lowerHeadline = headline.lowercased()
        if junkTitles.contains(lowerHeadline) { return true }

        let publication = item.publication.trimmingCharacters(in: .whitespacesAndNewlines)
        if lowerHeadline == publication.lowercased() { return true }

        if let host = URLNormalizer.host(of: item.originalURL), lowerHeadline == host.lowercased() {
            return true
        }

        return false
    }
}
