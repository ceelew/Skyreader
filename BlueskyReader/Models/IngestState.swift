import Foundation
import SwiftData

@Model
final class IngestState {
    var lastRefreshAt: Date?
    /// Stop marker for the checkpoint scan. Despite the name, this stores a *feed-item
    /// key* (`FeedViewPost.feedItemKey`), not necessarily a bare post URI: for reposts
    /// it's a composite key so a repost of the newest-seen post doesn't look identical
    /// to the original and falsely halt the scan. Values written before this change are
    /// plain post URIs, which remain valid keys for non-repost items, so no migration
    /// is needed.
    var newestSeenPostURI: String?

    init(lastRefreshAt: Date? = nil, newestSeenPostURI: String? = nil) {
        self.lastRefreshAt = lastRefreshAt
        self.newestSeenPostURI = newestSeenPostURI
    }
}
