// Files-based calendar exchange matching the desktop's supported ICS subset.
// Parse all VEVENTs/alarms before storing anything. Stable UIDs connect imports to
// existing records; EXDATE and RECURRENCE-ID become owned exceptions. Unsupported
// recurrence/alarm semantics fail explicitly instead of dropping user data.
import Foundation

struct ICS {
    struct Property { let value: String; let params: [String:String] }
    typealias Properties = [String:[Property]]
    static func escape(_ value: String) -> String {
        value.replacingOccurrences(of:"\\",with:"\\\\").replacingOccurrences(of:"\r\n",with:"\n").replacingOccurrences(of:"\r",with:"\n").replacingOccurrences(of:"\n",with:"\\n").replacingOccurrences(of:";",with:"\\;").replacingOccurrences(of:",",with:"\\,")
    }
    static func unescape(_ value: String) -> String {
        var result = "", escaped = false
        for char in value {
            if escaped { result += char == "n" || char == "N" ? "\n" : String(char); escaped = false }
            else if char == "\\" { escaped = true } else { result.append(char) }
        }
        if escaped { result += "\\" }; return result
    }
    static func fold(_ line: String) -> String {
        var segments: [String] = [], part = ""
        for scalar in line.unicodeScalars {
            let char = String(scalar)
            if (part + char).utf8.count > 75 { segments.append(part); part = " " }
            part += char
        }
        return (segments + [part]).joined(separator:"\r\n")
    }
    static func date(_ property: Property, timezone: String) throws -> (Date,Bool) {
        let allDay = property.params["VALUE"] == "DATE" || property.value.count == 8
        let utc = property.value.hasSuffix("Z")
        let zone = utc ? TimeZone(secondsFromGMT:0) : TimeZone(identifier:property.params["TZID"] ?? timezone)
        guard let zone else { throw CompanionError("Unknown ICS timezone") }
        let f = DateFormatter(); f.locale = Locale(identifier:"en_US_POSIX"); f.calendar = Calendar(identifier:.gregorian); f.timeZone = zone; f.isLenient = false
        f.dateFormat = allDay ? "yyyyMMdd" : (utc ? "yyyyMMdd'T'HHmmss'Z'" : "yyyyMMdd'T'HHmmss")
        guard let result = f.date(from:property.value), f.string(from:result) == property.value else { throw CompanionError("Invalid ICS timestamp") }
        return (result,allDay)
    }
    static func parse(_ source: String, defaultTimezone: String = TimeZone.current.identifier) throws -> [Graph] {
        guard source.utf8.count <= 4 * 1024 * 1024, TimeZone(identifier:defaultTimezone) != nil else { throw CompanionError("Invalid or oversized ICS file") }
        let unfolded = source.replacingOccurrences(of:"\r?\n[ \t]",with:"",options:.regularExpression).replacingOccurrences(of:"\r\n",with:"\n")
        let lines = unfolded.components(separatedBy:"\n")
        guard lines.contains("BEGIN:VCALENDAR"), lines.contains("END:VCALENDAR") else { throw CompanionError("Not a VCALENDAR") }
        var events: [(Properties,[Properties])] = [], event: Properties?, alarm: Properties?, alarms: [Properties] = []
        for line in lines where !line.isEmpty {
            guard let colon = line.firstIndex(of:":") else { throw CompanionError("Malformed ICS content line") }
            let tokens = line[..<colon].components(separatedBy:";")
            let key = tokens[0].uppercased(), value = String(line[line.index(after:colon)...])
            var params: [String:String] = [:]
            for token in tokens.dropFirst() {
                guard let equal = token.firstIndex(of:"=") else { throw CompanionError("Invalid ICS parameter") }
                params[String(token[..<equal]).uppercased()] = String(token[token.index(after:equal)...]).trimmingCharacters(in:CharacterSet(charactersIn:"\""))
            }
            if key == "BEGIN", value == "VEVENT" {
                guard event == nil else { throw CompanionError("Nested event") }; event = [:]; alarms = []
            } else if key == "BEGIN", value == "VALARM" {
                guard event != nil, alarm == nil else { throw CompanionError("Misplaced alarm") }; alarm = [:]
            } else if key == "END", value == "VALARM" {
                guard let finished = alarm else { throw CompanionError("Unbalanced alarm") }; alarms.append(finished); alarm = nil
            } else if key == "END", value == "VEVENT" {
                guard let finished = event, alarm == nil else { throw CompanionError("Unbalanced event") }; events.append((finished,alarms)); event = nil
            } else if alarm != nil { alarm![key,default:[]].append(Property(value:value,params:params)) }
            else if event != nil { event![key,default:[]].append(Property(value:value,params:params)) }
        }
        guard event == nil, alarm == nil, events.count <= 1000 else { throw CompanionError("Unclosed or oversized calendar") }
        var bases: [String:Graph] = [:], overrides: [(String,EventException)] = []
        for (properties,alarms) in events {
            guard Set(properties.keys).isDisjoint(with:["RDATE","DURATION","EXRULE"]) else { throw CompanionError("RDATE, DURATION and EXRULE are not supported") }
            func one(_ key: String, _ fallback: String? = nil) throws -> Property? {
                let values = properties[key] ?? []; guard values.count <= 1 else { throw CompanionError("Duplicate \(key)") }
                return values.first ?? fallback.map { Property(value:$0,params:[:]) }
            }
            guard let uid = try one("UID")?.value, let first = try one("DTSTART") else { throw CompanionError("Event requires UID and DTSTART") }
            try Graph.identifier(uid)
            let zone = first.params["TZID"] ?? (first.value.hasSuffix("Z") ? "UTC" : defaultTimezone)
            let (start,allDay) = try date(first,timezone:zone)
            let end: Date
            if let last = try one("DTEND") {
                let (parsed,day) = try date(last,timezone:zone); guard day == allDay else { throw CompanionError("Mixed DATE and DATE-TIME") }; end = parsed
            } else {
                var calendar = Calendar(identifier:.gregorian); calendar.timeZone = TimeZone(identifier:zone)!
                end = allDay ? calendar.date(byAdding:.day,value:1,to:start)! : start.addingTimeInterval(3600)
            }
            let title = unescape(try one("SUMMARY","Untitled event")!.value)
            let repeatRule = try one("RRULE")?.value ?? ""; _ = try Recurrence(repeatRule)
            if let recurrenceID = try one("RECURRENCE-ID") {
                let (original,_) = try date(recurrenceID,timezone:zone)
                overrides.append((uid,EventException(id:Dates.id("exception"),event_id:uid,occurrence_at:Dates.stamp(original),cancelled:try one("STATUS")?.value == "CANCELLED",start_at:Dates.stamp(start),end_at:Dates.stamp(end),title:title)))
                continue
            }
            guard bases[uid] == nil else { throw CompanionError("Duplicate event UID") }
            var g = Graph.new("event"); g.set("id",uid); g.set("ics_uid",uid); g.set("title",title); g.set("start_at",Dates.stamp(start)); g.set("end_at",Dates.stamp(end)); g.record["all_day"] = .bool(allDay); g.set("timezone",zone); g.optional("recurrence",repeatRule)
            g.set("description",unescape(try one("DESCRIPTION","")!.value)); g.set("location",unescape(try one("LOCATION","")!.value))
            for a in alarms {
                guard Set(a.keys).isSubset(of:["ACTION","TRIGGER","DESCRIPTION"]), a.values.allSatisfy({ $0.count == 1 }), a["ACTION"]?.first?.value == "DISPLAY", let trigger = a["TRIGGER"]?.first else { throw CompanionError("Only one-shot DISPLAY alarms are supported") }
                let fire: Date
                if trigger.value.hasPrefix("-P") {
                    guard trigger.params["RELATED"] == nil || trigger.params["RELATED"] == "START" else { throw CompanionError("End-relative alarms are not supported") }
                    let pattern = "^-P(?:(\\d+)D)?(?:T(?:(\\d+)H)?(?:(\\d+)M)?(?:(\\d+)S)?)?$"
                    let regex = try NSRegularExpression(pattern:pattern)
                    let range = NSRange(trigger.value.startIndex...,in:trigger.value)
                    guard let match = regex.firstMatch(in:trigger.value,range:range) else { throw CompanionError("Invalid alarm duration") }
                    let values = (1...4).map { i -> Int in
                        guard let r = Range(match.range(at:i),in:trigger.value) else { return 0 }; return Int(trigger.value[r]) ?? 0
                    }
                    guard values.contains(where:{ $0 > 0 }) else { throw CompanionError("Invalid alarm duration") }
                    fire = start.addingTimeInterval(-Double(values[0]*86400 + values[1]*3600 + values[2]*60 + values[3]))
                } else { fire = try date(trigger,timezone:zone).0 }
                g.reminders.append(Reminder(id:Dates.id("reminder"),owner_kind:"event",owner_id:uid,fire_at:Dates.stamp(fire),message:unescape(a["DESCRIPTION"]?.first?.value ?? title)))
            }
            for property in properties["EXDATE"] ?? [] {
                for part in property.value.components(separatedBy:",") {
                    let (original,_) = try date(Property(value:part,params:property.params),timezone:zone)
                    g.exceptions.append(EventException(id:Dates.id("exception"),event_id:uid,occurrence_at:Dates.stamp(original),cancelled:true,start_at:nil,end_at:nil,title:nil))
                }
            }
            bases[uid] = g
        }
        for (uid,exception) in overrides {
            guard bases[uid] != nil else { throw CompanionError("Exception has no parent event in this file") }
            bases[uid]!.exceptions.removeAll { $0.occurrence_at == exception.occurrence_at }; bases[uid]!.exceptions.append(exception)
        }
        // The owning calendar is chosen by LocalStore after parsing succeeds.
        return bases.values.sorted { $0.id < $1.id }
    }
    static func export(_ graphs: [Graph]) throws -> String {
        var lines = ["BEGIN:VCALENDAR","VERSION:2.0","PRODID:-//Tinker//Companion 1//EN","CALSCALE:GREGORIAN"]
        for g in graphs {
            try g.validate(); guard g.kind == "event" else { throw CompanionError("ICS export contains only calendar events") }
            let zone = TimeZone(identifier:g.text("timezone"))!
            func line(_ name: String, _ value: String) throws -> String {
                let f = DateFormatter(); f.locale = Locale(identifier:"en_US_POSIX"); f.timeZone = zone
                if g.flag("all_day") { f.dateFormat = "yyyyMMdd"; return name + ";VALUE=DATE:" + f.string(from:try Dates.parse(value)) }
                if zone.identifier == "GMT" || g.text("timezone") == "UTC" { f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"; return name + ":" + f.string(from:try Dates.parse(value)) }
                f.dateFormat = "yyyyMMdd'T'HHmmss"; return name + ";TZID=" + g.text("timezone") + ":" + f.string(from:try Dates.parse(value))
            }
            func utc(_ value: String) throws -> String {
                let f = DateFormatter(); f.locale = Locale(identifier:"en_US_POSIX"); f.timeZone = TimeZone(secondsFromGMT:0); f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"; return f.string(from:try Dates.parse(value))
            }
            lines += ["BEGIN:VEVENT","UID:"+g.id,"DTSTAMP:"+(try utc(g.text("updated_at"))),try line("DTSTART",g.text("start_at")),try line("DTEND",g.text("end_at")),"SUMMARY:"+escape(g.title),"DESCRIPTION:"+escape(g.text("description")),"LOCATION:"+escape(g.text("location"))]
            if !g.text("recurrence").isEmpty { lines.append("RRULE:"+g.text("recurrence")) }
            for reminder in g.reminders where !reminder.completed { lines += ["BEGIN:VALARM","ACTION:DISPLAY","TRIGGER;VALUE=DATE-TIME:"+(try utc(reminder.fire_at)),"DESCRIPTION:"+escape(reminder.message),"END:VALARM"] }
            lines.append("END:VEVENT")
            let duration = try Dates.parse(g.text("end_at")).timeIntervalSince(Dates.parse(g.text("start_at")))
            for e in g.exceptions {
                let end = try e.end_at ?? Dates.stamp(Dates.parse(e.occurrence_at).addingTimeInterval(duration))
                lines += ["BEGIN:VEVENT","UID:"+g.id,try line("RECURRENCE-ID",e.occurrence_at),try line("DTSTART",e.start_at ?? e.occurrence_at),try line("DTEND",end),"SUMMARY:"+escape(e.title ?? g.title)]
                if e.cancelled { lines.append("STATUS:CANCELLED") }; lines.append("END:VEVENT")
            }
        }
        lines.append("END:VCALENDAR"); return lines.map(fold).joined(separator:"\r\n") + "\r\n"
    }
}
