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
                        Text("children.loadFail").font(.headline)
                        Text(error).font(.caption).foregroundStyle(.secondary)
                        Button { Task { await load() } } label: {
                            Text("children.retry")
                        }
                    }
                } else if children.isEmpty {
                    ContentUnavailableView {
                        Label {
                            Text("children.empty.title")
                        } icon: {
                            Image(systemName: "figure.2.and.child.holdinghands")
                        }
                    } description: {
                        Text("children.empty.body")
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
            .navigationTitle("children.title")
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
            HStack(spacing: 6) {
                Text(child.dateOfBirth)
                Text("·")
                Text(LocalizedStringKey(child.sex.localizationKey))
                Text("·")
                Text(String(
                    format: NSLocalizedString("children.row.linkedCount", comment: ""),
                    child.linkedHospitals.count
                ))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
