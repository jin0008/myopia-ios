import SwiftUI

/// 포털 홈 대시보드. 웹 프로토타입의 첫 화면을 앱에 맞게 옮긴 것.
/// - 내 아이 모니터링(안축장 요약) 카드가 최상단 — 앱의 핵심.
/// - 서비스 그리드 / 추천 칼럼 / 커뮤니티 인기글.
/// 기존 엔드포인트를 조합해 구성한다(별도 /home 엔드포인트 불필요).
struct HomeDashboardView: View {
    /// 서비스 그리드에서 다른 탭으로 전환하기 위한 콜백.
    var selectTab: (MainTab) -> Void

    @State private var children: [Child] = []
    @State private var summaries: [String: ChildSummary] = [:]
    @State private var featured: [ColumnSummary] = []
    @State private var popular: [CommunityPostSummary] = []
    @State private var loading = false

    @State private var showFinder = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    childrenSection
                    serviceGrid
                    featuredColumns
                    popularPosts
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 96)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("home.title")
            .navigationDestination(for: Child.self) { ChildDetailView(child: $0) }
            .navigationDestination(for: ColumnSummary.self) { ColumnDetailView(summary: $0) }
            .refreshable { await loadAll() }
            .task { if children.isEmpty && featured.isEmpty { await loadAll() } }
            .sheet(isPresented: $showFinder) { HospitalFinderView() }
        }
    }

    // MARK: 내 아이 모니터링

    private var childrenSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("home.section.children", systemImage: "heart.text.square") {
                selectTab(.children)
            }
            if children.isEmpty {
                emptyChildrenCard
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(children) { child in
                            NavigationLink(value: child) {
                                ChildMonitorCard(child: child, summary: summaries[child.childId])
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2).padding(.bottom, 4)
                }
            }
        }
    }

    private var emptyChildrenCard: some View {
        Button { selectTab(.children) } label: {
            HStack(spacing: 12) {
                Image(systemName: "figure.2.and.child.holdinghands")
                    .font(.title2).foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("home.children.empty.title").font(.subheadline.weight(.semibold))
                    Text("home.children.empty.body").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator).opacity(0.3)))
        }
        .buttonStyle(.plain)
    }

    // MARK: 서비스 그리드

    private var serviceGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
            ServiceTile(title: "home.svc.columns", emoji: "📖", tint: .purple) { selectTab(.columns) }
            ServiceTile(title: "home.svc.finder", emoji: "🏥", tint: .green) { showFinder = true }
            ServiceTile(title: "home.svc.community", emoji: "💬", tint: .blue) { selectTab(.community) }
        }
    }

    // MARK: 추천 칼럼

    @ViewBuilder private var featuredColumns: some View {
        if !featured.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("home.section.columns", systemImage: "book") { selectTab(.columns) }
                VStack(spacing: 12) {
                    ForEach(featured.prefix(3)) { item in
                        NavigationLink(value: item) { ColumnCard(item: item) }
                            .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: 커뮤니티 인기글

    @ViewBuilder private var popularPosts: some View {
        if !popular.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("home.section.popular", systemImage: "person.3") { selectTab(.community) }
                VStack(spacing: 0) {
                    ForEach(Array(popular.prefix(4).enumerated()), id: \.element.id) { idx, post in
                        Button { selectTab(.community) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(post.title).font(.subheadline.weight(.semibold))
                                    .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                                Text(post.bodyPreview).font(.caption).foregroundStyle(.secondary)
                                    .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                                HStack(spacing: 12) {
                                    Label("\(post.likeCount)", systemImage: "heart").font(.caption2)
                                    Label("\(post.commentCount)", systemImage: "bubble.right").font(.caption2)
                                }
                                .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        if idx < min(popular.count, 4) - 1 { Divider() }
                    }
                }
                .padding(.horizontal, 14)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator).opacity(0.3)))
            }
        }
    }

    private func sectionHeader(_ key: LocalizedStringKey, systemImage: String,
                               more: @escaping () -> Void) -> some View {
        HStack {
            Label(key, systemImage: systemImage).font(.headline)
            Spacer()
            Button("home.more", action: more).font(.subheadline).foregroundStyle(Color.accentColor)
        }
    }

    // MARK: Loading

    private func loadAll() async {
        loading = true; defer { loading = false }
        async let childrenTask: [Child]? = try? await APIClient.shared.send(.children)
        async let columnsTask: ColumnListResponse? = try? await APIClient.shared.send(.columns(pageSize: 5))
        async let postsTask: CommunityPostListResponse? = try? await APIClient.shared.send(.communityPosts(pageSize: 5))

        let loadedChildren = await childrenTask ?? []
        children = loadedChildren
        featured = (await columnsTask)?.items ?? []
        popular = (await postsTask)?.posts ?? []

        // Per-child axial summary, concurrently.
        await withTaskGroup(of: (String, ChildSummary?).self) { group in
            for child in loadedChildren {
                group.addTask {
                    let s: ChildSummary? = try? await APIClient.shared.send(.summary(childId: child.childId))
                    return (child.childId, s)
                }
            }
            for await (id, s) in group {
                if let s { summaries[id] = s }
            }
        }
    }
}

// MARK: - Child monitor card

private struct ChildMonitorCard: View {
    let child: Child
    let summary: ChildSummary?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(String(child.nickname.prefix(1)))
                    .font(.subheadline.weight(.bold)).foregroundStyle(Color.accentColor)
                    .frame(width: 38, height: 38)
                    .background(Color.accentColor.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text(child.nickname).font(.subheadline.weight(.bold))
                    Text(child.dateOfBirth).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                if child.source == .web {
                    Text("children.source.web")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.green.opacity(0.15), in: Capsule())
                        .foregroundStyle(.green)
                }
            }

            HStack(spacing: 8) {
                metric("OD", summary?.latestAxial?.od)
                metric("OS", summary?.latestAxial?.os)
                riskMetric
            }
        }
        .padding(16)
        .frame(width: 260)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator).opacity(0.3)))
    }

    private func metric(_ label: String, _ value: Double?) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value.map { String(format: "%.2f", $0) } ?? "—")
                .font(.subheadline.weight(.bold))
            Text("mm").font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private var riskMetric: some View {
        VStack(spacing: 2) {
            Text("home.card.risk").font(.caption2).foregroundStyle(.secondary)
            Text(LocalizedStringKey(riskKey))
                .font(.caption.weight(.bold)).foregroundStyle(riskColor)
            Text(" ").font(.system(size: 9))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(riskColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private var riskKey: String {
        switch summary?.riskStatus {
        case .low:        return "risk.low"
        case .monitoring: return "risk.monitoring"
        case .moderate:   return "risk.moderate"
        case .high:       return "risk.high"
        case .none:       return "risk.unknown"
        }
    }

    private var riskColor: Color {
        switch summary?.riskStatus {
        case .low:        return .green
        case .monitoring: return .blue
        case .moderate:   return .orange
        case .high:       return .red
        case .none:       return .secondary
        }
    }
}

// MARK: - Service tile

private struct ServiceTile: View {
    let title: LocalizedStringKey
    let emoji: String
    let tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(emoji).font(.system(size: 26))
                    .frame(width: 52, height: 52)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                Text(title).font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center).foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator).opacity(0.3)))
        }
        .buttonStyle(.plain)
    }
}
