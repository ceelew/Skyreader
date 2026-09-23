import XCTest
@testable import BlueskyReader

final class IngestCheckpointTests: XCTestCase {

    private func post(uri: String, repostBy did: String? = nil, indexedAt: String? = nil) throws -> FeedViewPost {
        let reasonJSON: String
        if let did {
            reasonJSON = """
            "reason": {
                "$type": "app.bsky.feed.defs#reasonRepost",
                "by": {"did": "\(did)", "handle": "reposter.bsky.social", "displayName": "Reposter"},
                "indexedAt": "\(indexedAt ?? "2026-09-21T09:00:00.000Z")"
            },
            """
        } else {
            reasonJSON = ""
        }
        let json = """
        {
            \(reasonJSON)
            "post": {
                "uri": "\(uri)",
                "cid": "cid-\(uri.hashValue)",
                "author": {"did": "did:plc:author", "handle": "author.bsky.social", "displayName": "Author"},
                "indexedAt": "2026-09-19T09:00:00.000Z"
            }
        }
        """
        return try JSONDecoder().decode(FeedViewPost.self, from: Data(json.utf8))
    }

    func testMarkerAtIndexZeroOfRepostOfMarkerPostDoesNotStop() throws {
        // The newest feed item is a repost of the same post.uri as the checkpoint.
        // Because feedItemKey differs for the repost, this must NOT be treated as
        // having reached the marker (the historical bug this guards against).
        let markerURI = "at://did:plc:x/app.bsky.feed.post/1"
        let repostOfMarker = try post(uri: markerURI, repostBy: "did:plc:reposter", indexedAt: "2026-09-22T00:00:00.000Z")
        let older = try post(uri: "at://did:plc:x/app.bsky.feed.post/0")

        let feed = [repostOfMarker, older]
        let (items, reachedMarker) = IngestService.itemsBeforeCheckpoint(feed, marker: markerURI)

        XCTAssertFalse(reachedMarker)
        XCTAssertEqual(items.map(\.post.uri), [markerURI, "at://did:plc:x/app.bsky.feed.post/0"])
    }

    func testNormalStopAtMarker() throws {
        let a = try post(uri: "at://a")
        let b = try post(uri: "at://b")
        let c = try post(uri: "at://c")

        let (items, reachedMarker) = IngestService.itemsBeforeCheckpoint([a, b, c], marker: "at://b")

        XCTAssertTrue(reachedMarker)
        XCTAssertEqual(items.map(\.post.uri), ["at://a"])
    }

    func testNilMarkerReturnsWholeFeedAndDoesNotReachMarker() throws {
        let a = try post(uri: "at://a")
        let b = try post(uri: "at://b")

        let (items, reachedMarker) = IngestService.itemsBeforeCheckpoint([a, b], marker: nil)

        XCTAssertFalse(reachedMarker)
        XCTAssertEqual(items.map(\.post.uri), ["at://a", "at://b"])
    }
}
