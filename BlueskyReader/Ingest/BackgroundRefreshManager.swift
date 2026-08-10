import Foundation
import BackgroundTasks
import SwiftData

enum BackgroundRefreshManager {
    static let taskIdentifier = "com.coreylewis.BlueskyReader.refresh"

    static func scheduleNext() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Tight-budget refresh for the background window: fewer pages, and no
    /// headline resolution (that's a lot of extra network work for a task
    /// that may get killed at any moment) — §8.
    @MainActor
    static func performRefresh(client: ATProtoClient, container: ModelContainer) async {
        scheduleNext()
        guard await client.isAuthenticated else { return }
        let context = ModelContext(container)
        let ingestService = IngestService(client: client, maxPages: 2, maxPosts: 200)
        _ = try? await ingestService.refresh(context: context)
    }
}
