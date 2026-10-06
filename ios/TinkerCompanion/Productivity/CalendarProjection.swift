// Pure bounded phone calendar projection; no storage, notification or sync side
// effects. Calendar arithmetic follows the supplied timezone through DST changes.
import Foundation

struct ProjectedDueTask: Identifiable {
    let id: String
    let title: String
    let due: Date
    let linkedNoteID: String?
}

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
    /// task instances; only exact stored due dates, including note-owned reminders, are projected.
    static func dueTasks(_ records: [RecordVersion], interval: DateInterval) -> [ProjectedDueTask] {
        records.compactMap { row -> ProjectedDueTask? in
            guard let graph = row.value else { return nil }
            let task = graph.kind == "task" ? graph.record : graph.kind == "note" ? graph.linked_task : nil
            guard let task, !["completed","cancelled"].contains(task["status"]?.text ?? ""),
                  let due = try? Dates.parse(task["due_at"]?.text ?? ""),
                  due >= interval.start && due < interval.end else { return nil }
            return ProjectedDueTask(id:task["id"]?.text ?? graph.id,title:task["title"]?.text ?? graph.title,
                                    due:due,linkedNoteID:graph.kind == "note" ? graph.id : nil)
        }.sorted { $0.due < $1.due }
    }
}
