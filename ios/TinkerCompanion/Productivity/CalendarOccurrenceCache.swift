// View-owned calendar projection cache. Storage generation and presentation keys
// invalidate it; transient sync status does not. Expansion remains the existing
// recurrence implementation so COUNT, exceptions and timezone semantics are kept.
import Foundation
import Combine

@MainActor final class CalendarOccurrenceCache: ObservableObject {
    private struct Key: Equatable {
        let generation: Int
        let calendars: Set<String>
        let lower: Date
        let upper: Date
        let timezone: String
    }
    private var key: Key?
    private var value: (occurrences:[Occurrence], errors:[String]) = ([],[])

    func projection(records: [RecordVersion], generation: Int, calendars: Set<String>,
                    lower: Date, upper: Date, timezone: String) -> (occurrences:[Occurrence], errors:[String]) {
        let next = Key(generation:generation,calendars:calendars,lower:lower,upper:upper,timezone:timezone)
        if key == next { return value }
        var occurrences: [Occurrence] = [], errors: [String] = []
        for row in records where row.kind == "event" {
            guard let graph = row.value, calendars.contains(graph.text("calendar_id")) else { continue }
            do { occurrences += try Occurrence.expand(graph,lower:lower,upper:upper) }
            catch { errors.append(graph.title + ": " + error.localizedDescription) }
        }
        value = (occurrences.sorted { $0.start < $1.start },errors)
        key = next
        return value
    }
}
