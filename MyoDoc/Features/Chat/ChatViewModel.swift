import Foundation

/// Drives the AI 상담 (RAG chatbot) conversation against POST /api/mobile/chat.
///
/// Design notes:
///  - The server does the grounding, safety filtering and usage-limiting. The
///    client only keeps the transcript and renders the returned `mode` badge,
///    suggestions and sources.
///  - `history` sent to the server is capped (server also caps) and only carries
///    plain text turns, never the UI metadata.
@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var draft: String = ""
    @Published var isSending = false

    private let maxHistoryTurns = 6

    /// Opening greeting + a few starter prompts, shown before the first question.
    let starterSuggestions = [
        "아트로핀 넣고 눈부셔하는데 괜찮나요?",
        "드림렌즈는 어떤 원리인가요?",
        "야외활동은 하루 얼마나 해야 하나요?"
    ]

    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    func reset() {
        messages.removeAll()
        draft = ""
    }

    func sendDraft() {
        let q = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        draft = ""
        Task { await send(q) }
    }

    func send(_ question: String) async {
        guard !isSending else { return }
        isSending = true
        defer { isSending = false }

        messages.append(ChatMessage(author: .user, text: question))
        let pendingIndex = messages.count
        messages.append(ChatMessage(author: .assistant, text: "", isPending: true))

        let history = buildHistory()
        do {
            let resp: ChatResponse = try await APIClient.shared.send(
                .chat(question: question, history: history))
            messages[pendingIndex] = ChatMessage(
                author: .assistant,
                text: resp.answer,
                mode: resp.mode,
                suggestions: resp.suggestions,
                sources: resp.sources
            )
        } catch {
            messages[pendingIndex] = ChatMessage(
                author: .assistant,
                text: "지금은 답변을 만들 수 없어요. 잠시 후 다시 시도해 주세요.",
                mode: .error
            )
        }
    }

    /// Recent turns as {role,text}, excluding the just-added pending bubble.
    private func buildHistory() -> [ChatTurn] {
        let turns: [ChatTurn] = messages.compactMap { msg in
            guard !msg.isPending, !msg.text.isEmpty else { return nil }
            return ChatTurn(role: msg.author == .user ? "user" : "model", text: msg.text)
        }
        return Array(turns.suffix(maxHistoryTurns * 2))
    }
}
