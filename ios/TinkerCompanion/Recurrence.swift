// Bounded recurrence expansion shared with core/companion/recurrence.py.
// Calendar preserves event timezone/wall time across DST. DTSTART always counts;
// invalid month dates are skipped, unsupported RFC components fail explicitly.
import Foundation

struct Recurrence {
    let frequency: String?
    let interval: Int
    let count: Int
    let until: Date?
    let weekdays: Set<String>?
    static let days = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]
    init(_ text: String) throws {
        if text.isEmpty { frequency = nil; interval = 1; count = 1; until = nil; weekdays = nil; return }
        var fields: [String: String] = [:]
        for part in text.split(separator: ";", omittingEmptySubsequences: false) {
            let pair = part.split(separator: "=", omittingEmptySubsequences: false)
            guard pair.count == 2, fields[String(pair[0])] == nil else { throw CompanionError("Invalid repeat rule") }
            fields[String(pair[0])] = String(pair[1])
        }
        guard Set(fields.keys).isSubset(of: ["FREQ", "INTERVAL", "COUNT", "UNTIL", "BYDAY"]),
              let freq = fields["FREQ"], ["DAILY", "WEEKLY", "MONTHLY", "YEARLY"].contains(freq) else { throw CompanionError("Unsupported repeat rule") }
        guard let step = Int(fields["INTERVAL"] ?? "1"), (1...366).contains(step),
              let limit = Int(fields["COUNT"] ?? "10000"), (1...10000).contains(limit),
              fields["COUNT"] == nil || fields["UNTIL"] == nil else { throw CompanionError("Invalid repeat interval/count") }
        frequency = freq; interval = step; count = limit
        if let ending = fields["UNTIL"] {
            let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(secondsFromGMT: 0); f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"; f.isLenient = false
            guard let d = f.date(from: ending), f.string(from: d) == ending else { throw CompanionError("UNTIL must be a UTC timestamp") }; until = d
        } else { until = nil }
        if let byday = fields["BYDAY"] {
            let days = byday.components(separatedBy: ",")
            guard freq == "WEEKLY", Set(days).count == days.count, Set(days).isSubset(of: Set(Self.days)) else { throw CompanionError("BYDAY supports weekly weekdays only") }; weekdays = Set(days)
        } else { weekdays = nil }
    }
    func occurrences(start: Date, timezone: String, lower: Date, upper: Date) throws -> [Date] {
        guard upper > lower else { return [] }
        guard let zone = TimeZone(identifier: timezone) else { throw CompanionError("Unknown timezone") }
        guard let frequency else { return lower <= start && start < upper ? [start] : [] }
        guard upper.timeIntervalSince(start) <= 36600 * 86400 else { throw CompanionError("Recurrence window exceeds 100 years") }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = zone
        let original = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .weekday], from: start)
        let mondayIndex = ((original.weekday ?? 1) + 5) % 7
        var result: [Date] = [], seen = 0
        for offset in 0...36600 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { break }
            var components = calendar.dateComponents([.year, .month, .day, .weekday], from: day)
            components.hour = original.hour; components.minute = original.minute; components.second = original.second
            guard let candidate = calendar.date(from: components) else { continue }
            if candidate >= upper || (until != nil && candidate > until!) { break }
            var matches = offset == 0
            if !matches {
                switch frequency {
                case "DAILY": matches = offset % interval == 0
                case "WEEKLY":
                    let weekday = Self.days[((components.weekday ?? 1) + 5) % 7]
                    matches = ((offset + mondayIndex) / 7) % interval == 0 && (weekdays ?? [Self.days[mondayIndex]]).contains(weekday)
                case "MONTHLY":
                    let months = ((components.year ?? 0) - (original.year ?? 0)) * 12 + (components.month ?? 0) - (original.month ?? 0)
                    matches = months % interval == 0 && components.day == original.day
                default: matches = ((components.year ?? 0) - (original.year ?? 0)) % interval == 0 && components.month == original.month && components.day == original.day
                }
            }
            guard matches else { continue }
            seen += 1; if seen > count { break }
            if candidate >= lower { result.append(candidate) }
        }
        return result
    }
}

/// Calendar presentation applies exceptions after recurrence; moved instances may enter the visible range.
struct Occurrence: Identifiable {
    let id: String
    let graph: Graph
    let original: Date
    let start: Date
    let end: Date
    let title: String
    static func expand(_ graph: Graph, lower: Date, upper: Date) throws -> [Occurrence] {
        let start = try Dates.parse(graph.text("start_at")), end = try Dates.parse(graph.text("end_at"))
        let rule = try Recurrence(graph.text("recurrence"))
        let duration = end.timeIntervalSince(start)
        var dates = Set(try rule.occurrences(start: start, timezone: graph.text("timezone"), lower: lower.addingTimeInterval(-duration), upper: upper))
        for exception in graph.exceptions { dates.insert(try Dates.parse(exception.occurrence_at)) }
        var result: [Occurrence] = []
        for original in dates.sorted() {
            let exception = graph.exceptions.first { (try? Dates.parse($0.occurrence_at)) == original }
            if exception?.cancelled == true { continue }
            let shifted = try exception?.start_at.map(Dates.parse) ?? original
            let shiftedEnd = try exception?.end_at.map(Dates.parse) ?? shifted.addingTimeInterval(duration)
            if shifted < upper && shiftedEnd > lower {
                result.append(Occurrence(id: graph.id + "@" + Dates.stamp(original), graph: graph, original: original, start: shifted, end: shiftedEnd, title: exception?.title ?? graph.title))
            }
        }
        return result
    }
}
