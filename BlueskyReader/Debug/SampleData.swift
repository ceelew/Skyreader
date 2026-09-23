#if DEBUG
import Foundation
import SwiftData

/// Seeds a fixed reading list for UI checks without a Bluesky account.
/// Launch with the `-SeedSampleData` argument (Debug builds only).
enum SampleData {
    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("-SeedSampleData")
    }

    static func seed(into context: ModelContext) {
        try? context.delete(model: LinkItem.self)
        try? context.delete(model: IngestState.self)

        let now = Date()
        let hour: TimeInterval = 3600
        let rows: [(String, String, TimeInterval, String, String?, Bool, Bool)] = [
            ("The quiet return of the neighborhood newspaper", "The Atlantic", 0.5, "maya.bsky.social", "This is the best thing I've read on local news in years.", false, false),
            ("Why bird migration maps are getting harder to draw", "The New York Times", 2, "fieldnotes.bsky.social", nil, false, true),
            ("A field guide to open protocols, and who governs them", "The Verge", 5, "jkr.bsky.social", "Long but worth it.", true, false),
            ("City council approves a four-year plan for protected bike lanes across the east side, pending a final vote on funding", "Seattle Times", 9, "cascadia.bsky.social", nil, false, false),
            ("How a small press printed a bestseller", "Publishers Weekly", 27, "books.bsky.social", nil, false, false),
            ("The economics of free public transit, revisited", "Bloomberg", 30, "transitwonk.bsky.social", "Thread below with my notes.", true, true),
            ("Inside the lab building a better battery", "WIRED", 34, "maya.bsky.social", nil, false, false),
            ("example.com/blog/2026/09/an-unresolved-post-slug…", "example.com", 50, "someone.bsky.social", nil, false, false),
            ("What we learned from a year without phones at dinner", "The Guardian", 75, "jkr.bsky.social", nil, true, false),
            ("Notes on typography for small screens", "Ars Technica", 100, "fieldnotes.bsky.social", nil, false, false),
        ]

        for (index, row) in rows.enumerated() {
            let item = LinkItem(
                normalizedURL: "https://sample.invalid/\(index)",
                originalURL: "https://example.com/sample/\(index)",
                headline: row.0,
                headlineResolved: true,
                publication: row.1,
                appearedAt: now.addingTimeInterval(-row.2 * hour),
                sharedByHandle: row.3,
                postText: row.4,
                postURI: "at://did:plc:sample/app.bsky.feed.post/\(index)",
                isRead: row.5,
                isSaved: row.6
            )
            context.insert(item)
        }
        try? context.save()
    }
}
#endif
