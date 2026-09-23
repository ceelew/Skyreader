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
    private let siteNameCache: SiteNameCache

    struct RefreshResult {
        let newItemCount: Int
        /// True if the scan hit the page/post cap before reaching the previous
        /// checkpoint, meaning older items in this refresh window may not have been
        /// scanned. The checkpoint is still advanced in this case (otherwise a very
        /// active timeline would never stop re-scanning), but a future UI could use
        /// this to tell the user the ingest may be incomplete.
        let lastRefreshHitCap: Bool
    }

    init(client: ATProtoClient, maxPages: Int = 10, maxPosts: Int = 1000, siteNameCache: SiteNameCache = .shared) {
        self.client = client
        self.maxPages = maxPages
        self.maxPosts = maxPosts
        self.siteNameCache = siteNameCache
    }

    @discardableResult
    func refresh(context: ModelContext) async throws -> RefreshResult {
        let ingestState = try fetchOrCreateIngestState(context: context)
        let stopMarker = ingestState.newestSeenPostURI

        var existingURLs = Set(try context.fetch(FetchDescriptor<LinkItem>()).map(\.normalizedURL))

        var cursor: String?
        var pageCount = 0
        var postsProcessed = 0
        var newestKeyThisRefresh: String?
        var newItemCount = 0
        var shouldStop = false
        var hitCap = false

        while !shouldStop {
            let response = try await client.getTimeline(limit: 100, cursor: cursor)
            if response.feed.isEmpty { break }

            let (itemsToProcess, reachedMarker) = Self.itemsBeforeCheckpoint(response.feed, marker: stopMarker)

            // Extract links for the whole page up front so shortener redirects can be
            // resolved concurrently, rather than one at a time inside the insert loop.
            let linksByPost = itemsToProcess.map { LinkExtractor.extract(from: $0) }
            var shortenerURLs = Set<String>()
            for links in linksByPost {
                for link in links {
                    if let host = URLNormalizer.host(of: link.originalURL), URLNormalizer.isShortener(host: host) {
                        shortenerURLs.insert(link.originalURL)
                    }
                }
            }
            let resolvedRedirects = await Self.resolveRedirects(shortenerURLs)

            for (index, feedPost) in itemsToProcess.enumerated() {
                if newestKeyThisRefresh == nil {
                    newestKeyThisRefresh = feedPost.feedItemKey
                }
                for link in linksByPost[index] {
                    newItemCount += try ingest(link: link, resolvedRedirects: resolvedRedirects, existingURLs: &existingURLs, context: context)
                }
                postsProcessed += 1
            }

            if reachedMarker {
                shouldStop = true
                break
            }

            pageCount += 1
            cursor = response.cursor
            if cursor == nil {
                break
            }
            if pageCount >= maxPages || postsProcessed >= maxPosts {
                hitCap = true
                break
            }
        }

        if let newestKeyThisRefresh {
            ingestState.newestSeenPostURI = newestKeyThisRefresh
        }
        ingestState.lastRefreshAt = Date()

        try context.save()
        return RefreshResult(newItemCount: newItemCount, lastRefreshHitCap: hitCap)
    }

    /// Pure helper: splits a feed page at the stop marker (a `FeedViewPost.feedItemKey`).
    /// Returns the items before the marker (to be ingested) and whether the marker was
    /// found in this page. A nil marker means "no checkpoint yet" — the whole page is
    /// returned and `reachedMarker` is false.
    nonisolated static func itemsBeforeCheckpoint(
        _ feed: [FeedViewPost],
        marker: String?
    ) -> (items: [FeedViewPost], reachedMarker: Bool) {
        guard let marker else { return (feed, false) }
        var items: [FeedViewPost] = []
        for feedPost in feed {
            if feedPost.feedItemKey == marker {
                return (items, true)
            }
            items.append(feedPost)
        }
        return (items, false)
    }

    /// Normalizes, dedups, and inserts a single extracted link. Shortener redirects
    /// are already resolved in `resolvedRedirects` (a map from original URL to final
    /// URL, built concurrently before the insert loop). Returns 1 if a new item was
    /// inserted, 0 if it was a dup.
    private func ingest(
        link: ExtractedLink,
        resolvedRedirects: [String: String],
        existingURLs: inout Set<String>,
        context: ModelContext
    ) throws -> Int {
        let resolvedURL = resolvedRedirects[link.originalURL] ?? link.originalURL

        let normalized = URLNormalizer.normalize(resolvedURL)
        guard !existingURLs.contains(normalized) else { return 0 }
        existingURLs.insert(normalized)

        let host = URLNormalizer.host(of: resolvedURL) ?? normalized
        let cachedSiteName = siteNameCache.siteName(forHost: host)
        let publication = PublicationMapper.publication(ogSiteName: cachedSiteName, finalURLHost: host)

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

    /// Resolves a set of shortener URLs to their final URLs concurrently, at most
    /// `maxConcurrent` in flight at a time, and returns a map from original to
    /// resolved URL. `nonisolated` so the concurrent requests aren't serialized
    /// through the main actor; resolution itself has no shared mutable state.
    nonisolated static func resolveRedirects(
        _ urls: Set<String>,
        session: URLSession = .shared,
        maxConcurrent: Int = 6
    ) async -> [String: String] {
        guard !urls.isEmpty else { return [:] }

        var resolved: [String: String] = [:]
        resolved.reserveCapacity(urls.count)
        var pending = urls.makeIterator()

        await withTaskGroup(of: (String, String).self) { group in
            for _ in 0..<maxConcurrent {
                guard let url = pending.next() else { break }
                group.addTask { (url, await URLNormalizer.resolveRedirect(for: url, session: session)) }
            }
            while let (original, finalURL) = await group.next() {
                resolved[original] = finalURL
                if let next = pending.next() {
                    group.addTask { (next, await URLNormalizer.resolveRedirect(for: next, session: session)) }
                }
            }
        }
        return resolved
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
