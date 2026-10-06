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
    @EnvironmentObject private var presentation: PresentationStore
    let title: String
    var icon = "lock"
    let reason: String
    var body: some View {
        VStack(alignment:.leading,spacing:4) {
            Button {} label: {
                Label(title,systemImage:icon).frame(minHeight:44).padding(.horizontal,8)
                    .background(title.hasPrefix("Send") ? presentation.theme.color("send_bg") : Color.clear,in:Capsule())
            }.disabled(true).accessibilityHint(reason)
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
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        content.listRowBackground(Group {
            if presentation.theme.typography.frosted && !reduceTransparency { Rectangle().fill(.regularMaterial) }
            else { presentation.theme.color("panel") }
        })
    }
}
extension View {
    func phoneSection() -> some View { modifier(PhoneSectionStyle()) }
    func phoneInput() -> some View { modifier(PhoneInputStyle()) }
}

/// Native fields consume the input role rather than the platform's black fill.
/// The same surface styles multiline editors without changing their bindings.
struct PhoneInputStyle: ViewModifier {
    @EnvironmentObject private var presentation: PresentationStore
    func body(content: Content) -> some View {
        content.scrollContentBackground(.hidden).padding(8)
            .background(presentation.theme.color("input_bg"),in:RoundedRectangle(cornerRadius:8))
            .overlay(RoundedRectangle(cornerRadius:8).stroke(presentation.theme.color("border"),lineWidth:1))
    }
}
struct PhoneTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View { configuration.phoneInput() }
}

/// Expand the actual label hit region, not just the surrounding layout frame.
/// Empty HStack spacers must activate their row instead of the drawer backdrop.
struct PhoneButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.frame(minWidth:44,minHeight:44)
            .contentShape(Rectangle())
            .opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.45)
    }
}
