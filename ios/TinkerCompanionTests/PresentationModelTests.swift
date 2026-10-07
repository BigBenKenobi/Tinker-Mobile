// Native acceptance of phone-only persistence and desktop theme interchange.
// Temporary SQLite stores isolate tests from production data, Keychain and sync.
import XCTest
@testable import TinkerCompanion

@MainActor final class PresentationModelTests: XCTestCase {
    private func location() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("presentation.sqlite3") }
    /// Named theme and active appearance survive reopen without any sync mutation.
    func testThemePersistenceDoesNotEnterOutbox() throws {
        let path = location()
        let store = try LocalStore(path:path)
        let owner = PresentationStore(store:store)
        let theme = ThemeBundle.presets["ocean"]!
        owner.apply(theme); try owner.saveTheme(theme); owner.navigate("notes")
        XCTAssertNil(owner.error); XCTAssertEqual(store.pendingCount,0)
        XCTAssertTrue(store.records.isEmpty); XCTAssertNil(try store.cursor)
        let reopened = PresentationStore(store:try LocalStore(path:path))
        XCTAssertEqual(reopened.theme,theme); XCTAssertEqual(reopened.destination,"notes")
        XCTAssertEqual(reopened.savedThemes["Ocean"],theme)
        XCTAssertEqual(reopened.composer,"")
    }
    func testAllDesktopPalettesRoundTrip() throws {
        XCTAssertEqual(ThemeBundle.presets.count,16)
        for theme in ThemeBundle.presets.values {
            try theme.validate()
            let decoded = try JSONDecoder().decode(ThemeBundle.self,from:JSONEncoder().encode(theme))
            XCTAssertEqual(decoded,theme)
            XCTAssertEqual(Set(theme.palette.keys),Set(ThemeBundle.roles))
        }
    }
    func testMalformedThemePreservesCurrentChoice() throws {
        let owner = PresentationStore(store:try LocalStore(path:location()))
        let original = owner.theme
        var invalid = original; invalid.palette["text"] = "red"
        owner.apply(invalid); XCTAssertNotNil(owner.error); XCTAssertEqual(owner.theme,original)
        invalid = original; invalid.version = 2; XCTAssertThrowsError(try invalid.validate())
        invalid = original; invalid.effect.speed = .infinity; XCTAssertThrowsError(try invalid.validate())
        invalid = original; invalid.effect.quality = 3; XCTAssertThrowsError(try invalid.validate())
    }
    func testDuplicateThemeRequiresReplacement() throws {
        let owner = PresentationStore(store:try LocalStore(path:location()))
        let original = owner.theme; try owner.saveTheme(original)
        var changed = original; changed.effect.name = "Rain"
        XCTAssertThrowsError(try owner.saveTheme(changed))
        XCTAssertEqual(owner.savedThemes[original.name],original)
        try owner.saveTheme(changed,replacing:true)
        XCTAssertEqual(owner.savedThemes[original.name],changed)
    }
    func testIsolatedModelCannotPairOrSync() async throws {
        let store = try LocalStore(path:location())
        let model = try AppModel(store:store,isolated:true)
        model.foreground(); await model.pair(qr:"not an invitation")
        XCTAssertNil(model.pairing); XCTAssertFalse(model.syncing)
        XCTAssertEqual(model.error,"Pairing is disabled in isolated tests")
        await model.sync(); await model.reconcileReminders()
        XCTAssertTrue(store.records.isEmpty); XCTAssertEqual(store.pendingCount,0)
    }
    func testCalendarWeekUsesNZDSTAndBoundedDays() throws {
        var calendar = Calendar(identifier:.gregorian)
        calendar.timeZone = TimeZone(identifier:"Pacific/Auckland")!
        calendar.firstWeekday = 2
        let day = try Dates.parse("2026-09-27T12:00:00+13:00")
        let interval = CalendarProjection.interval(containing:day,mode:"Week",calendar:calendar)
        XCTAssertEqual(CalendarProjection.days(in:interval,calendar:calendar).count,7)
        XCTAssertEqual(interval.duration,167*3600)
        let month = CalendarProjection.interval(containing:day,mode:"Month",calendar:calendar)
        XCTAssertEqual(CalendarProjection.days(in:month,calendar:calendar).count,30)
    }
    func testDueTasksAreProjectionWithoutEventWrites() throws {
        var task = Graph.new("task"); task.set("due_at","2026-09-27T12:00:00+13:00")
        let store = try LocalStore(path:location()); try store.edit(task,kind:"task",id:task.id)
        let interval = DateInterval(start:try Dates.parse("2026-09-26T00:00:00Z"),end:try Dates.parse("2026-09-28T00:00:00Z"))
        let pending = store.pendingCount
        XCTAssertEqual(CalendarProjection.dueTasks(store.records,interval:interval).map(\.id),[task.id])
        XCTAssertEqual(store.pendingCount,pending); XCTAssertFalse(store.records.contains { $0.kind == "event" })
    }
    func testRenderedTextContrastDoesNotMutateDesktopPalette() throws {
        for theme in ThemeBundle.presets.values {
            let original = theme.palette
            for role in ["text","muted","accent"] {
                for surface in ["background","panel","input_bg","send_bg"] {
                    let accessible = ThemeBundle.accessibleHex(theme.palette[role]!,against:theme.palette[surface]!)
                    XCTAssertGreaterThanOrEqual(ThemeBundle.contrast(accessible,theme.palette[surface]!),4.5,"Unreadable " + role + " on " + surface)
                }
            }
            XCTAssertEqual(theme.palette,original)
        }
    }
    func testDesktopOmittedTypographyAndEffectDefaults() throws {
        let palette = ThemeBundle.presets["forest"]!.palette
        let data = try JSONSerialization.data(withJSONObject:["version":1,"name":" Minimal desktop ","palette":palette])
        let decoded = try JSONDecoder().decode(ThemeBundle.self,from:data)
        XCTAssertEqual(decoded.name,"Minimal desktop")
        XCTAssertEqual(decoded.typography.font,"Monospace")
        XCTAssertEqual(decoded.effect.name,"Solid")
        XCTAssertEqual(decoded.effect.color,palette["accent"])
    }
    func testActualDesktopBundlePreservesAllInterchangeFields() throws {
        let url = try XCTUnwrap(Bundle(for:Self.self).url(forResource:"theme-v1",withExtension:"json"))
        let source = try Data(contentsOf:url)
        let imported = try JSONDecoder().decode(ThemeBundle.self,from:source)
        try imported.validate()
        let exported = try JSONEncoder().encode(imported)
        let original = try JSONSerialization.jsonObject(with:source) as? NSDictionary
        let roundTrip = try JSONSerialization.jsonObject(with:exported) as? NSDictionary
        XCTAssertEqual(original,roundTrip)
        XCTAssertEqual(imported.typography.font,"Serif")
        XCTAssertEqual(imported.effect.name,"Rain")
        XCTAssertTrue(imported.effect.paused)
    }
    func testLinkedNoteReminderProjectsWithoutCreatingIndependentTask() throws {
        var note = Graph.new("note"); var task = Graph.new("task").record
        task["note_id"] = .string(note.id); task["kind"] = .string("reminder")
        task["due_at"] = .string("2026-09-27T12:00:00+13:00"); note.linked_task = task
        let store = try LocalStore(path:location()); try store.edit(note,kind:"note",id:note.id)
        let interval = DateInterval(start:try Dates.parse("2026-09-26T00:00:00Z"),end:try Dates.parse("2026-09-28T00:00:00Z"))
        let projected = CalendarProjection.dueTasks(store.records,interval:interval)
        XCTAssertEqual(projected.count,1); XCTAssertEqual(projected.first?.id,task["id"]?.text)
        XCTAssertEqual(projected.first?.linkedNoteID,note.id)
        XCTAssertEqual(store.records.count,1); XCTAssertEqual(store.records.first?.kind,"note")
        XCTAssertEqual(store.pendingCount,1)
    }
}
