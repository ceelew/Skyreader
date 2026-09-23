import Foundation
import SwiftData

/// Resolves placeholder headlines (facet-only links with no embed title) by
/// fetching the page and reading og:title / og:site_name. Runs after ingest,
/// updating rows live as each fetch completes (§3.5, §7).
@MainActor
final class HeadlineResolver {
    private let maxConcurrent: Int
    private let maxAttempts: Int
    private let maxHostsPerPublicationPass: Int
    private let siteNameCache: SiteNameCache

    /// Guards against overlapping runs (e.g. two quick refreshes in a row) double-fetching
    /// the same pages.
    private var isRunning = false

    init(
        maxConcurrent: Int = 4,
        maxAttempts: Int = 2,
        maxHostsPerPublicationPass: Int = 20,
        siteNameCache: SiteNameCache = .shared
    ) {
        self.maxConcurrent = maxConcurrent
        self.maxAttempts = maxAttempts
        self.maxHostsPerPublicationPass = maxHostsPerPublicationPass
        self.siteNameCache = siteNameCache
    }

    func resolveUnresolvedHeadlines(context: ModelContext) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        let descriptor = FetchDescriptor<LinkItem>(
            predicate: #Predicate<LinkItem> { $0.headlineResolved == false }
        )
        if let itemsToResolve = try? context.fetch(descriptor), !itemsToResolve.isEmpty {
            let jobs = itemsToResolve.map { Job(normalizedURL: $0.normalizedURL, urlString: $0.originalURL) }
            let metaByURL = await Self.fetchAll(jobs: jobs, maxConcurrent: maxConcurrent)

            for item in itemsToResolve {
                apply(meta: metaByURL[item.normalizedURL] ?? nil, to: item)
            }
            try? context.save()
        }

        await enrichPublicationsForUnmappedHosts(context: context)
    }

    /// Second pass: items with an *embed* title (already headlineResolved) can still
    /// be stuck showing their bare host as the publication forever if the host has no
    /// entry in PublicationMapper. For each such host we haven't already tried, fetch
    /// one page, read og:site_name, and apply it to every item on that host.
    private func enrichPublicationsForUnmappedHosts(context: ModelContext) async {
        guard let allItems = try? context.fetch(FetchDescriptor<LinkItem>()) else { return }

        var itemsByUnmappedHost: [String: [LinkItem]] = [:]
        for item in allItems {
            guard let host = URLNormalizer.host(of: item.originalURL) else { continue }
            guard item.publication == host else { continue }
            guard !siteNameCache.hasTried(host: host) else { continue }
            itemsByUnmappedHost[host, default: []].append(item)
        }
        guard !itemsByUnmappedHost.isEmpty else { return }

        let hosts = Array(itemsByUnmappedHost.keys.prefix(maxHostsPerPublicationPass))
        let jobs: [HostJob] = hosts.compactMap { host in
            guard let sample = itemsByUnmappedHost[host]?.first else { return nil }
            return HostJob(host: host, urlString: sample.originalURL)
        }

        let siteNameByHost = await Self.fetchAllSiteNames(jobs: jobs, maxConcurrent: maxConcurrent)

        for host in hosts {
            siteNameCache.markTried(host: host)
            guard let siteName = siteNameByHost[host] ?? nil, !siteName.isEmpty else { continue }
            siteNameCache.record(siteName: siteName, forHost: host)
            for item in itemsByUnmappedHost[host] ?? [] {
                item.publication = siteName
            }
        }
        try? context.save()
    }

    /// Runs fetches with bounded concurrency off the main actor (network I/O only,
    /// no SwiftData access), then hands plain Sendable results back.
    private static func fetchAll(jobs: [Job], maxConcurrent: Int) async -> [String: HTMLMetaParser.PageMeta?] {
        await withTaskGroup(of: (String, HTMLMetaParser.PageMeta?).self) { group in
            var iterator = jobs.makeIterator()
            var results: [String: HTMLMetaParser.PageMeta?] = [:]

            func addNext() {
                guard let job = iterator.next() else { return }
                group.addTask {
                    let meta = await HeadlinePageFetcher.fetchMeta(for: job.urlString)
                    return (job.normalizedURL, meta)
                }
            }

            for _ in 0..<maxConcurrent { addNext() }
            while let (key, meta) = await group.next() {
                results[key] = meta
                addNext()
            }
            return results
        }
    }

    private func apply(meta: HTMLMetaParser.PageMeta?, to item: LinkItem) {
        let fetchedTitle = meta?.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let isJunkTitle = fetchedTitle.map { ArticleDeduplicator.junkTitles.contains($0.lowercased()) } ?? false

        if let fetchedTitle, !fetchedTitle.isEmpty, !isJunkTitle {
            item.headline = fetchedTitle
            item.headlineResolved = true
        } else {
            item.headlineFetchAttempts += 1
            if item.headlineFetchAttempts >= maxAttempts {
                // Give up: a clean "host/path…" beats leaving the bare host (or a junk
                // title like "Just a moment...") as the permanent headline.
                item.headline = URLNormalizer.fallbackHeadline(for: item.originalURL)
                item.headlineResolved = true
            }
        }

        if let siteName = meta?.siteName, !siteName.isEmpty {
            item.publication = siteName
            if let host = URLNormalizer.host(of: item.originalURL) {
                siteNameCache.record(siteName: siteName, forHost: host)
            }
        }
    }

    /// Runs site-name-only fetches with bounded concurrency off the main actor.
    private static func fetchAllSiteNames(jobs: [HostJob], maxConcurrent: Int) async -> [String: String?] {
        await withTaskGroup(of: (String, String?).self) { group in
            var iterator = jobs.makeIterator()
            var results: [String: String?] = [:]

            func addNext() {
                guard let job = iterator.next() else { return }
                group.addTask {
                    let meta = await HeadlinePageFetcher.fetchMeta(for: job.urlString)
                    return (job.host, meta?.siteName)
                }
            }

            for _ in 0..<maxConcurrent { addNext() }
            while let (host, siteName) = await group.next() {
                results[host] = siteName
                addNext()
            }
            return results
        }
    }

    fileprivate struct Job: Sendable {
        let normalizedURL: String
        let urlString: String
    }

    fileprivate struct HostJob: Sendable {
        let host: String
        let urlString: String
    }
}
