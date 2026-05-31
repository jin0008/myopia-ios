import SwiftUI

/// One sheet covers all the write/edit cases the board needs:
/// new post, edit-an-existing post, top-level comment, and reply.
struct CommunityComposerView: View {

    enum Mode {
        case newPost
        case editPost(CommunityPostDetail)
        case comment(postId: String)
        case reply(parent: CommunityComment, postId: String)

        var needsTitle: Bool {
            switch self {
            case .newPost, .editPost: return true
            case .comment, .reply: return false
            }
        }
        var titleLocalized: LocalizedStringKey {
            switch self {
            case .newPost:   return "community.compose.newPost"
            case .editPost:  return "community.compose.editPost"
            case .comment:   return "community.compose.comment"
            case .reply:     return "community.compose.reply"
            }
        }
        var submitLocalized: LocalizedStringKey {
            switch self {
            case .editPost: return "common.save"
            case .newPost:  return "community.compose.submitPost"
            default:        return "community.compose.submitComment"
            }
        }
    }

    let mode: Mode
    /// Called with the new/updated post id (for posts) or empty string
    /// (for comments) so the caller can refresh whichever list it shows.
    var onSubmitted: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var body: String = ""
    @State private var isSubmitting = false
    @State private var error: String?
    @FocusState private var bodyFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                if case let .reply(parent, _) = mode {
                    Section {
                        Text(parent.body ?? String(localized: "community.comment.deleted"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    } header: {
                        Text("community.reply.toLabel \(parent.author.username ?? String(localized: "community.anonymous"))")
                    }
                }

                if mode.needsTitle {
                    Section(header: Text("community.compose.titleLabel")) {
                        TextField(String(localized: "community.compose.titlePlaceholder"),
                                  text: $title)
                    }
                }

                Section(header: Text("community.compose.bodyLabel")) {
                    TextEditor(text: $body)
                        .frame(minHeight: 180)
                        .focused($bodyFocused)
                }

                if let error {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle(Text(mode.titleLocalized))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: { Text("common.cancel") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text(mode.submitLocalized)
                        }
                    }
                    .disabled(canSubmit == false || isSubmitting)
                }
            }
            .onAppear {
                if case let .editPost(post) = mode {
                    title = post.title
                    body = post.body
                }
                bodyFocused = true
            }
        }
    }

    private var canSubmit: Bool {
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedBody.isEmpty { return false }
        if mode.needsTitle {
            return title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }
        return true
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            switch mode {
            case .newPost:
                let created: CommunityPostDetail = try await APIClient.shared
                    .send(.createCommunityPost(title: trimmedTitle, body: trimmedBody))
                onSubmitted(created.id)
            case .editPost(let post):
                struct EditResp: Decodable {
                    let id: String
                    let title: String
                    let body: String
                    let updatedAt: Date
                }
                let _: EditResp = try await APIClient.shared.send(
                    .updateCommunityPost(post.id, title: trimmedTitle, body: trimmedBody)
                )
                onSubmitted(post.id)
            case .comment(let postId):
                let _: CommunityComment = try await APIClient.shared.send(
                    .createCommunityComment(postId: postId, body: trimmedBody)
                )
                onSubmitted("")
            case .reply(let parent, let postId):
                let _: CommunityComment = try await APIClient.shared.send(
                    .createCommunityComment(postId: postId,
                                            body: trimmedBody,
                                            parentCommentId: parent.id)
                )
                onSubmitted("")
            }
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
