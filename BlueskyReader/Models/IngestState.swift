import Foundation
import SwiftData

@Model
final class IngestState {
    var lastRefreshAt: Date?
    var newestSeenPostURI: String?

    init(lastRefreshAt: Date? = nil, newestSeenPostURI: String? = nil) {
        self.lastRefreshAt = lastRefreshAt
        self.newestSeenPostURI = newestSeenPostURI
    }
}
