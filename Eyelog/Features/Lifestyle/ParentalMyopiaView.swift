import SwiftUI

/// Parental refraction picker.
///
/// What this writes
/// ----------------
/// One row in `patient_parental_myopia_status` per linked patient per
/// parent (mother / father). The PUT endpoint deletes any prior rows
/// for that parent_sex on each linked patient before inserting the new
/// one, so this screen is effectively "edit the current value" rather
/// than appending history. Doctors on the web see this on their normal
/// patient detail screen.
///
/// "Don't know"
/// ------------
/// We DO write `unknown` to the DB rather than skipping. That makes
/// the difference between "parent answered but doesn't know their
/// refraction" and "parent never opened this screen" explicit on the
/// clinician side. (Storing nothing for a parent who explicitly said
/// "don't know" was the alternative; we picked storing `unknown`.)
struct ParentalMyopiaView: View {

    let childId: String

    @State private var mother: MyopiaStatus = .unknown
    @State private var father: MyopiaStatus = .unknown
    @State private var motherInitial: MyopiaStatus = .unknown
    @State private var fatherInitial: MyopiaStatus = .unknown
    @State private var loading = true
    @State private var saving = false
    @State private var error: String?
    @State private var lastSaveOK = false

    var body: some View {
        Form {
            Section {
                Text("parental.description")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }

            Section(header: Text("parental.mother")) {
                ParentalStatusPicker(value: $mother)
            }

            Section(header: Text("parental.father")) {
                ParentalStatusPicker(value: $father)
            }

            Section {
                Button {
                    Task { await save() }
                } label: {
                    if saving {
                        ProgressView()
                    } else {
                        Text("parental.save")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                    }
                }
                .disabled(saving || (mother == motherInitial && father == fatherInitial))

                if let error {
                    Text(error).foregroundStyle(.red).font(.footnote)
                }
                if lastSaveOK {
                    Label("OK", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("parental.title")
        .task { await load() }
    }

    // MARK: - Networking

    private func load() async {
        loading = true; defer { loading = false }
        do {
            let r: ParentalMyopiaResponse = try await APIClient.shared.send(.parentalMyopia(childId: childId))
            mother = r.mother?.status ?? .unknown
            father = r.father?.status ?? .unknown
            motherInitial = mother
            fatherInitial = father
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func save() async {
        saving = true; lastSaveOK = false; error = nil; defer { saving = false }
        do {
            let _: APIClient.EmptyResponse = try await APIClient.shared.send(
                .updateParentalMyopia(
                    childId: childId,
                    mother: mother == motherInitial ? nil : mother,
                    father: father == fatherInitial ? nil : father,
                    clearMother: false,
                    clearFather: false
                )
            )
            motherInitial = mother
            fatherInitial = father
            lastSaveOK = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct ParentalStatusPicker: View {
    @Binding var value: MyopiaStatus

    var body: some View {
        Picker(selection: $value) {
            ForEach(MyopiaStatus.allCases) { status in
                Text(LocalizedStringKey(status.localizationKey)).tag(status)
            }
        } label: {
            EmptyView()
        }
        .pickerStyle(.inline)
        .labelsHidden()
    }
}
