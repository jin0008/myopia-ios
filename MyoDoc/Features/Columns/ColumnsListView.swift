import SwiftUI

/// 전문가 칼럼 목록. GET /api/mobile/columns 연동. 카테고리 필터 + 커서 페이지네이션.
struct ColumnsListView: View {
    @State private var items: [ColumnSummary] = []
    @State private var nextCursor: String?
    @State private var category: String? = nil
    @State private var loading = false
    @State private var error: String?

    /// Category chips seen in the web portal. `nil` = 전체.
    private let categories: [String?] = [nil, "아트로핀", "드림렌즈", "생활습관", "기초", "정기검진"]

    var body: some View {
        NavigationStack {
            Group {
                if loading && items.isEmpty {
                    ProgressView()
                } else if let error, items.isEmpty {
                    VStack(spacing: 8) {
                        Text("columns.loadFail").font(.headline)
                        Text(error).font(.caption).foregroundStyle(.secondary)
                        Button("children.retry") { Task { await reload() } }
                    }
                } else {
                    list
                }
            }
            .navigationTitle("columns.title")
            .navigationDestination(for: ColumnSummary.self) { ColumnDetailView(summary: $0) }
            .task { if items.isEmpty { await reload() } }
        }
    }

    private var list: some View {
        ScrollView {
            categoryChips
            LazyVStack(spacing: 12) {
                ForEach(items) { item in
                    NavigationLink(value: item) { ColumnCard(item: item) }
                        .buttonStyle(.plain)
                        .onAppear {
                            if item.id == items.last?.id { Task { await loadMore() } }
                        }
                }
                if loading && !items.isEmpty {
                    ProgressView().padding()
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 90)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable { await reload() }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { cat in
                    let selected = cat == category
                    Button {
                        category = cat
                        Task { await reload() }
                    } label: {
                        Text(cat ?? String(localized: "columns.category.all"))
                            .font(.subheadline.weight(selected ? .semibold : .regular))
                            .padding(.vertical, 7).padding(.horizontal, 14)
                            .background(selected ? Color.accentColor : Color(.secondarySystemBackground),
                                        in: Capsule())
                            .foregroundStyle(selected ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
    }

    private func reload() async {
        loading = true; defer { loading = false }
        error = nil
        do {
            let resp: ColumnListResponse = try await APIClient.shared.send(.columns(category: category))
            items = resp.items
            nextCursor = resp.nextCursor
        } catch { self.error = error.localizedDescription }
    }

    private func loadMore() async {
        guard let cursor = nextCursor, !loading else { return }
        loading = true; defer { loading = false }
        do {
            let resp: ColumnListResponse = try await APIClient.shared.send(
                .columns(category: category, cursor: cursor))
            items.append(contentsOf: resp.items)
            nextCursor = resp.nextCursor
        } catch { /* keep existing items */ }
    }
}

struct ColumnCard: View {
    let item: ColumnSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(item.thumbnailEmoji ?? "📖").font(.system(size: 34))
                    .frame(width: 64, height: 64)
                    .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 5) {
                    if !item.category.isEmpty {
                        Text(item.category)
                            .font(.caption2.weight(.semibold))
                            .padding(.vertical, 2).padding(.horizontal, 7)
                            .background(Color.blue.opacity(0.12), in: Capsule())
                            .foregroundStyle(.blue)
                    }
                    Text(item.title).font(.subheadline.weight(.bold))
                        .lineLimit(2).multilineTextAlignment(.leading)
                    Text(item.excerpt).font(.caption).foregroundStyle(.secondary)
                        .lineLimit(2).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            Divider().padding(.leading, 12)
            HStack(spacing: 12) {
                Label("\(item.author) · \(item.authorRole)", systemImage: "stethoscope")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                Label("\(item.likeCount)", systemImage: "heart").font(.caption2).foregroundStyle(.secondary)
                Label("\(item.commentCount)", systemImage: "bubble.right").font(.caption2).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
        }
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator).opacity(0.3)))
    }
}

#Preview {
    ColumnsListView()
}
