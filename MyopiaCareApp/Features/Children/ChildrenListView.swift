import SwiftUI

struct ChildrenListView: View {
    @State private var children: [Child] = []
    @State private var loading = false
    @State private var error: String?
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if loading && children.isEmpty {
                    ProgressView()
                } else if let error {
                    VStack(spacing: 8) {
                        Text("불러올 수 없습니다").font(.headline)
                        Text(error).font(.caption).foregroundStyle(.secondary)
                        Button("다시 시도") { Task { await load() } }
                    }
                } else if children.isEmpty {
                    ContentUnavailableView {
                        Label("등록된 아이가 없습니다", systemImage: "figure.2.and.child.holdinghands")
                    } description: {
                        Text("+ 버튼을 눌러 아이를 등록하세요.")
                    }
                } else {
                    List(children) { child in
                        NavigationLink(value: child) {
                            ChildRow(child: child)
                        }
                    }
                    .navigationDestination(for: Child.self) { ChildDetailView(child: $0) }
                    .refreshable { await load() }
                }
            }
            .navigationTitle("아이 목록")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddChildView { new in
                    children.append(new)
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        loading = true; defer { loading = false }
        do {
            children = try await APIClient.shared.send(.children)
        } catch { self.error = error.localizedDescription }
    }
}

private struct ChildRow: View {
    let child: Child
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(child.nickname).font(.headline)
            Text("\(child.dateOfBirth) · \(child.sex.display) · 연결된 병원 \(child.linkedHospitals.count)곳")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
