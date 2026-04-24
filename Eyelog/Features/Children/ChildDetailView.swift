import SwiftUI

struct ChildDetailView: View {
    let child: Child
    @State private var samples: [AxialLengthSample] = []
    @State private var summary: ChildSummary?
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if let s = summary { SummaryCard(summary: s) }
                AxialLengthChartView(samples: samples)
                    .frame(height: 280)
                    .padding(.horizontal)
                LinkedHospitalsSection(child: child)
                MeasurementListSection(samples: samples)
            }
            .padding(.vertical)
        }
        .navigationTitle(child.nickname)
        .task { await load() }
        .overlay { if loading { ProgressView() } }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(child.nickname).font(.title.bold())
            Text("\(child.dateOfBirth) · \(child.sex.display)")
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    private func load() async {
        loading = true; defer { loading = false }
        do {
            async let al: [AxialLengthSample] = APIClient.shared.send(.axialLength(childId: child.childId))
            async let sm: ChildSummary       = APIClient.shared.send(.summary(childId: child.childId))
            self.samples = try await al
            self.summary = try await sm
        } catch { self.error = error.localizedDescription }
    }
}

private struct SummaryCard: View {
    let summary: ChildSummary
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("최근 요약").font(.headline)
            HStack {
                if let a = summary.latestAxial {
                    VStack(alignment: .leading) {
                        Text("Axial Length").font(.caption).foregroundStyle(.secondary)
                        Text("OD \(a.od.map { String(format: "%.2f", $0) } ?? "-") mm")
                        Text("OS \(a.os.map { String(format: "%.2f", $0) } ?? "-") mm")
                    }
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("측정 횟수").font(.caption).foregroundStyle(.secondary)
                    Text("\(summary.measurementCount)").font(.title2.bold())
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

private struct MeasurementListSection: View {
    let samples: [AxialLengthSample]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("측정 기록").font(.headline).padding(.horizontal)
            ForEach(samples) { s in
                HStack {
                    VStack(alignment: .leading) {
                        Text(s.date).font(.subheadline)
                        Text(s.hospitalName).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("OD \(s.od.map { String(format: "%.2f", $0) } ?? "-")").font(.caption)
                        Text("OS \(s.os.map { String(format: "%.2f", $0) } ?? "-")").font(.caption)
                    }
                }
                .padding(.horizontal)
                Divider().padding(.leading)
            }
        }
    }
}
