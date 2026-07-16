import SwiftUI

/// Floating "AI 상담" button that can sit on top of any screen and presents the
/// chatbot as a sheet. Mirrors the web prototype's bottom-right chat launcher.
///
/// Apply once near the app root (see `MainTabView`) so it floats over every tab:
///
///     TabView { ... }.chatLauncher()
///
private struct ChatLauncherModifier: ViewModifier {
    @State private var showChat = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showChat = true
                } label: {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.accentColor, in: Circle())
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                }
                .accessibilityLabel(Text("chat.launch"))
                // Lift above the floating tab bar.
                .padding(.trailing, 18)
                .padding(.bottom, 74)
            }
            .sheet(isPresented: $showChat) {
                ChatView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
    }
}

extension View {
    /// Adds the floating AI-상담 launcher + chat sheet.
    func chatLauncher() -> some View {
        modifier(ChatLauncherModifier())
    }
}
