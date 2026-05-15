import SwiftUI

struct ChildDetailView: View {
    let child: Child
    @State private var samples: [AxialLengthSample] = []
    @State private var summary: ChildSummary?
    @State private var loading = false
    @State private var error: String?
    @State private var lifestyleReminderDue = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if child.source == .web {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "globe")
                            .foregroundStyle(Color.accentColor)
                        Text("children.source.web.help")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(Color.accentColor.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
                if lifestyleReminderDue {
                    LifestyleReminderBanner(childId: child.childId)
                        .padding(.horizontal)
                }
                if let s = summary { SummaryCard(summary: s) }
                AxialLengthChartView(samples: samples)
                    .frame(height: 280)
                    .padding(.horizontal)

                // Parent-entered data — both sections navigate into editors
                VStack(spacing: 12) {
                    NavigationLink {
                        ParentalMyopiaView(childId: child.childId)
                    } label: {
                        navRow(titleKey: "parental.title", icon: "figure.2.arms.open")
                    }
                    NavigationLink {
                        LifestyleActivityView(childId: child.childId)
                    } label: {
                        navRow(titleKey: "lifestyle.title", icon: "sun.max")
                    }
                }
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
            HStack(spacing: 6) {
                Text(child.dateOfBirth)
                Text("·")
                Text(LocalizedStringKey(child.sex.localizationKey))
            }
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func navRow(titleKey: LocalizedStringKey, icon: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(Color.accentColor)
            Text(titleKey).fontWeight(.medium)
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func load() async {
        loading = true; defer { loading = false }
        do {
            async let al: [AxialLengthSample] = APIClient.shared.send(.axialLength(childId: child.childId))
            async let sm: ChildSummary       = APIClient.shared.send(.summary(childId: child.childId))
            async let lr: LifestyleReminder  = APIClient.shared.send(.lifestyleReminder(childId: child.childId))
            self.samples = try await al
            self.summary = try await sm
            self.lifestyleReminderDue = try await lr.dueForUpdate
        } catch { self.error = error.localizedDescription }
    }
}

private struct SummaryCard: View {
    let summary: ChildSummary
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("child.summary.title").font(.headline)
            HStack {
                if let a = summary.latestAxial {
                    VStack(alignment: .leading) {
                        Text("axial.title").font(.caption).foregroundStyle(.secondary)
                        Text("OD \(a.od.map { String(format: "%.2f", $0) } ?? "-") mm")
                        Text("OS \(a.os.map { String(format: "%.2f", $0) } ?? "-") mm")
                    }
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("child.summary.measurementCount").font(.caption).foregroundStyle(.secondary)
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
            Text("child.measurements.title").font(.headline).padding(.horizontal)
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
