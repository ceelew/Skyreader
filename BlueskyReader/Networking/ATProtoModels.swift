import Foundation

// MARK: - Session

struct CreateSessionResponse: Decodable {
    let accessJwt: String
    let refreshJwt: String
    let did: String
    let handle: String
}

struct RefreshSessionResponse: Decodable {
    let accessJwt: String
    let refreshJwt: String
    let did: String
    let handle: String
}

struct ATProtoErrorBody: Decodable {
    let error: String?
    let message: String?
}

enum ATProtoError: Error, LocalizedError {
    case invalidCredentials
    case expiredToken
    case rateLimited(retryAfter: TimeInterval?)
    case network(Error)
    case decoding(Error)
    case notAuthenticated
    case server(status: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "Invalid handle or app password."
        case .expiredToken: return "Session expired."
        case .rateLimited: return "Too many requests — please wait a moment."
        case .network(let e): return "Network error: \(e.localizedDescription)"
        case .decoding(let e): return "Failed to parse response: \(e.localizedDescription)"
        case .notAuthenticated: return "Not signed in."
        case .server(let status, let message): return message ?? "Server error (\(status))."
        }
    }
}

// MARK: - Timeline

struct GetTimelineResponse: Decodable {
    let feed: [FeedViewPost]
    let cursor: String?
}

struct FeedViewPost: Decodable {
    let post: PostView
    let reason: FeedReason?
}

struct FeedReason: Decodable {
    let type: String
    let by: ReasonAuthor?
    let indexedAt: String?

    enum CodingKeys: String, CodingKey {
        case type = "$type"
        case by
        case indexedAt
    }

    var isRepost: Bool { type == "app.bsky.feed.defs#reasonRepost" }
}

struct ReasonAuthor: Decodable {
    let did: String
    let handle: String
    let displayName: String?
}

struct PostView: Decodable {
    let uri: String
    let cid: String
    let author: ReasonAuthor
    let record: PostRecord?
    let embed: PostEmbed?
    let indexedAt: String
}

struct PostRecord: Decodable {
    let text: String?
    let facets: [Facet]?
}

struct Facet: Decodable {
    let features: [FacetFeature]?
}

struct FacetFeature: Decodable {
    let type: String?
    let uri: String?

    enum CodingKeys: String, CodingKey {
        case type = "$type"
        case uri
    }

    var isLink: Bool { type == "app.bsky.richtext.facet#link" }
}

/// Lenient embed decoder — handles external, recordWithMedia(external), and unknown/ignored shapes.
struct PostEmbed: Decodable {
    let type: String?
    let external: ExternalEmbed?
    let mediaExternal: ExternalEmbed?

    enum CodingKeys: String, CodingKey {
        case type = "$type"
        case external
        case media
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        external = try container.decodeIfPresent(ExternalEmbed.self, forKey: .external)

        // app.bsky.embed.recordWithMedia#view nests the actual media under "media",
        // which itself may be an external embed view.
        if let mediaContainer = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .media) {
            mediaExternal = try? mediaContainer.decodeIfPresent(ExternalEmbed.self, forKey: .external)
        } else {
            mediaExternal = nil
        }
    }

    var resolvedExternal: ExternalEmbed? { external ?? mediaExternal }
}

struct ExternalEmbed: Decodable {
    let uri: String
    let title: String?
    let description: String?
}
