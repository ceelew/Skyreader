import Foundation

enum ItemFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case unread = "Unread"
    case saved = "Saved"

    var id: String { rawValue }
}
