import Foundation

enum DateGrouping {
    /// "Today" / "Yesterday" / "Friday, August 8" (adds year if not the current year).
    static func sectionLabel(for date: Date, calendar: Calendar = .current, now: Date = Date()) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) { return "Yesterday" }

        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        let formatter = DateFormatter()
        formatter.dateFormat = sameYear ? "EEEE, MMMM d" : "EEEE, MMMM d, yyyy"
        return formatter.string(from: date)
    }

    /// Start-of-day key used to bucket items into sections, so items ingested at
    /// different times on the same day group together.
    static func dayKey(for date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }
}
