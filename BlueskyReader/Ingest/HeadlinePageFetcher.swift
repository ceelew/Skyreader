import Foundation

enum HeadlinePageFetcher {
    private static let maxBytes = 1_048_576 // ~1MB
    private static let timeout: TimeInterval = 10

    /// Fetches a URL and pulls og:title / og:site_name / <title>. Returns nil on
    /// any failure (timeout, non-200, undecodable body) — callers treat that as
    /// "try again later," never as a reason to fail the whole refresh.
    static func fetchMeta(for urlString: String, session: URLSession = .shared) async -> HTMLMetaParser.PageMeta? {
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.setValue("Mozilla/5.0 (compatible; BlueskyReaderApp/1.0; +https://bsky.app)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                return nil
            }
            let capped = data.prefix(maxBytes)
            guard let html = String(data: capped, encoding: .utf8) ?? String(data: capped, encoding: .isoLatin1) else {
                return nil
            }
            return HTMLMetaParser.parse(html: html)
        } catch {
            return nil
        }
    }
}
