import SwiftUI

/// Lifestyle screen — parent enters average daily near-work and outdoor
/// activity in hours. UX is "see the previous value, decide whether
/// anything changed, otherwise skip" so we don't accumulate noise rows
/// when nothing has actually moved.
///
/// Backend writes
/// --------------
/// Each save creates one new timeline row in
/// `patient_nearwork_activity` / `patient_outdoor_activity` per linked
/// patient. Tapping "변경 없음 / No change" simply doesn't POST — the
/// previous row stays as the latest value. The 6-month reminder will
/// then surface again 6 months from the *previous* save.
struct LifestyleActivityView: View {

    let childId: String

    @State private var lastNearwork: LifestyleReminder.LatestActivity?
    @State private var lastOutdoor: LifestyleReminder.LatestActivity?
    @State private var nearworkHours: Int = 4
    @State private var outdoorHours: Int = 1
    @State private var loading = true
    @State private var savingKind: ActivityKind?
    @State private var error: String?
    @State private var savedKinds: Set<ActivityKind> = []

    enum ActivityKind: String { case nearwork, outdoor }

    var body: some View {
        Form {
            Section {
                Text("lifestyle.subtitle")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }

            section(
                kind: .nearwork,
                titleKey: "lifestyle.nearwork.title",
                last: lastNearwork,
                hours: $nearworkHours
            )

            section(
                kind: .outdoor,
                titleKey: "lifestyle.outdoor.title",
                last: lastOutdoor,
                hours: $outdoorHours
            )

            if let error {
                Section { Text(error).foregroundStyle(.red).font(.footnote) }
            }
        }
        .navigationTitle("lifestyle.title")
        .task { await load() }
    }

    @ViewBuilder
    private func section(
        kind: ActivityKind,
        titleKey: LocalizedStringKey,
        last: LifestyleReminder.LatestActivity?,
        hours: Binding<Int>
    ) -> some View {
        Section(header: Text(titleKey)) {
            if let last, let lastHours = last.hours {
                LabeledContent {
                    Text("\(lastHours)h · \(formatted(last.recordedAt))")
                        .foregroundStyle(.secondary)
                } label: {
                    Text("lifestyle.lastEntry") // formatted via the value side
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
            } else {
                Text("lifestyle.noEntry").foregroundStyle(.secondary).font(.footnote)
            }

            Stepper(value: hours, in: 0...24) {
                LabeledContent("lifestyle.hoursPerDay", value: "\(hours.wrappedValue)h")
            }

            HStack {
                Button {
                    // "No change" — explicit ack, no network call
                    savedKinds.insert(kind)
                } label: {
                    Text("lifestyle.unchanged").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(savingKind != nil)

                Button {
                    Task { await save(kind: kind, hours: hours.wrappedValue) }
                } label: {
                    if savingKind == kind {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("lifestyle.save").frame(maxWidth: .infinity).fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(savingKind != nil)
            }

            if savedKinds.contains(kind) {
                Label("OK", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.footnote)
            }
        }
    }

    // MARK: - Networking

    private func load() async {
        loading = true; defer { loading = false }
        do {
            let r: LifestyleReminder = try await APIClient.shared.send(.lifestyleReminder(childId: childId))
            lastNearwork = r.nearwork
            lastOutdoor = r.outdoor
            if let h = r.nearwork?.hours { nearworkHours = h }
            if let h = r.outdoor?.hours { outdoorHours = h }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func save(kind: ActivityKind, hours: Int) async {
        savingKind = kind; error = nil; defer { savingKind = nil }
        do {
            let _: APIClient.EmptyResponse = try await APIClient.shared.send(
                kind == .nearwork
                    ? .addNearwork(childId: childId, hours: hours)
                    : .addOutdoor(childId: childId, hours: hours)
            )
            savedKinds.insert(kind)
            // Refresh the "last entry" line so a second save shows the
            // updated value rather than the pre-save value.
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }
}

/// Banner shown at the top of the children list (and child detail) when
/// any of the parent's children have stale lifestyle entries (>6 mo).
/// Implemented as a separate small view so the list can drop it in/out
/// without ceremony.
struct LifestyleReminderBanner: View {
    let childId: String
    var body: some View {
        NavigationLink {
            LifestyleActivityView(childId: childId)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("lifestyle.reminder.title")
                        .font(.subheadline.weight(.semibold))
                    Text("lifestyle.reminder.body")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color.accentColor.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
