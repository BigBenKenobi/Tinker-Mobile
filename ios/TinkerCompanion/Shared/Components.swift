// Shared presentation vocabulary. Unsupported operations have visible reasons
// and disabled controls with no service closure; previews never fabricate records.
import SwiftUI

enum PhoneCapability {
    case localProductivity, appearance, unavailable(String), desktopOnly(String)
    var reason: String? {
        switch self {
        case .localProductivity, .appearance: return nil
        case .unavailable(let reason), .desktopOnly(let reason): return reason
        }
    }
}
struct UnavailableAction: View {
    let title: String
    var icon = "lock"
    let reason: String
    var body: some View {
        VStack(alignment:.leading,spacing:4) {
            Button {} label: { Label(title,systemImage:icon).frame(minHeight:44) }.disabled(true).accessibilityHint(reason)
            Text(reason).font(.caption).foregroundStyle(.secondary)
        }
    }
}
struct WorkspaceEmpty: View {
    let title: String
    let icon: String
    let reason: String
    var body: some View { ContentUnavailableView(title,systemImage:icon,description:Text(reason)).frame(maxWidth:.infinity).padding(.vertical) }
}
struct Panel<Content: View>: View {
    @EnvironmentObject private var presentation: PresentationStore
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let title: String
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment:.leading,spacing:presentation.theme.spacing) {
            Text(title).font(.headline)
            content()
        }.frame(maxWidth:.infinity,alignment:.leading).padding(presentation.theme.spacing)
            .background {
                if presentation.theme.typography.frosted && !reduceTransparency { RoundedRectangle(cornerRadius:16).fill(.regularMaterial) }
                else { RoundedRectangle(cornerRadius:16).fill(presentation.theme.color("panel")) }
            }
            .overlay(RoundedRectangle(cornerRadius:16).stroke(presentation.theme.color("border"),lineWidth:1))
    }
}
struct WorkspaceLayout<Content: View>: View {
    @EnvironmentObject private var presentation: PresentationStore
    let title: String
    @ViewBuilder var content: () -> Content
    var body: some View {
        ScrollView { VStack(alignment:.leading,spacing:presentation.theme.spacing) { content() }.padding() }
            .background(presentation.theme.color("background").opacity(title == "Tinker" ? 0 : 1))
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
}

/// Apply semantic row surfaces to native Lists/Forms, including editor sheets.
struct PhoneSectionStyle: ViewModifier {
    @EnvironmentObject private var presentation: PresentationStore
    func body(content: Content) -> some View {
        content.listRowBackground(presentation.theme.color("panel"))
    }
}
extension View {
    func phoneSection() -> some View { modifier(PhoneSectionStyle()) }
}
