// Phone-owned routes, theme preferences and ephemeral workspace drafts.
// Durable values use namespaced SQLite state only; drafts remain process-local.
// Views never access SQL and a failed preference save remains visible to the user.
import SwiftUI

enum PhoneDestination: String, CaseIterable {
    case home = "new_chat"
    case search = "search"
    case email = "email"
    case tools = "tools"
    case brain = "brain"
    case calendar = "calendar"
    case compare = "compare"
    case cookbook = "cookbook"
    case research = "research"
    case gallery = "gallery"
    case library = "library"
    case notes = "notes"
    case tasks = "tasks"
    case companion = "companion"
    case theme = "theme"
    case settings = "settings"
    case account = "account"
    case models = "model_selector"
}

struct PhoneRoute: Identifiable {
    let destination: PhoneDestination
    var id: String { destination.rawValue }
    init(id: PhoneDestination,title: String,icon: String) { destination = id; self.title = title; self.icon = icon }
    var capability: PhoneCapability {
        switch destination {
        case .notes,.tasks,.calendar,.companion: return .localProductivity
        case .theme,.settings: return .appearance
        default: return .unavailable("Service execution or durable workspace storage is unavailable on iPhone.")
        }
    }
    let title: String
    let icon: String
    static let all: [PhoneRoute] = [
        .init(id:.home,title:"Home",icon:"house"), .init(id:.search,title:"Search",icon:"magnifyingglass"),
        .init(id:.email,title:"Email",icon:"envelope"), .init(id:.tools,title:"Tools",icon:"wrench.and.screwdriver"),
        .init(id:.brain,title:"Brain",icon:"brain"), .init(id:.calendar,title:"Calendar",icon:"calendar"),
        .init(id:.compare,title:"Model Compare",icon:"rectangle.split.2x1"), .init(id:.cookbook,title:"Cookbook",icon:"book"),
        .init(id:.research,title:"Deep Research",icon:"sparkle.magnifyingglass"), .init(id:.gallery,title:"Gallery",icon:"photo"),
        .init(id:.library,title:"Library",icon:"books.vertical"), .init(id:.notes,title:"Notes",icon:"note.text"),
        .init(id:.tasks,title:"Tasks",icon:"checklist"), .init(id:.companion,title:"Companion",icon:"iphone.and.arrow.forward"),
        .init(id:.theme,title:"Theme",icon:"paintpalette"), .init(id:.settings,title:"Settings",icon:"gearshape"),
        .init(id:.account,title:"Account",icon:"person.crop.circle"), .init(id:.models,title:"Models",icon:"cpu")
    ]
}

@MainActor final class PresentationStore: ObservableObject {
    @Published var destination = "new_chat"
    @Published var opaquePresentation = false
    @Published var composer = ""
    @Published var chatMode = "Chat"
    @Published var drafts: [String:String] = [:]
    @Published var selections: [String:String] = [:]
    @Published var theme = ThemeBundle.presets["forest"]!
    @Published var savedThemes: [String:ThemeBundle] = [:]
    @Published var error: String?
    private let store: LocalStore
    /// Restore validated durable preferences; corrupt state is reported, never reset.
    init(store: LocalStore) {
        self.store = store
        do {
            if let value = try store.presentationValue("destination"), PhoneRoute.all.contains(where:{ $0.id == value }) { destination = value }
            if let value = try store.presentationValue("theme") {
                let decoded = try JSONDecoder().decode(ThemeBundle.self,from:Data(value.utf8)); try decoded.validate(); theme = decoded
            }
            if let value = try store.presentationValue("savedThemes") {
                let decoded = try JSONDecoder().decode([String:ThemeBundle].self,from:Data(value.utf8))
                for bundle in decoded.values { try bundle.validate() }; savedThemes = decoded
            }
        } catch { self.error = error.localizedDescription }
    }
    /// Keep routing functional if preference persistence fails; report the failure.
    func navigate(_ id: String) {
        guard PhoneRoute.all.contains(where:{ $0.id == id }) else { return }
        destination = id
        do { try store.savePresentationValue("destination",value:id) } catch { self.error = error.localizedDescription }
    }
    /// Validate and commit before updating every observing screen and sheet.
    func apply(_ bundle: ThemeBundle) {
        do {
            try bundle.validate()
            try store.savePresentationValue("theme",value:String(decoding:JSONEncoder().encode(bundle),as:UTF8.self))
            theme = bundle; error = nil
        } catch { self.error = error.localizedDescription }
    }
    /// Duplicate imports require an explicit replacement decision in presentation.
    func saveTheme(_ bundle: ThemeBundle, replacing: Bool = false) throws {
        try bundle.validate()
        guard savedThemes[bundle.name] == nil || replacing else { throw CompanionError("A theme with this name already exists") }
        var next = savedThemes; next[bundle.name] = bundle
        try store.savePresentationValue("savedThemes",value:String(decoding:JSONEncoder().encode(next),as:UTF8.self))
        savedThemes = next
    }
    func draft(_ key: String) -> Binding<String> { Binding(get:{ self.drafts[key] ?? "" },set:{ self.drafts[key] = $0 }) }
    func selection(_ key: String, fallback: String) -> Binding<String> { Binding(get:{ self.selections[key] ?? fallback },set:{ self.selections[key] = $0 }) }
}
