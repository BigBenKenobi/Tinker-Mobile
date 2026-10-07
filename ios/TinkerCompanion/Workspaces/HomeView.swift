// Minimal home owns layout and focus; drafts remain process-local in PresentationStore.
// No chat transport exists yet, so Send stays disabled and never discards the draft.
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var presentation: PresentationStore
    @FocusState private var composerFocused: Bool
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 48
    var body: some View {
        VStack {
            Spacer(minLength: 16)
            Text("Tinker")
                .font(.system(size: titleSize, weight: .bold, design: presentation.theme.fontDesign))
                .lineLimit(1).minimumScaleFactor(0.5)
                .accessibilityAddTraits(.isHeader).accessibilityIdentifier("home.title")
                .frame(maxWidth: .infinity)
            Spacer(minLength: 24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 0) {
                    ForEach(["Chat", "Agent"], id: \.self) { mode in
                        Button { presentation.chatMode = mode } label: {
                            Text(mode).font(.caption).padding(.horizontal, 12).frame(minHeight: 44)
                                .background(presentation.chatMode == mode ? presentation.theme.color("border") : Color.clear, in: Capsule())
                        }.buttonStyle(.plain)
                            .accessibilityLabel(mode + " mode")
                            .accessibilityAddTraits(presentation.chatMode == mode ? .isSelected : [])
                            .accessibilityIdentifier("home.mode." + mode.lowercased())
                    }
                }.background(presentation.theme.color("panel"), in: Capsule())
                HStack(alignment: .bottom, spacing: 8) {
                    TextEditor(text: $presentation.composer)
                        .frame(height: 88).scrollContentBackground(.hidden).focused($composerFocused)
                        .accessibilityLabel("Message").accessibilityIdentifier("home.composer")
                        .padding(.vertical, 12)
                    Button {} label: {
                        Image(systemName: "arrow.up").font(.body.weight(.semibold))
                            .frame(width: 36, height: 36)
                            .background(presentation.theme.color("border"), in: Circle())
                            .frame(width: 44, height: 44)
                    }.buttonStyle(.plain).disabled(true)
                        .accessibilityLabel("Send message")
                        .accessibilityHint("Message sending is not connected yet. Your draft is retained while the app is open.")
                        .accessibilityIdentifier("home.send")
                }.padding(.horizontal, 12).padding(.vertical, 4)
                    .background(presentation.theme.color("input_bg"), in: RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(presentation.theme.color("border"), lineWidth: 1))
            }.padding(.horizontal, 16).padding(.bottom, 8)
        }
        .onChange(of: presentation.destination) { _, route in
            if route != "new_chat" { composerFocused = false }
        }
    }
}
