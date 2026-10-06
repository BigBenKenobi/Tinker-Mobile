// Pure bounded phone calendar projection; no storage, notification or sync side
// effects. Calendar arithmetic follows the supplied timezone through DST changes.
import Foundation

enum CalendarProjection {
    /// Month/week/day expansion is limited to the selected calendar period.
    static func interval(containing day: Date, mode: String, calendar: Calendar = .current) -> DateInterval {
        let component: Calendar.Component = mode == "Month" ? .month : mode == "Week" ? .weekOfYear : .day
        return calendar.dateInterval(of:component,for:day)!
    }
    static func days(in interval: DateInterval, calendar: Calendar = .current) -> [Date] {
        var result: [Date] = []; var day = interval.start
        while day < interval.end && result.count < 42 {
            result.append(day)
            guard let next = calendar.date(byAdding:.day,value:1,to:day), next > day else { break }; day = next
        }
        return result
    }
    /// Tasks are projected without manufacturing calendar events or recurring
    /// task instances; only the exact stored due date is shown in the period.
    static func dueTasks(_ records: [RecordVersion], interval: DateInterval) -> [Graph] {
        records.filter { $0.kind == "task" }.compactMap(\.value).filter {
            guard !["completed","cancelled"].contains($0.text("status")), let due = try? Dates.parse($0.text("due_at")) else { return false }
            return due >= interval.start && due < interval.end
        }.sorted { $0.text("due_at") < $1.text("due_at") }
    }
}
