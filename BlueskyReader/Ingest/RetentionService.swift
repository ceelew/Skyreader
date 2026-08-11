import Foundation
import SwiftData

@MainActor
enum RetentionService {
    /// Prunes unread items older than `retentionDays`. Saved items are never pruned.
    static func pruneOldUnread(context: ModelContext, retentionDays: Int) {
        guard retentionDays > 0 else { return }
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) else { return }

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
