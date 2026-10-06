// Gallery and Library expose collection/detail/editor navigation with truthful
// empty states. Editor controls are previews; no durable image or library writes.
import SwiftUI

struct GalleryWorkspace: View {
    @EnvironmentObject private var presentation: PresentationStore
    @State private var editor = false
    var body: some View {
        WorkspaceLayout(title:"Gallery") {
            Panel(title:"Collections") {
                Picker("Collection",selection:presentation.selection("gallery.tab",fallback:"Photos")) { Text("Photos").tag("Photos"); Text("Albums").tag("Albums") }.pickerStyle(.segmented)
                TextField("Search photos and albums",text:presentation.draft("gallery.search"))
                WorkspaceEmpty(title:"No gallery items",icon:"photo.on.rectangle",reason:"Gallery storage is unavailable.")
                Button("Preview editor layout") { editor = true }.frame(minHeight:44)
                UnavailableAction(title:"Import photo · Create album",reason:"Durable Gallery operations are unavailable.")
            }
        }.sheet(isPresented:$editor) {
            NavigationStack {
                WorkspaceLayout(title:"Image editor") {
                    Panel(title:"Canvas") { Rectangle().fill(presentation.theme.color("input_bg")).frame(height:200).overlay(Text("No image loaded").foregroundStyle(.secondary)); Text("Editor layout preview").font(.caption) }
                    Panel(title:"Tools") {
                        Picker("Tool preview",selection:presentation.selection("gallery.tool",fallback:"Select")) { ForEach(["Select","Crop","Draw","Erase","Inpaint"],id:\.self) { Text($0) } }
                        TextField("Inpaint prompt",text:presentation.draft("gallery.inpaint"))
                        UnavailableAction(title:"Apply edit · Run inpaint",reason:"Image processing and durable editing are unavailable.")
                    }
                    DisclosureGroup("Layers") { Text("No layers exist without an image."); UnavailableAction(title:"Add layer",reason:"Layer storage is unavailable.") }
                    DisclosureGroup("History") { Text("No image edits have occurred.") }
                    UnavailableAction(title:"Save · Export",reason:"No image exists to save or export.")
                }.toolbar { Button("Done") { editor = false } }
            }
        }
    }
}
struct LibraryWorkspace: View {
    @EnvironmentObject private var presentation: PresentationStore
    @State private var detail = false
    var body: some View {
        WorkspaceLayout(title:"Library") {
            Panel(title:"Library") {
                Picker("Collection",selection:presentation.selection("library.tab",fallback:"Chats")) { ForEach(["Chats","Documents","Research","Archive"],id:\.self) { Text($0) } }
                TextField("Search library",text:presentation.draft("library.search"))
                WorkspaceEmpty(title:"No library records",icon:"books.vertical",reason:"Conversation, document and report storage are unavailable.")
                Button("Preview detail layout") { detail = true }.frame(minHeight:44)
            }
        }.sheet(isPresented:$detail) {
            NavigationStack {
                WorkspaceLayout(title:"Library detail preview") {
                    Panel(title:"Document / report") { Text("Title · Type · Modified date").font(.caption); Text("No stored document or report is selected."); DisclosureGroup("Sources and metadata") { Text("No metadata exists.") } }
                    UnavailableAction(title:"Open · Share · Archive · Delete",reason:"Durable library records are unavailable.")
                }.toolbar { Button("Done") { detail = false } }
            }
        }
    }
}
struct SettingsView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        List {
            Section("Appearance") { NavigationLink("Themes and backgrounds") { ThemeView() } }.phoneSection()
            Section("Local Data") { Text("Notes, Tasks and Calendar are stored on this iPhone."); Text("\(model.store.records.count) local domain records"); Text("\(model.store.pendingCount) pending edits"); UnavailableAction(title:"Reset local data",reason:"Destructive reset requires a separate recovery workflow.") }.phoneSection()
            Section("Reminders") { Text(model.notifications.status); Button("Enable iPhone notifications") { Task { await model.notifications.authorize(); await model.reconcileReminders() } } }.phoneSection()
            Section("Desktop-only") { UnavailableAction(title:"Edit shortcuts · Peek · Window geometry",reason:"Desktop shortcuts and floating windows are represented by phone navigation.") }.phoneSection()
            ForEach(["Models","AI defaults","Search","Integrations","Email"],id:\.self) { name in Section(name) { NavigationLink("Configure " + name) { ServiceSettingsView(section:name) } }.phoneSection().phoneSection() }
        }.navigationTitle("Settings")
    }
}
struct AccountView: View {
    @EnvironmentObject private var presentation: PresentationStore
    var body: some View {
        WorkspaceLayout(title:"Account") {
            Panel(title:"Profile") { TextField("Display name preview",text:presentation.draft("account.name")); UnavailableAction(title:"Save profile · Sign in",reason:"Account authentication and profile storage are unavailable.") }
            Panel(title:"Study Mode") { UnavailableAction(title:"Enable Study Mode",reason:"Study Mode execution is unavailable on iPhone.") }
        }
    }
}
