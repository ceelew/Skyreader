import Foundation
import SwiftData

@MainActor
enum RetentionService {
    private static let lastPruneKey = "RetentionService.lastPruneDate"
    private static let throttleInterval: TimeInterval = 12 * 60 * 60

    /// Prunes unread items older than `retentionDays`. Saved items are never pruned.
    ///
    /// Called from ReadingListView's `.task`, which re-runs every time the list
    /// appears — so this is throttled to at most once per `throttleInterval`,
    /// tracked via `defaults`, to avoid a redundant fetch/delete pass on every
    /// tab switch or foreground.
    static func pruneOldUnread(
        context: ModelContext,
        retentionDays: Int,
        defaults: UserDefaults = .standard,
        now: Date = Date()
    ) {
        guard retentionDays > 0 else { return }
        if let last = defaults.object(forKey: lastPruneKey) as? Date,
           now.timeIntervalSince(last) < throttleInterval {
            return
        }
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: now) else { return }

        defaults.set(now, forKey: lastPruneKey)

        let descriptor = FetchDescriptor<LinkItem>(
            predicate: #Predicate<LinkItem> { !$0.isSaved && $0.appearedAt < cutoff }
        )
        guard let candidates = try? context.fetch(descriptor) else { return }
        for item in candidates where !item.isRead {
            context.delete(item)
        }
        try? context.save()
    }

    /// Manual "Remove read items now" action — deletes every read item
    /// regardless of age. Saved items are never pruned.
    static func pruneRead(context: ModelContext) {
        let descriptor = FetchDescriptor<LinkItem>(
            predicate: #Predicate<LinkItem> { !$0.isSaved && $0.isRead }
        )
        guard let candidates = try? context.fetch(descriptor) else { return }
        for item in candidates {
            context.delete(item)
        }
        try? context.save()
    }
}
