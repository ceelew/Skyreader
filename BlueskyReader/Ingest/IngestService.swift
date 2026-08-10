import Foundation
import SwiftData

/// Orchestrates a timeline refresh: page the timeline, extract links, normalize,
/// dedup, insert `LinkItem`s. Runs on the main actor since it drives a SwiftData
/// `ModelContext` shared with the UI's `@Query`.
@MainActor
final class IngestService {
    private let client: ATProtoClient
    private let maxPages: Int
    private let maxPosts: Int

    struct RefreshResult {
        let newItemCount: Int
    }

    init(client: ATProtoClient, maxPages: Int = 10, maxPosts: Int = 1000) {
        self.client = client
        self.maxPages = maxPages
        self.maxPosts = maxPosts
    }

    @discardableResult
    func refresh(context: ModelContext) async throws -> RefreshResult {
        let ingestState = try fetchOrCreateIngestState(context: context)
        let stopMarker = ingestState.newestSeenPostURI

        var existingURLs = Set(try context.fetch(FetchDescriptor<LinkItem>()).map(\.normalizedURL))

        var cursor: String?
        var pageCount = 0
        var postsProcessed = 0
        var newestURIThisRefresh: String?
        var newItemCount = 0
        var shouldStop = false

        while !shouldStop {
            let response = try await client.getTimeline(limit: 100, cursor: cursor)
            if response.feed.isEmpty { break }

            for feedPost in response.feed {
                if newestURIThisRefresh == nil {
                    newestURIThisRefresh = feedPost.post.uri
                }
                if let stopMarker, feedPost.post.uri == stopMarker {
                    shouldStop = true
                    break
                }

                for link in LinkExtractor.extract(from: feedPost) {
                    newItemCount += try await ingest(link: link, existingURLs: &existingURLs, context: context)
                }
                postsProcessed += 1
            }

            pageCount += 1
            cursor = response.cursor
            if cursor == nil || pageCount >= maxPages || postsProcessed >= maxPosts {
                break
            }
        }

        if let newestURIThisRefresh {
            ingestState.newestSeenPostURI = newestURIThisRefresh
        }
        ingestState.lastRefreshAt = Date()

        try context.save()
        return RefreshResult(newItemCount: newItemCount)
    }

    /// Resolves shorteners, normalizes, dedups, and inserts a single extracted link.
    /// Returns 1 if a new item was inserted, 0 if it was a dup.
    private func ingest(link: ExtractedLink, existingURLs: inout Set<String>, context: ModelContext) async throws -> Int {
        var resolvedURL = link.originalURL
        if let host = URLNormalizer.host(of: resolvedURL), URLNormalizer.isShortener(host: host) {
            resolvedURL = await URLNormalizer.resolveRedirect(for: resolvedURL)
        }

        let normalized = URLNormalizer.normalize(resolvedURL)
        guard !existingURLs.contains(normalized) else { return 0 }
        existingURLs.insert(normalized)

        let host = URLNormalizer.host(of: resolvedURL) ?? normalized
        let publication = PublicationMapper.publication(ogSiteName: nil, finalURLHost: host)

        let hasEmbedTitle = !(link.headlineFromEmbed?.isEmpty ?? true)
        let headline = hasEmbedTitle ? link.headlineFromEmbed! : host

        let item = LinkItem(
            normalizedURL: normalized,
            originalURL: resolvedURL,
            headline: headline,
            headlineResolved: hasEmbedTitle,
            publication: publication,
            appearedAt: link.appearedAt,
            sharedByHandle: link.sharedByHandle,
            sharedByDisplayName: link.sharedByDisplayName,
            postText: link.postText,
            postURI: link.postURI
        )
        context.insert(item)
        return 1
    }

    private func fetchOrCreateIngestState(context: ModelContext) throws -> IngestState {
        var descriptor = FetchDescriptor<IngestState>()
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            return existing
        }
        let state = IngestState()
        context.insert(state)
        return state
    }
}
