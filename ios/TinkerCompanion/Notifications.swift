// Local notification reconciliation for explicitly phone-owned reminders.
// AppModel calls this after edits and committed sync. IDs include stable reminder
// and original occurrence identities, so reconnection/repeated scheduling replaces
// pending requests. Desktop-owned reminders never enter iOS's notification queue.
import Foundation
import UserNotifications

@MainActor final class Notifications: NSObject, UNUserNotificationCenterDelegate, ObservableObject {
    @Published private(set) var status = "Notifications have not been enabled"
    private let center = UNUserNotificationCenter.current()
    private let isolated: Bool
    /// Isolated UI fixtures never claim the notification-center delegate or permissions.
    init(isolated: Bool = false) { self.isolated = isolated; super.init(); if !isolated { center.delegate = self } }
    func authorize() async {
        guard !isolated else { return }
        do { let allowed = try await center.requestAuthorization(options:[.alert,.sound,.badge]); status = allowed ? "Notifications enabled" : "Notifications are disabled in iPhone Settings" }
        catch { status = error.localizedDescription }
    }
    func cancelAll() async {
        guard !isolated else { return }
        let ids = await center.pendingNotificationRequests().filter { $0.identifier.hasPrefix("tinker:") }.map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers:ids)
        center.removeAllDeliveredNotifications()
    }
    func reconcile(_ records: [RecordVersion], now: Date = Date()) async throws {
        guard !isolated else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { status = "Enable notifications in iPhone Settings"; return }
        let upper = now.addingTimeInterval(30 * 86400)
        var planned: [(String,Date,String,String)] = []
        for graph in records.compactMap(\.value) {
            if graph.kind == "task", ["completed","cancelled"].contains(graph.text("status")) { continue }
            let task = graph.kind == "task" ? graph.record : graph.kind == "note" ? graph.linked_task : nil
            if let task, task["kind"]?.text == "reminder", task["notification_owner"]?.text == "phone",
               !["completed","cancelled"].contains(task["status"]?.text ?? ""),
               let due = try? Dates.parse(task["due_at"]?.text ?? "") {
                var next = due
                let frequency = task["recurrence"]?.text ?? "none"
                var calendar = Calendar(identifier:.gregorian)
                calendar.timeZone = TimeZone(identifier:task["timezone_name"]?.text ?? "UTC") ?? .current
                for _ in 0..<60 {
                    if next > now && next < upper {
                        planned.append(("tinker:task:" + (task["id"]?.text ?? graph.id) + "@" + Dates.stamp(next), next,
                                        task["title"]?.text ?? graph.title, task["description"]?.text ?? ""))
                    }
                    guard frequency != "none" else { break }
                    let component: Calendar.Component = frequency == "daily" ? .day : frequency == "weekly" ? .weekOfYear : frequency == "monthly" ? .month : .year
                    guard let following = calendar.date(byAdding:component,value:1,to:next), following > next else { break }
                    next = following
                    if next >= upper { break }
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
                        if when > now && when < upper { planned.append(("tinker:"+reminder.id+"@"+Dates.stamp(original),when,exception?.title ?? graph.title,reminder.message)) }
                    }
                } else if fire > now && fire < upper {
                    planned.append(("tinker:"+reminder.id+"@"+reminder.fire_at,fire,graph.title,reminder.message))
                }
            }
        }
        // iOS has a finite pending-request budget. Keep the next 60 occurrences,
        // leave room for system use, and refill on foreground/best-effort refresh.
        planned.sort { $0.1 < $1.1 }; planned = Array(planned.prefix(60))
        let ids = Set(planned.map { $0.0 })
        let old = await center.pendingNotificationRequests().filter { $0.identifier.hasPrefix("tinker:") && !ids.contains($0.identifier) }.map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers:old)
        for (id,date,title,message) in planned {
            let content = UNMutableNotificationContent(); content.title = title.isEmpty ? "Tinker reminder" : title; content.body = message; content.sound = .default
            var calendar = Calendar(identifier:.gregorian); calendar.timeZone = TimeZone(secondsFromGMT:0)!
            var components = calendar.dateComponents([.year,.month,.day,.hour,.minute,.second],from:date); components.timeZone = calendar.timeZone
            let trigger = UNCalendarNotificationTrigger(dateMatching:components,repeats:false)
            try await center.add(UNNotificationRequest(identifier:id,content:content,trigger:trigger))
        }
        status = "\(planned.count) upcoming phone reminders scheduled"
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner,.sound])
    }
}
