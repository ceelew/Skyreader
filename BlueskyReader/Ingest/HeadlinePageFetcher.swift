import Foundation

enum HeadlinePageFetcher {
    private static let maxBytes = 1_048_576 // ~1MB
    private static let timeout: TimeInterval = 10
    /// How often (in bytes) to check the accumulated buffer for a closing `</head>`
    /// tag. Checking every byte would be quadratic; this amortizes the cost while
    /// still stopping shortly after the head actually closes.
    private static let headCheckInterval = 8_192

    /// Fetches a URL and pulls og:title / og:site_name / <title>. Returns nil on
    /// any failure (timeout, non-200, undecodable body) — callers treat that as
    /// "try again later," never as a reason to fail the whole refresh.
    ///
    /// Reads the response as a byte stream and stops as soon as either `maxBytes`
    /// have been read or the accumulated text contains a closing `</head>` tag —
    /// everything we need (og:title/og:site_name/<title>) lives in `<head>`, so most
    /// pages let us stop well short of the full body.
    static func fetchMeta(for urlString: String, session: URLSession = .shared) async -> HTMLMetaParser.PageMeta? {
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        request.setValue("Mozilla/5.0 (compatible; Skyreader/\(version); +https://github.com/ceelew/Skyreader)", forHTTPHeaderField: "User-Agent")

        do {
            let (asyncBytes, response) = try await session.bytes(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                return nil
            }

            var data = Data()
            data.reserveCapacity(min(maxBytes, 65_536))
            var bytesSinceLastCheck = 0

            for try await byte in asyncBytes {
                data.append(byte)
                if data.count >= maxBytes {
                    break
                }
                bytesSinceLastCheck += 1
                if bytesSinceLastCheck >= headCheckInterval {
                    bytesSinceLastCheck = 0
                    if containsHeadClose(data) {
                        break
                    }
                }
            }

            guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
                return nil
            }
            return HTMLMetaParser.parse(html: html)
        } catch {
            return nil
        }
    }

    private static func containsHeadClose(_ data: Data) -> Bool {
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            return false
        }
        return text.range(of: "</head>", options: [.caseInsensitive]) != nil
    }
}
