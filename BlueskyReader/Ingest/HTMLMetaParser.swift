import Foundation

/// Lightweight scanner over an HTML `<head>` — no HTML-parsing dependency.
/// Pulls og:title / og:site_name / <title> via regex over the raw markup.
enum HTMLMetaParser {
    struct PageMeta {
        let title: String?
        let siteName: String?
    }

    static func parse(html: String) -> PageMeta {
        let head = headSlice(of: html)
        let ogTitle = metaContent(in: head, key: "og:title")
        let ogSiteName = metaContent(in: head, key: "og:site_name")
        let plainTitle = titleTag(in: head)

        let title = firstNonEmpty(ogTitle, plainTitle).map(decodeEntities)
        let siteName = ogSiteName.map(decodeEntities)

        return PageMeta(title: title, siteName: siteName)
    }

    /// Limits regex work to the `<head>...</head>` region when present.
    private static func headSlice(of html: String) -> Substring {
        guard let headStart = html.range(of: "<head", options: [.caseInsensitive]),
              let headEnd = html.range(of: "</head>", options: [.caseInsensitive], range: headStart.upperBound..<html.endIndex) else {
            // No clear head boundary — just scan a bounded prefix of the document.
            let cutoff = html.index(html.startIndex, offsetBy: min(200_000, html.count))
            return html[html.startIndex..<cutoff]
        }
        return html[headStart.lowerBound..<headEnd.upperBound]
    }

    private static func metaContent(in html: Substring, key: String) -> String? {
        let escapedKey = NSRegularExpression.escapedPattern(for: key)
        let keyAttr = #"(?:property|name)\s*=\s*["']"# + escapedKey + #"["']"#
        let contentAttr = #"content\s*=\s*["']([^"']*)["']"#
        let patterns = [
            "<meta[^>]*?\(keyAttr)[^>]*?\(contentAttr)",
            "<meta[^>]*?\(contentAttr)[^>]*?\(keyAttr)",
        ]
        for pattern in patterns {
            if let match = firstMatch(pattern: pattern, in: html) {
                return match
            }
        }
        return nil
    }

    private static func titleTag(in html: Substring) -> String? {
        firstMatch(pattern: #"<title[^>]*>([^<]*)</title>"#, in: html)
    }

    private static func firstMatch(pattern: String, in text: Substring) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let nsText = String(text) as NSString
        guard let match = regex.firstMatch(in: nsText as String, options: [], range: NSRange(location: 0, length: nsText.length)),
              match.numberOfRanges > 1 else { return nil }
        let range = match.range(at: 1)
        guard range.location != NSNotFound else { return nil }
        let value = nsText.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func firstNonEmpty(_ values: String?...) -> String? {
        for value in values {
            if let value, !value.isEmpty { return value }
        }
        return nil
    }

    private static func decodeEntities(_ string: String) -> String {
        var result = string
        let named: [String: String] = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
            "&apos;": "'", "&#39;": "'", "&nbsp;": " ", "&mdash;": "—",
            "&ndash;": "–", "&rsquo;": "\u{2019}", "&lsquo;": "\u{2018}",
            "&rdquo;": "\u{201D}", "&ldquo;": "\u{201C}",
        ]
        for (entity, replacement) in named {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        // Numeric entities: &#123; / &#x7B;
        if let regex = try? NSRegularExpression(pattern: #"&#(x?[0-9a-fA-F]+);"#) {
            let nsResult = result as NSString
            let matches = regex.matches(in: result, range: NSRange(location: 0, length: nsResult.length))
            for match in matches.reversed() {
                let codeStr = nsResult.substring(with: match.range(at: 1))
                let scalarValue: UInt32?
                if codeStr.hasPrefix("x") || codeStr.hasPrefix("X") {
                    scalarValue = UInt32(codeStr.dropFirst(), radix: 16)
                } else {
                    scalarValue = UInt32(codeStr, radix: 10)
                }
                if let scalarValue, let scalar = Unicode.Scalar(scalarValue) {
                    result = (result as NSString).replacingCharacters(in: match.range, with: String(Character(scalar)))
                }
            }
        }
        return result
    }
}
