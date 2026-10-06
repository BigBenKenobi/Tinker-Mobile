// Brain, comparison, models and research expose distinct desktop layouts.
// Form inputs are process-local; no results, jobs or downloads are fabricated.
import SwiftUI

struct BrainWorkspace: View {
    @EnvironmentObject private var presentation: PresentationStore
    @State private var adding = false
    var body: some View {
        WorkspaceLayout(title:"Brain") {
            Panel(title:"Knowledge") {
                Picker("Collection",selection:presentation.selection("brain.tab",fallback:"Memories")) { Text("Memories").tag("Memories"); Text("Skills").tag("Skills") }.pickerStyle(.segmented)
                TextField("Search knowledge",text:presentation.draft("brain.search"))
                Button("Preview add form") { adding = true }.frame(minHeight:44)
                WorkspaceEmpty(title:"No stored knowledge",icon:"brain",reason:"Memory and skill persistence is unavailable on iPhone.")
            }
            Panel(title:"Knowledge exchange") { UnavailableAction(title:"Import · Export knowledge",reason:"Memory and skill storage and exchange are unavailable on iPhone.") }
            DisclosureGroup("Automation preferences") {
                Panel(title:"Extraction") { UnavailableAction(title:"Automatic memory extraction",reason:"Conversation extraction is unavailable."); UnavailableAction(title:"Skill suggestions",reason:"Skill generation and knowledge storage are unavailable.") }
            }
        }.sheet(isPresented:$adding) {
            NavigationStack {
                Form {
                    Section("Temporary knowledge draft") {
                        TextField("Title",text:presentation.draft("brain.title"))
                        TextEditor(text:presentation.draft("brain.body")).frame(minHeight:160).accessibilityLabel("Knowledge content")
                        TextField("Tags",text:presentation.draft("brain.tags"))
                        Picker("Confidence preview",selection:presentation.selection("brain.confidence",fallback:"Unverified")) { ForEach(["Unverified","Low","Medium","High"],id:\.self) { Text($0) } }
                    }.phoneSection()
                    Section { UnavailableAction(title:"Save knowledge",reason:"Knowledge storage is unavailable. Fields clear on restart.") }.phoneSection()
                }.navigationTitle("Add knowledge").toolbar { Button("Done") { adding = false } }
            }
        }
    }
}
struct CompareWorkspace: View {
    @EnvironmentObject private var presentation: PresentationStore
    var body: some View {
        WorkspaceLayout(title:"Model Compare") {
            Panel(title:"Comparison setup") {
                Picker("Mode",selection:presentation.selection("compare.mode",fallback:"Parallel")) { Text("Parallel").tag("Parallel"); Text("Blind").tag("Blind") }.pickerStyle(.segmented)
                TextEditor(text:presentation.draft("compare.prompt")).frame(minHeight:120).accessibilityLabel("Comparison prompt")
                ForEach(["A","B"],id:\.self) { slot in DisclosureGroup("Model " + slot) { Text("No model is available"); UnavailableAction(title:"Select model " + slot,reason:"Model services are unavailable.") } }
                UnavailableAction(title:"Run comparison",reason:"Comparison jobs and model execution are unavailable.")
            }
            Panel(title:"Results") {
                ForEach(["A","B"],id:\.self) { slot in DisclosureGroup("Response " + slot) { Text("No response has been generated.") } }
                UnavailableAction(title:"Reveal models · Pick winner",reason:"A completed comparison is required.")
            }
        }
    }
}
struct CookbookWorkspace: View {
    @EnvironmentObject private var presentation: PresentationStore
    var body: some View {
        WorkspaceLayout(title:"Cookbook") {
            Panel(title:"Local model cache") {
                TextField("Filter models",text:presentation.draft("cookbook.search"))
                Picker("View",selection:presentation.selection("cookbook.tab",fallback:"Models")) { ForEach(["Models","Dependencies","Settings"],id:\.self) { Text($0) } }.pickerStyle(.segmented)
                WorkspaceEmpty(title:"No cached models",icon:"externaldrive",reason:"The phone does not host the desktop model cache.")
            }
            Panel(title:"Model controls") { ForEach(["Launch","Download","Remove"],id:\.self) { UnavailableAction(title:$0,reason:"Desktop model/package management is unavailable on iPhone.") } }
            DisclosureGroup("Dependencies") { Text("Runtime, backend and package status require a desktop model service.") }
            DisclosureGroup("Settings") { Text("Cache folder, device selection and runtime arguments are desktop-only.") }
        }
    }
}
struct ResearchWorkspace: View {
    @EnvironmentObject private var presentation: PresentationStore
    var body: some View {
        WorkspaceLayout(title:"Deep Research") {
            Panel(title:"Research setup") {
                TextField("Research topic",text:presentation.draft("research.topic"))
                TextEditor(text:presentation.draft("research.instructions")).frame(minHeight:110).accessibilityLabel("Research instructions")
                Picker("Rounds preview",selection:presentation.selection("research.rounds",fallback:"3")) { ForEach(["1","3","5"],id:\.self) { Text($0) } }
                Picker("Report format",selection:presentation.selection("research.format",fallback:"Summary")) { ForEach(["Summary","Detailed","Sources"],id:\.self) { Text($0) } }
                UnavailableAction(title:"Provider / model",reason:"No research provider or model is connected.")
                UnavailableAction(title:"Start research",reason:"Research jobs and report storage are unavailable.")
            }
            Panel(title:"Queue") { WorkspaceEmpty(title:"No research jobs",icon:"list.bullet.rectangle",reason:"No jobs have been submitted.") }
            DisclosureGroup("Report layout") { Panel(title:"Research report") { Text("Summary · Findings · Sources").font(.headline); Text("Generated report content appears here when research support is available."); UnavailableAction(title:"Export report",reason:"No report exists to export.") } }
        }
    }
}
struct ModelsWorkspace: View {
    @EnvironmentObject private var presentation: PresentationStore
    var body: some View {
        WorkspaceLayout(title:"Models") {
            Panel(title:"Model registry") { TextField("Filter models",text:presentation.draft("models.search")); WorkspaceEmpty(title:"No available models",icon:"cpu",reason:"Model providers are not connected on iPhone.") }
            Panel(title:"Registry controls") { ForEach(["Refresh","Add model","Choose default"],id:\.self) { UnavailableAction(title:$0,reason:"Model registry and execution are unavailable.") } }
        }
    }
}
