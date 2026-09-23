import XCTest
import SwiftData
@testable import BlueskyReader

@MainActor
final class RetentionServiceTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "RetentionServiceTests"
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)

        container = try! ModelContainer(
            for: LinkItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        context = nil
        container = nil
        super.tearDown()
    }

    private func makeItem(daysOld: Int, isRead: Bool = false, isSaved: Bool = false) -> LinkItem {
        let appearedAt = Calendar.current.date(byAdding: .day, value: -daysOld, to: Date())!
        return LinkItem(
            normalizedURL: UUID().uuidString,
            originalURL: "https://example.com/\(UUID().uuidString)",
            headline: "Headline",
            headlineResolved: true,
            publication: "Example",
            appearedAt: appearedAt,
            sharedByHandle: "alice.bsky.social",
            postURI: "at://did:example/app.bsky.feed.post/\(UUID().uuidString)",
            isRead: isRead,
            isSaved: isSaved
        )
    }

    func testFirstRunPrunesAndRecordsTimestamp() {
        let old = makeItem(daysOld: 60)
        context.insert(old)

        RetentionService.pruneOldUnread(context: context, retentionDays: 30, defaults: defaults, now: Date())

        XCTAssertEqual(try? context.fetch(FetchDescriptor<LinkItem>()).count, 0)
        XCTAssertNotNil(defaults.object(forKey: "RetentionService.lastPruneDate"))
    }

    func testSecondRunWithinThrottleWindowIsSkipped() {
        let now = Date()
        let old = makeItem(daysOld: 60)
        context.insert(old)
        RetentionService.pruneOldUnread(context: context, retentionDays: 30, defaults: defaults, now: now)

        let stillOld = makeItem(daysOld: 60)
        context.insert(stillOld)
        RetentionService.pruneOldUnread(
            context: context,
            retentionDays: 30,
            defaults: defaults,
            now: now.addingTimeInterval(60 * 60) // 1 hour later, inside the 12h window
        )

        // The second item survives because the throttle window suppressed the run.
        XCTAssertEqual(try? context.fetch(FetchDescriptor<LinkItem>()).count, 1)
    }

    func testRunAfterThrottleWindowElapsesPrunesAgain() {
        let now = Date()
        let old = makeItem(daysOld: 60)
        context.insert(old)
        RetentionService.pruneOldUnread(context: context, retentionDays: 30, defaults: defaults, now: now)

        let stillOld = makeItem(daysOld: 60)
        context.insert(stillOld)
        RetentionService.pruneOldUnread(
            context: context,
            retentionDays: 30,
            defaults: defaults,
            now: now.addingTimeInterval(13 * 60 * 60) // 13 hours later, past the 12h window
        )

        XCTAssertEqual(try? context.fetch(FetchDescriptor<LinkItem>()).count, 0)
    }
}
