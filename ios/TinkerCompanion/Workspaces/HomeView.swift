// Home is the desktop composer adapted to safe phone navigation. The draft is
// owned by PresentationStore for this process only; no send/storage API exists.
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var presentation: PresentationStore
    @State private var sheet: String?
    @FocusState private var composerFocused: Bool
    var body: some View {
        WorkspaceLayout(title:"Tinker") {
            VStack(spacing:12) {
                Image(systemName:"sparkle").font(.system(size:42)).accessibilityHidden(true)
                Text("Tinker").font(.largeTitle.bold())
                Text("A space to think, make and explore.").multilineTextAlignment(.center)
                Button("Nobody") { sheet = "Nobody" }.frame(minHeight:44)
            }.frame(maxWidth:.infinity).padding(.vertical,32)
            Panel(title:"What are you thinking?") {
                TextEditor(text:$presentation.composer).focused($composerFocused).frame(minHeight:140).scrollContentBackground(.hidden).phoneInput()
                    .accessibilityLabel("Temporary composer draft").accessibilityIdentifier("home.composer")
                Picker("Mode",selection:$presentation.chatMode) { Text("Chat").tag("Chat"); Text("Agent").tag("Agent") }.pickerStyle(.segmented)
                HStack {
                    Button { sheet = "Models" } label: { Label("Choose model",systemImage:"cpu") }.frame(minHeight:44)
                    Spacer()
                    Button { sheet = "Composer tools" } label: { Image(systemName:"plus.circle") }.frame(minWidth:44,minHeight:44).accessibilityLabel("Composer tools")
                }
                UnavailableAction(title:"Send",icon:"arrow.up",reason:"Sending and conversation storage are unavailable on iPhone. This draft clears when the app restarts.")
            }
            Panel(title:"Conversation") { WorkspaceEmpty(title:"No conversation",icon:"bubble.left.and.bubble.right",reason:"No messages have been sent or saved.") }
        }.onChange(of:presentation.destination) { _,route in if route != "new_chat" { composerFocused = false } }
        .onChange(of:sheet) { _,value in presentation.opaquePresentation = value != nil }
        .sheet(isPresented:Binding(get:{ sheet != nil },set:{ if !$0 { sheet = nil } })) {
            NavigationStack {
                Group {
                    if sheet == "Models" { ModelsWorkspace() }
                    else if sheet == "Composer tools" { ToolsWorkspace() }
                    else { WorkspaceEmpty(title:"Nobody",icon:"person.crop.circle.badge.questionmark",reason:"Private conversation execution is unavailable on iPhone.") }
                }.toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { sheet = nil } } }
            }.environmentObject(presentation)
        }
    }
}
