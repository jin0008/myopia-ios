import SwiftUI

/// Detail view for a single post: title, body, like button, then the
/// flat comment list with replies indented under their parent.
struct CommunityDetailView: View {
    let postId: String
    /// Callback fired when something that affects the parent list
    /// changed (post deleted, like toggled, new comment, etc.).
    var onChange: (() -> Void)?

    @StateObject private var model: CommunityDetailModel
    @State private var replyTarget: CommunityComment?
    @State private var showComposer = false
    @State private var editingPost = false
    @Environment(\.dismiss) private var dismiss

    init(postId: String, onChange: (() -> Void)? = nil) {
        self.postId = postId
        self.onChange = onChange
        _model = StateObject(wrappedValue: CommunityDetailModel(postId: postId))
    }

    var body: some View {
        content
            .toolbar {
                if let post = model.post, post.author.isMe {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                editingPost = true
                            } label: { Label("common.edit", systemImage: "pencil") }
                            Button(role: .destructive) {
                                Task {
                                    if await model.deletePost() {
                                        onChange?()
                                        dismiss()
                                    }
                                }
                            } label: { Label("common.delete", systemImage: "trash") }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showComposer, onDismiss: { replyTarget = nil }) {
                CommunityComposerView(
                    mode: replyTarget.map { .reply(parent: $0, postId: postId) }
                        ?? .comment(postId: postId)
                ) { _ in
                    Task {
                        await model.reload()
                        onChange?()
                    }
                }
                // Liquid Glass (iOS 26): glass sheet + detents/grabber.
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $editingPost) {
                if let post = model.post {
                    CommunityComposerView(mode: .editPost(post)) { _ in
                        Task {
                            await model.reload()
                            onChange?()
                        }
                    }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
            }
            .task { await model.load() }
            .refreshable { await model.reload() }
    }

    @ViewBuilder
    private var content: some View {
        if let post = model.post {
            List {
                Section { postHeader(post) }
                Section {
                    if model.comments.isEmpty {
                        Text("community.comments.empty")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.threads, id: \.root.id) { thread in
                            VStack(alignment: .leading, spacing: 0) {
                                commentRow(thread.root, isReply: false)
                                ForEach(thread.replies) { reply in
                                    commentRow(reply, isReply: true)
                                        .padding(.leading, 24)
                                }
                            }
                        }
                    }
                } header: {
                    Text("community.comments.title \(post.commentCount)")
                }
            }
            .navigationTitle(Text("community.post"))
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) { composeBar }
        } else if let error = model.error {
            ContentUnavailableView(
                String(localized: "common.error"),
                systemImage: "exclamationmark.triangle",
                description: Text(error)
            )
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func postHeader(_ post: CommunityPostDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(post.title).font(.title2).bold()
            HStack(spacing: 8) {
                Label(post.author.username ?? String(localized: "community.anonymous"),
                      systemImage: "person.crop.circle")
                Text("·").foregroundStyle(.tertiary)
                Text(post.createdAt, style: .relative)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Text(post.body)
                .font(.body)
                .padding(.top, 4)
            HStack {
                Button {
                    Task { await model.togglePostLike() }
                } label: {
                    Label("\(post.likeCount)",
                          systemImage: post.likedByMe ? "heart.fill" : "heart")
                        .foregroundStyle(post.likedByMe ? .pink : .secondary)
                }
                .glassButton()   // Liquid Glass (iOS 26): glass capsule (was .bordered)
                Label("\(post.commentCount)", systemImage: "bubble.left")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .font(.subheadline)
            .padding(.top, 6)
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func commentRow(_ comment: CommunityComment, isReply: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if isReply {
                    Image(systemName: "arrow.turn.down.right")
                        .foregroundStyle(.tertiary)
                }
                Text(comment.author.username ?? String(localized: "community.anonymous"))
                    .font(.subheadline).bold()
                Text(comment.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if comment.deleted {
                Text("community.comment.deleted")
                    .italic()
                    .foregroundStyle(.tertiary)
            } else {
                Text(comment.body ?? "")
                    .font(.body)
            }
            HStack(spacing: 14) {
                Button {
                    Task { await model.toggleCommentLike(comment) }
                } label: {
                    Label("\(comment.likeCount)",
                          systemImage: comment.likedByMe ? "heart.fill" : "heart")
                        .foregroundStyle(comment.likedByMe ? .pink : .secondary)
                }
                .buttonStyle(.borderless)
                if isReply == false && comment.deleted == false {
                    Button {
                        replyTarget = comment
                        showComposer = true
                    } label: {
                        Label("community.reply", systemImage: "arrowshape.turn.up.left")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
                Spacer()
                if comment.author.isMe && comment.deleted == false {
                    Button(role: .destructive) {
                        Task { await model.deleteComment(comment) }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }

    private var composeBar: some View {
        HStack {
            Button {
                replyTarget = nil
                showComposer = true
            } label: {
                HStack {
                    Image(systemName: "square.and.pencil")
                    Text("community.compose.commentPlaceholder")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                // Liquid Glass (iOS 26): glass capsule field (was secondarySystemBackground).
                .glassControl(in: Capsule())
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .background(.bar)
    }
}

@MainActor
final class CommunityDetailModel: ObservableObject {
    let postId: String

    @Published private(set) var post: CommunityPostDetail?
    @Published private(set) var comments: [CommunityComment] = []
    @Published private(set) var error: String?

    /// Top-level comment + its replies, server-flattened to depth 1.
    struct Thread {
        let root: CommunityComment
        let replies: [CommunityComment]
    }

    var threads: [Thread] {
        let roots = comments.filter { $0.parentCommentId == nil }
        let repliesByParent = Dictionary(grouping: comments.filter { $0.parentCommentId != nil },
                                         by: { $0.parentCommentId ?? "" })
        return roots.map { root in
            Thread(root: root, replies: repliesByParent[root.id] ?? [])
        }
    }

    init(postId: String) { self.postId = postId }

    func load() async {
        if post == nil { await reload() }
    }

    func reload() async {
        do {
            async let postReq: CommunityPostDetail = APIClient.shared
                .send(.communityPost(postId))
            async let commentsReq: CommunityCommentListResponse = APIClient.shared
                .send(.communityComments(postId: postId))
            let (p, c) = try await (postReq, commentsReq)
            self.post = p
            self.comments = c.comments
            self.error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func togglePostLike() async {
        guard let post else { return }
        do {
            let resp: CommunityLikeResponse = try await APIClient.shared
                .send(post.likedByMe ? .unlikeCommunityPost(post.id)
                                     : .likeCommunityPost(post.id))
            self.post = CommunityPostDetail(
                id: post.id, title: post.title, body: post.body,
                author: post.author,
                createdAt: post.createdAt, updatedAt: post.updatedAt,
                commentCount: post.commentCount,
                likeCount: resp.likeCount,
                likedByMe: resp.liked
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggleCommentLike(_ comment: CommunityComment) async {
        do {
            let resp: CommunityLikeResponse = try await APIClient.shared
                .send(comment.likedByMe ? .unlikeCommunityComment(comment.id)
                                        : .likeCommunityComment(comment.id))
            if let idx = comments.firstIndex(where: { $0.id == comment.id }) {
                comments[idx] = CommunityComment(
                    id: comment.id, postId: comment.postId,
                    parentCommentId: comment.parentCommentId,
                    body: comment.body, deleted: comment.deleted,
                    author: comment.author,
                    createdAt: comment.createdAt, updatedAt: comment.updatedAt,
                    likeCount: resp.likeCount, likedByMe: resp.liked
                )
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteComment(_ comment: CommunityComment) async {
        do {
            try await APIClient.shared.sendNoBody(.deleteCommunityComment(comment.id))
            await reload()
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Returns `true` on success — the caller pops the detail view.
    func deletePost() async -> Bool {
        guard let post else { return false }
        do {
            try await APIClient.shared.sendNoBody(.deleteCommunityPost(post.id))
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
