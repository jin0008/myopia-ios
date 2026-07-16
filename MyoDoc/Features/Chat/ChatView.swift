import SwiftUI

/// AI 상담 화면. 어느 화면에서든 플로팅 버튼(→ `ChatLauncher`)으로 시트로 열린다.
struct ChatView: View {
    @StateObject private var vm = ChatViewModel()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                transcript
                Divider()
                inputBar
            }
            .navigationTitle("chat.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { vm.reset() } label: { Image(systemName: "arrow.counterclockwise") }
                        .disabled(vm.messages.isEmpty)
                }
            }
        }
    }

    // MARK: Transcript

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if vm.messages.isEmpty { intro }
                    ForEach(vm.messages) { msg in
                        ChatBubble(message: msg) { suggestion in
                            Task { await vm.send(suggestion) }
                        }
                        .id(msg.id)
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .onChange(of: vm.messages.count) { _, _ in
                if let last = vm.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                Text("chat.intro.title").font(.headline)
            }
            Text("chat.intro.body")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("chat.intro.disclaimer")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            ForEach(vm.starterSuggestions, id: \.self) { s in
                Button {
                    Task { await vm.send(s) }
                } label: {
                    HStack {
                        Text(s).font(.subheadline)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 10).padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: Input

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("chat.input.placeholder", text: $vm.draft, axis: .vertical)
                .lineLimit(1...4)
                .focused($inputFocused)
                .textFieldStyle(.plain)
                .padding(.vertical, 9).padding(.horizontal, 14)
                .background(Color(.secondarySystemBackground), in: Capsule())
                .onSubmit { vm.sendDraft() }
            Button {
                inputFocused = false
                vm.sendDraft()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.hierarchical)
            }
            .disabled(!vm.canSend)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.bar)
    }
}

/// One chat row: user bubble (trailing) or assistant answer (leading) with a
/// grounding badge, optional emergency styling, source links and suggestions.
private struct ChatBubble: View {
    let message: ChatMessage
    var onSuggestion: (String) -> Void

    var body: some View {
        if message.author == .user {
            HStack {
                Spacer(minLength: 40)
                Text(message.text)
                    .foregroundStyle(.white)
                    .padding(.vertical, 10).padding(.horizontal, 14)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
            }
        } else {
            assistant
        }
    }

    private var assistant: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let mode = message.mode, mode != .error {
                Text(mode.badgeText)
                    .font(.caption2.weight(.semibold))
                    .padding(.vertical, 3).padding(.horizontal, 8)
                    .background(badgeColor(mode).opacity(0.15), in: Capsule())
                    .foregroundStyle(badgeColor(mode))
            }

            if message.isPending {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("chat.thinking").font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.vertical, 10).padding(.horizontal, 14)
                .background(bubbleBg, in: RoundedRectangle(cornerRadius: 16))
            } else {
                Text(message.text)
                    .textSelection(.enabled)
                    .padding(.vertical, 10).padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(bubbleBg, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(alignment: .leading) {
                        if message.mode == .emergency {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.red)
                                .frame(width: 4)
                                .padding(.vertical, 6)
                        }
                    }
            }

            if !message.sources.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("chat.sources").font(.caption2).foregroundStyle(.secondary)
                    ForEach(message.sources) { src in
                        if let url = URL(string: src.url) {
                            Link(destination: url) {
                                Label(src.title, systemImage: "link")
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .padding(.top, 2)
            }

            if !message.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(message.suggestions, id: \.self) { s in
                        Button { onSuggestion(s) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.turn.down.right")
                                    .font(.caption2).foregroundStyle(.secondary)
                                Text(s).font(.caption).multilineTextAlignment(.leading)
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    private var bubbleBg: Color {
        message.mode == .emergency ? Color.red.opacity(0.08) : Color(.systemBackground)
    }

    private func badgeColor(_ mode: ChatMode) -> Color {
        switch mode {
        case .qa:        return .green
        case .general:   return .blue
        case .consult:   return .orange
        case .emergency: return .red
        default:         return .secondary
        }
    }
}

#Preview {
    ChatView()
}
