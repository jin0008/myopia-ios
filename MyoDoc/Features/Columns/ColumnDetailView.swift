import SwiftUI

/// 전문가 칼럼 상세. 목록에서 넘어온 요약으로 즉시 헤더를 그리고, 본문은
/// GET /api/mobile/columns/:id 로 채운다.
struct ColumnDetailView: View {
    let summary: ColumnSummary

    @State private var detail: ColumnDetail?
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                Divider()
                if loading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 24)
                } else if let detail {
                    Text(rendered(detail.body))
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if let error {
                    Text(error).font(.caption).foregroundStyle(.secondary)
                }
                disclaimer
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(summary.category.isEmpty ? "columns.title" : LocalizedStringKey(summary.category))
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(summary.thumbnailEmoji ?? "📖").font(.system(size: 40))
                Spacer()
                if !summary.category.isEmpty {
                    Text(summary.category)
                        .font(.caption.weight(.semibold))
                        .padding(.vertical, 3).padding(.horizontal, 9)
                        .background(Color.blue.opacity(0.12), in: Capsule())
                        .foregroundStyle(.blue)
                }
            }
            Text(summary.title).font(.title2.weight(.bold))
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.fill").foregroundStyle(.secondary)
                Text(summary.author).font(.subheadline.weight(.semibold))
                Text(summary.authorRole)
                    .font(.caption2.weight(.bold))
                    .padding(.vertical, 2).padding(.horizontal, 6)
                    .background(Color.purple.opacity(0.12), in: Capsule())
                    .foregroundStyle(.purple)
                Spacer()
                if !summary.publishedAt.isEmpty {
                    Text(summary.publishedAt.prefix(10)).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var disclaimer: some View {
        Text("columns.disclaimer")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            .padding(.top, 8)
    }

    /// Best-effort markdown → AttributedString. Falls back to plain text.
    private func rendered(_ body: String) -> AttributedString {
        if let attributed = try? AttributedString(
            markdown: body,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return attributed
        }
        return AttributedString(body)
    }

    private func load() async {
        loading = true; defer { loading = false }
        do {
            detail = try await APIClient.shared.send(.column(summary.id))
        } catch { self.error = error.localizedDescription }
    }
}
