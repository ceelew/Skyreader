import Foundation
import SwiftData

/// Resolves placeholder headlines (facet-only links with no embed title) by
/// fetching the page and reading og:title / og:site_name. Runs after ingest,
/// updating rows live as each fetch completes (§3.5, §7).
@MainActor
final class HeadlineResolver {
    private let maxConcurrent: Int
    private let maxAttempts: Int

    init(maxConcurrent: Int = 4, maxAttempts: Int = 2) {
        self.maxConcurrent = maxConcurrent
        self.maxAttempts = maxAttempts
    }

    func resolveUnresolvedHeadlines(context: ModelContext) async {
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
        if let title = meta?.title, !title.isEmpty {
            item.headline = title
            item.headlineResolved = true
        } else {
            item.headlineFetchAttempts += 1
            if item.headlineFetchAttempts >= maxAttempts {
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
