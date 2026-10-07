// Read-only ICS replacement plans shared by LocalStore and the import sheet.
// Plans retain the parsed file and opening tokens until one atomic commit. Identity
// matching preserves calendar membership and the delivery owner of matching alarms.
import Foundation

struct EventImportPlan: Identifiable {
    struct Entry: Equatable {
        let graph: Graph
        let expected: EditToken
    }
    let id = UUID()
    let sources: [Graph]
    let targetCalendarID: String
    let calendarToken: EditToken
    let entries: [Entry]

    /// Match each alarm once by absolute time/message or its relative offset.
    /// Unchanged alarms keep completion and delivery ownership; exceptions retain
    /// their occurrence identity. Removed children are visible replacement effects.
    static func preservingIdentity(_ source: Graph, existing: Graph) throws -> Graph {
        var graph = source
        graph.set("id",existing.id)
        graph.set("calendar_id",existing.text("calendar_id"))
        graph.set("created_at",existing.text("created_at"))
        let oldStart = try Dates.parse(existing.text("start_at"))
        let newStart = try Dates.parse(graph.text("start_at"))
        var remaining = existing.reminders
        graph.reminders = try graph.reminders.map { imported in
            var alarm = imported
            alarm.owner_id = existing.id
            let fire = try Dates.parse(alarm.fire_at)
            if let index = remaining.firstIndex(where:{ previous in
                guard previous.message == alarm.message, let oldFire = try? Dates.parse(previous.fire_at) else { return false }
                return oldFire == fire || oldFire.timeIntervalSince(oldStart) == fire.timeIntervalSince(newStart)
            }) {
                let previous = remaining.remove(at:index)
                alarm.id = previous.id
                alarm.notification_owner = previous.notification_owner
                alarm.completed = previous.completed
            }
            return alarm
        }
        graph.exceptions = graph.exceptions.map { imported in
            var exception = imported
            exception.event_id = existing.id
            if let previous = existing.exceptions.first(where:{ $0.occurrence_at == exception.occurrence_at }) {
                exception.id = previous.id
            }
            return exception
        }
        return graph
    }
}
