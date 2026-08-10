import Foundation
import SwiftData

@Model
final class LinkItem {
    @Attribute(.unique) var normalizedURL: String
    var originalURL: String
    var headline: String
    var headlineResolved: Bool
    var publication: String
    var appearedAt: Date
    var sharedByHandle: String
    var sharedByDisplayName: String?
    var postText: String?
    var postURI: String
    var isRead: Bool
    var isSaved: Bool
    var headlineFetchAttempts: Int

    init(
        normalizedURL: String,
        originalURL: String,
        headline: String,
        headlineResolved: Bool,
        publication: String,
        appearedAt: Date,
        sharedByHandle: String,
        sharedByDisplayName: String? = nil,
        postText: String? = nil,
        postURI: String,
        isRead: Bool = false,
        isSaved: Bool = false,
        headlineFetchAttempts: Int = 0
    ) {
        self.normalizedURL = normalizedURL
        self.originalURL = originalURL
        self.headline = headline
        self.headlineResolved = headlineResolved
        self.publication = publication
        self.appearedAt = appearedAt
        self.sharedByHandle = sharedByHandle
        self.sharedByDisplayName = sharedByDisplayName
        self.postText = postText
        self.postURI = postURI
        self.isRead = isRead
        self.isSaved = isSaved
        self.headlineFetchAttempts = headlineFetchAttempts
    }
}
