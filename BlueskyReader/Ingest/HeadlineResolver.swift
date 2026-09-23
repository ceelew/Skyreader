import Foundation
import SwiftData

/// Resolves placeholder headlines (facet-only links with no embed title) by
/// fetching the page and reading og:title / og:site_name. Runs after ingest,
/// updating rows live as each fetch completes (§3.5, §7).
@MainActor
final class HeadlineResolver {
    private let maxConcurrent: Int
    private let maxAttempts: Int

    /// Guards against overlapping runs (e.g. two quick refreshes in a row) double-fetching
    /// the same pages.
    private var isRunning = false

    init(maxConcurrent: Int = 4, maxAttempts: Int = 2) {
        self.maxConcurrent = maxConcurrent
        self.maxAttempts = maxAttempts
    }

    func resolveUnresolvedHeadlines(context: ModelContext) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        let descriptor = FetchDescriptor<LinkItem>(
            predicate: #Predicate<LinkItem> { $0.headlineResolved == false }
        )
        guard let itemsToResolve = try? context.fetch(descriptor), !itemsToResolve.isEmpty else { return }

        let jobs = itemsToResolve.map { Job(normalizedURL: $0.normalizedURL, urlString: $0.originalURL) }

        let metaByURL = await Self.fetchAll(jobs: jobs, maxConcurrent: maxConcurrent)

        for item in itemsToResolve {
            apply(meta: metaByURL[item.normalizedURL] ?? nil, to: item)
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
        }
    }

    fileprivate struct Job: Sendable {
        let normalizedURL: String
        let urlString: String
    }
}
