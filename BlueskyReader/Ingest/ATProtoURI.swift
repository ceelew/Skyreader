import Foundation

enum ATProtoURI {
    /// Converts an `at://did/app.bsky.feed.post/rkey` URI into a bsky.app web link.
    static func bskyAppURL(fromPostURI uri: String) -> URL? {
        guard uri.hasPrefix("at://") else { return nil }
        let parts = uri.dropFirst("at://".count).split(separator: "/")
        guard parts.count >= 3, parts[1] == "app.bsky.feed.post" else { return nil }
        return URL(string: "https://bsky.app/profile/\(parts[0])/post/\(parts[2])")
    }
}
