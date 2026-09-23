import Foundation

/// Display-time tidy-up for headlines. Many sites append their own name to the page
/// title ("Story - The Boston Globe"), which repeats the publication shown above it.
enum HeadlineCleaner {
    private static let separators = [" - ", " | ", " — ", " – ", " · ", " :: "]

    /// Drops a trailing "<separator><publication>" when that suffix names the same
    /// outlet as `publication` (or the article's host). Never returns an empty string.
    static func clean(_ headline: String, publication: String, host: String? = nil) -> String {
        let trimmed = headline.trimmingCharacters(in: .whitespacesAndNewlines)
        let targets = Set([publication, host ?? ""].map(squash).filter { !$0.isEmpty })
        guard !targets.isEmpty else { return trimmed }

        for separator in separators {
            guard let range = trimmed.range(of: separator, options: .backwards) else { continue }
            let head = trimmed[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
            let tail = String(trimmed[range.upperBound...])
            if !head.isEmpty, targets.contains(squash(tail)) {
                return head
            }
        }
        return trimmed
    }

    /// "The Boston Globe", "BostonGlobe.com", "www.bostonglobe.com" → "bostonglobe".
    static func squash(_ name: String) -> String {
        var s = name.lowercased()
        if s.hasPrefix("www.") { s.removeFirst(4) }
        for suffix in [".com", ".org", ".net", ".co.uk", ".co", ".news"] where s.hasSuffix(suffix) {
            s.removeLast(suffix.count)
            break
        }
        s = s.filter { $0.isLetter || $0.isNumber }
        if s.hasPrefix("the"), s.count > 3 { s.removeFirst(3) }
        return s
    }
}
