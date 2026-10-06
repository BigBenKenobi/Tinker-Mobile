// Local notification reconciliation for explicitly phone-owned reminders.
// A pure planner derives the next bounded request set from durable graphs before
// Notifications mutates UNUserNotificationCenter. Stable reminder/occurrence IDs
// make foreground and background reconciliation replace rather than duplicate.
import Foundation
import UserNotifications

struct PlannedNotification: Equatable {
    let identifier: String
    let date: Date
    let title: String
    let message: String
}

enum NotificationPlanner {
    static let horizon: TimeInterval = 30 * 86400
    static let limit = 60

    static func plan(_ records: [RecordVersion], now: Date = Date()) throws -> [PlannedNotification] {
        let upper = now.addingTimeInterval(horizon)
        var planned: [PlannedNotification] = []
        for graph in records.compactMap(\.value) {
            let task = graph.kind == "task" ? graph.record : graph.kind == "note" ? graph.linked_task : nil
            if let task, task["kind"]?.text == "reminder", task["notification_owner"]?.text == "phone",
               task["status"]?.text == "pending", task["paused"]?.flag != true {
                let taskID = task["id"]?.text ?? graph.id
                for occurrence in try taskOccurrences(task,now:now,upper:upper) {
                    planned.append(PlannedNotification(identifier:"tinker:task:"+taskID+"@"+Dates.stamp(occurrence),date:occurrence,
                                                       title:task["title"]?.text ?? graph.title,message:task["description"]?.text ?? ""))
                }
            }
            for reminder in graph.reminders where !reminder.completed && reminder.notification_owner == "phone" {
                let fire = try Dates.parse(reminder.fire_at)
                if graph.kind == "event" && !graph.text("recurrence").isEmpty {
                    let originalStart = try Dates.parse(graph.text("start_at"))
                    let offset = fire.timeIntervalSince(originalStart)
                    let rule = try Recurrence(graph.text("recurrence"))
                    var starts = Set(try rule.occurrences(start:originalStart,timezone:graph.text("timezone"),lower:now.addingTimeInterval(-offset),upper:upper.addingTimeInterval(-offset)))
                    for exception in graph.exceptions { starts.insert(try Dates.parse(exception.occurrence_at)) }
                    for original in starts {
                        let exception = graph.exceptions.first { (try? Dates.parse($0.occurrence_at)) == original }
                        if exception?.cancelled == true { continue }
                        let actual = try exception?.start_at.map(Dates.parse) ?? original
                        let when = actual.addingTimeInterval(offset)
                        if when > now && when < upper {
                            planned.append(PlannedNotification(identifier:"tinker:"+reminder.id+"@"+Dates.stamp(original),date:when,
                                                               title:exception?.title ?? graph.title,message:reminder.message))
                        }
                    }
                } else if fire > now && fire < upper {
                    planned.append(PlannedNotification(identifier:"tinker:"+reminder.id+"@"+reminder.fire_at,date:fire,title:graph.title,message:reminder.message))
                }
            }
        }
        planned.sort { $0.date == $1.date ? $0.identifier < $1.identifier : $0.date < $1.date }
        return Array(planned.prefix(limit))
    }

    private static func taskOccurrences(_ task: [String:JSONValue], now: Date, upper: Date) throws -> [Date] {
        let due = try Dates.parse(task["due_at"]?.text ?? "")
        let frequency = task["recurrence"]?.text ?? "none"
        if frequency == "none" { return due > now && due < upper ? [due] : [] }
        guard ["daily","weekly","monthly","yearly"].contains(frequency) else { throw CompanionError("Unsupported task recurrence") }
        guard let zone = TimeZone(identifier:task["timezone_name"]?.text ?? "") else { throw CompanionError("Unknown timezone") }
        let anchorText = task["recurrence_anchor"]?.text ?? ""
        let anchor = anchorText.isEmpty ? due : try Dates.parse(anchorText)
        var calendar = Calendar(identifier:.gregorian); calendar.timeZone = zone
        let component: Calendar.Component = frequency == "daily" ? .day : frequency == "weekly" ? .weekOfYear : frequency == "monthly" ? .month : .year
        var step = estimatedStep(from:anchor,to:now,frequency:frequency,calendar:calendar)
        var result: [Date] = []
        while true {
            guard let candidate = calendar.date(byAdding:component,value:step,to:anchor) else { throw CompanionError("Cannot expand task recurrence") }
            if candidate >= upper { break }
            if candidate > now { result.append(candidate) }
            step += 1
        }
        return result
    }

    private static func estimatedStep(from anchor: Date, to now: Date, frequency: String, calendar: Calendar) -> Int {
        if now < anchor { return 0 }
        switch frequency {
        case "daily":
            let days = calendar.dateComponents([.day],from:calendar.startOfDay(for:anchor),to:calendar.startOfDay(for:now)).day ?? 0
            return max(0,days - 1)
        case "weekly":
            let days = calendar.dateComponents([.day],from:calendar.startOfDay(for:anchor),to:calendar.startOfDay(for:now)).day ?? 0
            return max(0,days / 7 - 1)
        case "monthly":
            let months = calendar.dateComponents([.month],from:anchor,to:now).month ?? 0
            return max(0,months - 1)
        default:
            let years = calendar.dateComponents([.year],from:anchor,to:now).year ?? 0
            return max(0,years - 1)
        }
    }
}

@MainActor final class Notifications: NSObject, UNUserNotificationCenterDelegate, ObservableObject {
    @Published private(set) var status = "Notifications have not been enabled"
    private let center = UNUserNotificationCenter.current()
    override init() { super.init(); center.delegate = self }
    func authorize() async {
        do { let allowed = try await center.requestAuthorization(options:[.alert,.sound,.badge]); status = allowed ? "Notifications enabled" : "Notifications are disabled in iPhone Settings" }
        catch { status = error.localizedDescription }
    }
    func cancelAll() async {
        let ids = await center.pendingNotificationRequests().filter { $0.identifier.hasPrefix("tinker:") }.map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers:ids)
        center.removeAllDeliveredNotifications()
    }
    func reconcile(_ records: [RecordVersion], now: Date = Date()) async throws {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { status = "Enable notifications in iPhone Settings"; return }
        // Finish the fallible plan before changing pending requests, so corrupt
        // local input cannot partially replace a previously valid schedule.
        let planned = try NotificationPlanner.plan(records,now:now)
        let ids = Set(planned.map(\.identifier))
        let old = await center.pendingNotificationRequests().filter { $0.identifier.hasPrefix("tinker:") && !ids.contains($0.identifier) }.map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers:old)
        for item in planned {
            let content = UNMutableNotificationContent(); content.title = item.title.isEmpty ? "Tinker reminder" : item.title; content.body = item.message; content.sound = .default
            var calendar = Calendar(identifier:.gregorian); calendar.timeZone = TimeZone(secondsFromGMT:0)!
            var components = calendar.dateComponents([.year,.month,.day,.hour,.minute,.second],from:item.date); components.timeZone = calendar.timeZone
            let trigger = UNCalendarNotificationTrigger(dateMatching:components,repeats:false)
            try await center.add(UNNotificationRequest(identifier:item.identifier,content:content,trigger:trigger))
        }
        status = "\(planned.count) upcoming phone reminders scheduled"
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner,.sound])
    }
}
