// Native phone shell consumes canonical desktop route IDs in desktop order.
// One presentation owner retains temporary drafts and appearance across tools;
// mounted navigation stacks retain selection and editors without storing records.
import SwiftUI

struct RootView: View {
    @ObservedObject var model: AppModel
    @StateObject private var presentation: PresentationStore
    @ScaledMetric(relativeTo:.body) private var bodySize: CGFloat = 17
    @State private var drawer = false
    init(model: AppModel) {
        self.model = model
        _presentation = StateObject(wrappedValue:PresentationStore(store:model.store))
    }
    var body: some View {
        ZStack {
            BackgroundView(theme:presentation.theme,visible:!drawer && !presentation.opaquePresentation && ["new_chat","theme"].contains(presentation.destination))
            ZStack {
                ForEach(PhoneRoute.all) { route in
                    NavigationStack {
                        destination(route.destination)
                            .scrollContentBackground(.hidden)
                            .background(presentation.theme.color("background").opacity(route.id == "new_chat" ? 0 : 1))
                            .toolbar {
                                ToolbarItem(placement:.topBarLeading) {
                                    Button { withAnimation { drawer.toggle() } } label: { Label("Tools",systemImage:"line.3.horizontal") }
                                        .accessibilityIdentifier("shell.tools").frame(minWidth:44,minHeight:44)
                                }
                                ToolbarItem(placement:.topBarTrailing) {
                                    Button { presentation.navigate("companion") } label: {
                                        Image(systemName:model.syncing ? "arrow.triangle.2.circlepath" : "iphone.and.arrow.forward")
                                    }.accessibilityLabel("Companion: " + model.connection).frame(minWidth:44,minHeight:44)
                                }
                            }
                            .toolbarBackground(presentation.theme.color("panel"),for:.navigationBar)
                            .toolbarBackground(.visible,for:.navigationBar)
                    }
                    .opacity(presentation.destination == route.id ? 1 : 0)
                    .allowsHitTesting(presentation.destination == route.id)
                    .accessibilityHidden(presentation.destination != route.id)
                    .zIndex(presentation.destination == route.id ? 1 : 0)
                }
            }
            if drawer {
                GeometryReader { geometry in
                    ZStack(alignment:.leading) {
                        Color.black.opacity(0.45).ignoresSafeArea().onTapGesture { withAnimation { drawer = false } }.accessibilityLabel("Close tool drawer")
                        ScrollView {
                            VStack(alignment:.leading,spacing:8) {
                                HStack { Text("Tinker").font(.largeTitle.bold()); Spacer(); Button { drawer = false } label: { Image(systemName:"xmark") }.accessibilityLabel("Close tools").frame(minWidth:44,minHeight:44) }
                                ForEach(PhoneRoute.all) { route in
                                    Button { presentation.navigate(route.id); withAnimation { drawer = false } } label: {
                                        HStack { Label(route.title,systemImage:route.icon); Spacer(); if route.id == presentation.destination { Image(systemName:"checkmark") } }
                                            .frame(maxWidth:.infinity,minHeight:44,alignment:.leading).padding(.horizontal,8)
                                    }.accessibilityIdentifier("route." + route.id)
                                }
                            }.padding()
                        }.frame(width:min(320,geometry.size.width * 0.88)).background(presentation.theme.color("sidebar"))
                    }
                }.transition(.move(edge:.leading)).zIndex(3)
            }
        }
        .safeAreaInset(edge:.bottom) {
            if model.isolated { Text("Preview/test fixture · isolated local data").font(.caption).frame(maxWidth:.infinity).padding(6).background(presentation.theme.color("panel")) }
        }
        .environmentObject(presentation)
        .tint(presentation.theme.color("accent"))
        .foregroundStyle(presentation.theme.color("text"))
        .font(.system(size:bodySize * (presentation.theme.typography.text_size == "Small" ? 0.9 : presentation.theme.typography.text_size == "Large" ? 1.15 : 1),design:presentation.theme.fontDesign))
        .fontDesign(presentation.theme.fontDesign)
        .environment(\.defaultMinListRowHeight,44)
        .preferredColorScheme(presentation.theme.isLight ? .light : .dark)
        .alert("Presentation settings",isPresented:Binding(get:{ presentation.error != nil },set:{ if !$0 { presentation.error = nil } })) { Button("OK") { presentation.error = nil } } message: { Text(presentation.error ?? "") }
    }
    /// Route construction owns no domain writes; functional tools reuse AppModel.
    @ViewBuilder private func destination(_ id: PhoneDestination) -> some View {
        switch id {
        case .home: HomeView()
        case .notes: DomainView(model:model,kind:"note")
        case .tasks: DomainView(model:model,kind:"task")
        case .calendar: CalendarView(model:model)
        case .companion: CompanionView(model:model)
        case .theme: ThemeView()
        case .settings: SettingsView(model:model)
        case .account: AccountView()
        case .search: SearchWorkspace()
        case .email: EmailWorkspace()
        case .brain: BrainWorkspace()
        case .compare: CompareWorkspace()
        case .cookbook: CookbookWorkspace()
        case .research: ResearchWorkspace()
        case .gallery: GalleryWorkspace()
        case .library: LibraryWorkspace()
        case .models: ModelsWorkspace()
        case .tools: ToolsWorkspace()
        }
    }
}
