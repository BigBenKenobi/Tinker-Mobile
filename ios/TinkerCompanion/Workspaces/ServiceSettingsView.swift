// Dedicated Settings layouts adapt desktop forms while keeping unsupported
// configuration visibly unavailable. Editable fields are labelled temporary
// previews; no credential is collected and no service configuration is committed.
import SwiftUI

struct ServiceSettingsView: View {
    @EnvironmentObject private var presentation: PresentationStore
    let section: String
    @State private var temperature = 0.7
    var body: some View {
        Form {
            Section { Text("Layout preview · these temporary fields clear on restart.").font(.caption) }.phoneSection()
            switch section {
            case "Models":
                Section("Added models") { WorkspaceEmpty(title:"No registered models",icon:"cpu",reason:"Model registry storage is unavailable.") }.phoneSection()
                Section("Add model preview") {
                    TextField("Model name",text:presentation.draft("settings.model.name"))
                    TextField("Provider URL preview",text:presentation.draft("settings.model.url")).textInputAutocapitalization(.never).keyboardType(.URL)
                    Picker("Provider",selection:presentation.selection("settings.model.provider",fallback:"Local")) { ForEach(["Local","Compatible API"],id:\.self) { Text($0) } }
                    UnavailableAction(title:"Add · Verify · Remove model",reason:"Model configuration and provider authentication are unavailable.")
                }.phoneSection()
            case "AI defaults":
                Section("Generation preview") {
                    Text("Temperature preview: " + String(format:"%.1f",temperature))
                    Slider(value:$temperature,in:0...2).accessibilityLabel("Temperature preview")
                    TextField("System instruction preview",text:presentation.draft("settings.ai.system"))
                    UnavailableAction(title:"Default model · Apply defaults",reason:"No model registry or generation runtime is available.")
                }.phoneSection()
            case "Search":
                Section("Search provider preview") {
                    Picker("Provider",selection:presentation.selection("settings.search.provider",fallback:"Local")) { Text("Local").tag("Local"); Text("Web").tag("Web") }
                    TextField("Result limit preview",text:presentation.draft("settings.search.limit")).keyboardType(.numberPad)
                    UnavailableAction(title:"Connect provider · Save search defaults",reason:"Search indexes and web providers are unavailable.")
                }.phoneSection()
            case "Integrations":
                ForEach(["Files","Browser","Shell","Voice"],id:\.self) { name in
                    Section(name) { UnavailableAction(title:"Connect " + name,reason:"Desktop integration execution is unavailable on iPhone.") }.phoneSection()
                }
            case "Email":
                Section("Mail accounts") { NavigationLink("Mailboxes and accounts") { EmailWorkspace() }; UnavailableAction(title:"Connect account",reason:"Mail authentication and adapters are unavailable.") }.phoneSection()
            default:
                Section { Text("This configuration is unavailable.") }.phoneSection()
            }
        }.navigationTitle(section)
    }
}
