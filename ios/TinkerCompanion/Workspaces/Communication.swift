// Search, Email and composer tools are dedicated visual workspaces. Session-only
// fields are retained by PresentationStore; absent mail/search services never run.
import SwiftUI

struct SearchWorkspace: View {
    @EnvironmentObject private var presentation: PresentationStore
    var body: some View {
        WorkspaceLayout(title:"Search") {
            Panel(title:"Find in Tinker") {
                TextField("Search conversations and library",text:presentation.draft("search.query")).textFieldStyle(.roundedBorder)
                Picker("Scope",selection:presentation.selection("search.scope",fallback:"All")) { ForEach(["All","Chats","Documents","Research"],id:\.self) { Text($0) } }
                UnavailableAction(title:"Search",icon:"magnifyingglass",reason:"Searchable conversation and library storage is unavailable on iPhone.")
            }
            Panel(title:"Results") { WorkspaceEmpty(title:"No searchable items",icon:"magnifyingglass",reason:"Notes and Tasks have their own working local search.") }
        }
    }
}
struct EmailWorkspace: View {
    @EnvironmentObject private var presentation: PresentationStore
    @State private var composing = false
    @State private var accounts = false
    var body: some View {
        WorkspaceLayout(title:"Email") {
            Panel(title:"Mailbox") {
                Picker("Mailbox",selection:presentation.selection("email.mailbox",fallback:"Inbox")) { ForEach(["Inbox","Sent","Drafts","Archive","Trash"],id:\.self) { Text($0) } }
                TextField("Filter messages",text:presentation.draft("email.filter")).textFieldStyle(.roundedBorder)
                Toggle("Unread only",isOn:Binding(get:{ presentation.selections["email.unread"] == "yes" },set:{ presentation.selections["email.unread"] = $0 ? "yes" : "no" }))
                HStack { Button("Compose") { composing = true }.frame(minHeight:44); Spacer(); Button("Accounts") { accounts = true }.frame(minHeight:44) }
            }
            Panel(title:"Messages") { WorkspaceEmpty(title:"No messages in " + (presentation.selections["email.mailbox"] ?? "Inbox"),icon:"tray",reason:"Email accounts and message storage are unavailable. Compose is a temporary draft only.") }
            DisclosureGroup("Message detail layout") {
                Panel(title:"Message") { Text("From · To · Subject").font(.caption); Text("Message body appears here when mail support is available."); UnavailableAction(title:"Reply",reason:"No message is available to reply to.") }
            }
        }.sheet(isPresented:$composing) {
            NavigationStack {
                Form {
                    Section("Temporary draft") {
                        TextField("To",text:presentation.draft("email.to")).keyboardType(.emailAddress).textInputAutocapitalization(.never)
                        TextField("Subject",text:presentation.draft("email.subject"))
                        TextEditor(text:presentation.draft("email.body")).frame(minHeight:160).accessibilityLabel("Email body").phoneInput()
                    }.phoneSection()
                    Section { UnavailableAction(title:"Send email",icon:"paperplane",reason:"No mail service or durable email storage is available. Draft clears on restart.") }.phoneSection()
                }.navigationTitle("Compose").toolbar { Button("Done") { composing = false } }
            }
        }.sheet(isPresented:$accounts) {
            NavigationStack {
                WorkspaceLayout(title:"Email accounts") {
                    Panel(title:"Connect an account") {
                        TextField("Email address",text:presentation.draft("email.account")).textInputAutocapitalization(.never)
                        UnavailableAction(title:"Connect",reason:"Account authentication and mail adapters are unavailable.")
                    }
                }.toolbar { Button("Done") { accounts = false } }
            }
        }
    }
}
struct ToolsWorkspace: View {
    @EnvironmentObject private var presentation: PresentationStore
    var body: some View {
        WorkspaceLayout(title:"Tools") {
            Panel(title:"Attachments and actions") {
                ForEach(["Attach file","Web search","Capture screen","Voice input"],id:\.self) { action in
                    UnavailableAction(title:action,icon:"plus",reason:"This composer integration is unavailable on iPhone.")
                }
            }
            Panel(title:"Prompt Studio") {
                Picker("Prompt mode",selection:presentation.selection("prompt.mode",fallback:"Inject")) { ForEach(["Inject","Persona","Group"],id:\.self) { Text($0) } }.pickerStyle(.segmented)
                TextField("Name",text:presentation.draft("prompt.name"))
                TextEditor(text:presentation.draft("prompt.body")).frame(minHeight:140).accessibilityLabel("Prompt draft").phoneInput()
                Text("Draft text is temporary and is never executed or saved as a prompt record.").font(.caption)
                UnavailableAction(title:"Apply prompt",reason:"Prompt injection and persona/group execution are unavailable.")
            }
            Panel(title:"Desktop controls") { UnavailableAction(title:"Peek · Minimize · Resize",reason:"Floating window controls are desktop-only. On iPhone, use full-screen destinations and sheets.") }
        }
    }
}
