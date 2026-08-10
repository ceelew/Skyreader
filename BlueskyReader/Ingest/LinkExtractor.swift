import Foundation

struct ExtractedLink {
    let originalURL: String
    let headlineFromEmbed: String?
    let appearedAt: Date
    let sharedByHandle: String
    let sharedByDisplayName: String?
    let postText: String?
    let postURI: String
}

enum LinkExtractor {
    /// Pulls every external link out of a feed post: the embed card (richest source)
    /// and any bare-text links in facets. Reposts are timestamped and attributed to
    /// the reposter (§3.4). Never throws — malformed posts just yield no links.
    static func extract(from feedPost: FeedViewPost) -> [ExtractedLink] {
        let post = feedPost.post

        let appearedAtString: String
        let sharerHandle: String
        let sharerDisplayName: String?

        if let reason = feedPost.reason, reason.isRepost {
            appearedAtString = reason.indexedAt ?? post.indexedAt
            sharerHandle = reason.by?.handle ?? post.author.handle
            sharerDisplayName = reason.by?.displayName ?? post.author.displayName
        } else {
            appearedAtString = post.indexedAt
            sharerHandle = post.author.handle
            sharerDisplayName = post.author.displayName
        }

        guard let appearedAt = DateParsing.parse(appearedAtString) else { return [] }

        var seenInPost = Set<String>()
        var results: [ExtractedLink] = []

        func tryAdd(uri: String, headline: String?) {
            guard let host = URLNormalizer.host(of: uri) else { return }
            if host == "bsky.app" { return }
            guard uri.hasPrefix("http://") || uri.hasPrefix("https://") else { return }

            let normalized = URLNormalizer.normalize(uri)
            guard !seenInPost.contains(normalized) else { return }
            seenInPost.insert(normalized)

            results.append(
                ExtractedLink(
                    originalURL: uri,
                    headlineFromEmbed: headline?.trimmingCharacters(in: .whitespacesAndNewlines),
                    appearedAt: appearedAt,
                    sharedByHandle: sharerHandle,
                    sharedByDisplayName: sharerDisplayName,
                    postText: post.record?.text,
                    postURI: post.uri
                )
            )
        }

        if let external = post.embed?.resolvedExternal {
            tryAdd(uri: external.uri, headline: external.title)
        }

        for facet in post.record?.facets ?? [] {
            for feature in facet.features ?? [] where feature.isLink {
                if let uri = feature.uri {
                    tryAdd(uri: uri, headline: nil)
                }
            }
        }

        return results
    }
}
