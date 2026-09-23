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

    /// Follows redirects to resolve a shortener to its final URL. Tries a cheap HEAD
    /// first; some shorteners (dlvr.it among them) reject HEAD or answer it without
    /// redirecting, so fall back to a GET that stops once headers arrive.
    /// Returns the original string unchanged on any failure.
    static func resolveRedirect(for urlString: String, session: URLSession = .shared) async -> String {
        guard let url = URL(string: upgradedToHTTPS(urlString)) else { return urlString }

        if let final = await finalURL(for: url, method: "HEAD", session: session), !isStillShortened(final) {
            return final.absoluteString
        }
        if let final = await finalURL(for: url, method: "GET", session: session), !isStillShortened(final) {
            return final.absoluteString
        }
        return urlString
    }

    private static func finalURL(for url: URL, method: String, session: URLSession) async -> URL? {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 8
        // A non-browser agent on purpose: t.co answers browsers with a JavaScript
        // redirect page (HTTP 200) but gives other clients a real 301.
        request.setValue("Skyreader/1.0 (link resolver)", forHTTPHeaderField: "User-Agent")
        let tracker = RedirectTracker()
        do {
            // bytes(for:) returns once headers arrive, after redirects are followed,
            // so a GET here never downloads the page body.
            let (_, response) = try await session.bytes(for: request, delegate: tracker)
            // Once redirects are done, the destination is known even if that site
            // refuses our request, so the final status code doesn't matter.
            return response.url ?? tracker.lastRedirect
        } catch {
            return tracker.lastRedirect
        }
    }

    /// App Transport Security blocks plain-HTTP requests, so lookups on `http://`
    /// links fail silently. Every shortener we know of, and nearly every publisher,
    /// serves HTTPS, so request that instead.
    static func upgradedToHTTPS(_ urlString: String) -> String {
        guard urlString.lowercased().hasPrefix("http://") else { return urlString }
        return "https://" + urlString.dropFirst("http://".count)
    }

    private static func isStillShortened(_ url: URL) -> Bool {
        guard let host = url.host() else { return true }
        return isShortener(host: host)
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

/// Upgrades each redirect hop to HTTPS (App Transport Security would otherwise kill
/// chains like t.co → trib.al → http://publisher) and remembers the latest target.
private final class RedirectTracker: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var _lastRedirect: URL?

    var lastRedirect: URL? {
        lock.lock(); defer { lock.unlock() }
        return _lastRedirect
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        var upgraded = request
        if let url = request.url {
            let https = URL(string: URLNormalizer.upgradedToHTTPS(url.absoluteString)) ?? url
            upgraded.url = https
            lock.lock(); _lastRedirect = https; lock.unlock()
        }
        return upgraded
    }
}
