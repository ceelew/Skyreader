import Foundation

enum URLNormalizer {
    /// Domains known to be link shorteners — worth spending a redirect round-trip to unwrap.
    private static let knownShorteners: Set<String> = [
        "bit.ly", "t.co", "tinyurl.com", "buff.ly", "ow.ly", "dlvr.it",
        "is.gd", "rebrand.ly", "lnkd.in", "trib.al", "shar.es", "cutt.ly",
    ]

    private static let trackingParamPrefixes = ["utm_"]
    private static let trackingParamNames: Set<String> = [
        "fbclid", "gclid", "igshid", "mc_cid", "mc_eid", "ref", "ref_src",
        "ref_url", "spm", "si", "cmpid", "s", "source",
    ]

    static func isShortener(host: String) -> Bool {
        knownShorteners.contains(strippingPrefixes(from: host))
    }

    /// Follows redirects (HEAD, capped hops) to resolve a shortener to its final URL.
    /// Returns the original string unchanged on any failure.
    static func resolveRedirect(for urlString: String, session: URLSession = .shared) async -> String {
        guard let url = URL(string: urlString) else { return urlString }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 8

        do {
            let (_, response) = try await session.data(for: request)
            if let finalURL = response.url {
                return finalURL.absoluteString
            }
        } catch {
            // Fall through to original.
        }
        return urlString
    }

    /// Produces the dedup/display key: lowercased host with www/m/amp stripped,
    /// tracking params removed, no fragment, no trailing slash.
    static func normalize(_ urlString: String) -> String {
        guard var components = URLComponents(string: urlString) else {
            return urlString.lowercased()
        }

        if let host = components.host {
            components.host = strippingPrefixes(from: host.lowercased())
        }

        if let items = components.queryItems {
            let filtered = items.filter { item in
                let name = item.name.lowercased()
                if trackingParamPrefixes.contains(where: { name.hasPrefix($0) }) { return false }
                if trackingParamNames.contains(name) { return false }
                return true
            }
            components.queryItems = filtered.isEmpty ? nil : filtered.sorted { $0.name < $1.name }
        }

        components.fragment = nil

        var path = components.path
        if path.count > 1 && path.hasSuffix("/") {
            path.removeLast()
        }
        components.path = path

        return (components.string ?? urlString).lowercased()
    }

    static func strippingPrefixes(from host: String) -> String {
        var h = host
        for prefix in ["www.", "m.", "amp."] {
            if h.hasPrefix(prefix) {
                h.removeFirst(prefix.count)
                break
            }
        }
        return h
    }

    static func host(of urlString: String) -> String? {
        guard let url = URL(string: urlString), let host = url.host else { return nil }
        return strippingPrefixes(from: host.lowercased())
    }

    /// A readable fallback headline for a link whose page title could never be
    /// resolved: "host/first/path/components", truncated to ~`maxLength` chars with
    /// a trailing ellipsis when something had to be cut.
    static func fallbackHeadline(for urlString: String, maxLength: Int = 60) -> String {
        let base: String
        let pathComponents: [String]
        if let url = URL(string: urlString), let host = url.host, !host.isEmpty {
            base = strippingPrefixes(from: host.lowercased())
            pathComponents = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        } else {
            base = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
            pathComponents = []
        }

        var result = base
        var pathWasTruncated = false
        for component in pathComponents {
            let candidate = result + "/" + component
            if candidate.count > maxLength {
                pathWasTruncated = true
                break
            }
            result = candidate
        }

        let needsEllipsis = pathWasTruncated || result.count > maxLength
        if result.count > maxLength {
            result = String(result.prefix(max(0, maxLength - 1)))
        }
        return needsEllipsis ? result + "…" : result
    }
}
