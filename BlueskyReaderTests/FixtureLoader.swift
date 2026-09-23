import Foundation
@testable import BlueskyReader

enum FixtureLoader {
    enum FixtureError: Error {
        case missing(String)
    }

    private final class Anchor {}

    static func data(named name: String) throws -> Data {
        let bundle = Bundle(for: Anchor.self)
        guard let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: name, withExtension: "json") else {
            throw FixtureError.missing(name)
        }
        return try Data(contentsOf: url)
    }

    static func feedViewPost(named name: String) throws -> FeedViewPost {
        let data = try data(named: name)
        return try JSONDecoder().decode(FeedViewPost.self, from: data)
    }
}
