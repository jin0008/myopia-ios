import SwiftUI

/// Top-level feed for 자유게시판. Reverse-chronological list of posts
/// with keyset pagination — we fetch the next page when the last row
/// scrolls into view.
struct CommunityListView: View {
    @StateObject private var model = CommunityListModel()
    @State private var showComposer = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(Text("community.title"))
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showComposer = true
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .accessibilityLabel(Text("community.compose"))
                        }
                    }
                }
                .sheet(isPresented: $showComposer) {
                    CommunityComposerView(mode: .newPost) { _ in
                        Task { await model.reload() }
                    }
                }
                .task { await model.loadIfNeeded() }
                .refreshable { await model.reload() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading where model.posts.isEmpty:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error(let message) where model.posts.isEmpty:
            VStack(spacing: 12) {
                Text("community.loadFail").font(.headline)
                Text(message).font(.footnote).foregroundStyle(.secondary)
                Button {
                    Task { await model.reload() }
                } label: { Text("children.retry") }
            }
            .padding()
        case .empty:
            VStack(spacing: 12) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 42))
                    .foregroundStyle(.tertiary)
                Text("community.empty.title").font(.headline)
                Text("community.empty.body").font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        default:
            List {
                ForEach(model.posts) { post in
                    NavigationLink(value: post.id) {
                        CommunityRow(post: post)
                    }
                    .listRowInsets(.init(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .onAppear {
                        if post.id == model.posts.last?.id {
                            Task { await model.loadNextPage() }
                        }
                    }
                }

                if model.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .navigationDestination(for: String.self) { postId in
                CommunityDetailView(postId: postId, onChange: {
                    Task { await model.reload() }
                })
            }
        }
    }
}

/// Single row in the feed — title, preview, author + meta footer.
private struct CommunityRow: View {
    let post: CommunityPostSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(post.title)
                .font(.headline)
                .lineLimit(2)
            Text(post.bodyPreview)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack(spacing: 10) {
                Label(post.author.username ?? String(localized: "community.anonymous"),
                      systemImage: "person.crop.circle")
                Text(post.createdAt, style: .relative)
                Spacer()
                Label("\(post.commentCount)", systemImage: "bubble.left")
                Label("\(post.likeCount)",
                      systemImage: post.likedByMe ? "heart.fill" : "heart")
                    .foregroundStyle(post.likedByMe ? .pink : .secondary)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

@MainActor
final class CommunityListModel: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case empty
        case error(String)
    }

    @Published private(set) var state: LoadState = .idle
    @Published private(set) var posts: [CommunityPostSummary] = []
    @Published private(set) var isLoadingMore = false

    private var nextCursor: String?
    private var hasFirstLoaded = false

    func loadIfNeeded() async {
        guard hasFirstLoaded == false else { return }
        await reload()
    }

    func reload() async {
        state = .loading
        nextCursor = nil
        do {
            let page: CommunityPostListResponse = try await APIClient.shared
                .send(.communityPosts(cursor: nil))
            posts = page.posts
            nextCursor = page.nextCursor
            state = posts.isEmpty ? .empty : .loaded
            hasFirstLoaded = true
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func loadNextPage() async {
        guard let cursor = nextCursor, isLoadingMore == false else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page: CommunityPostListResponse = try await APIClient.shared
                .send(.communityPosts(cursor: cursor))
            // De-dupe in case the server returns overlap on inserts.
            let existing = Set(posts.map(\.id))
            posts.append(contentsOf: page.posts.filter { !existing.contains($0.id) })
            nextCursor = page.nextCursor
        } catch {
            // Surface the error but keep current rows.
            state = .error(error.localizedDescription)
        }
    }
}
