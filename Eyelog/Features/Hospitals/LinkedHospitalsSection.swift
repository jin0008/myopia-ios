import SwiftUI

struct LinkedHospitalsSection: View {
    let child: Child
    @State private var linked: [LinkedHospital]
    @State private var showAdd = false

    init(child: Child) {
        self.child = child
        _linked = State(initialValue: child.linkedHospitals)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("hospital.linked").font(.headline)
                Spacer()
                Button { showAdd = true } label: {
                    Label {
                        Text("common.add")
                    } icon: {
                        Image(systemName: "plus")
                    }
                }
            }
            if linked.isEmpty {
                Text("hospital.empty")
                    .foregroundStyle(.secondary).font(.footnote)
            } else {
                ForEach(linked) { h in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(h.hospitalName).font(.subheadline.bold())
                            Text(String(
                                format: NSLocalizedString("hospital.regNumberLabel", comment: ""),
                                h.registrationNumber
                            ))
                            .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            Task { await unlink(h) }
                        } label: {
                            Image(systemName: "link.badge.minus")
                        }
                    }
                    Divider()
                }
            }
        }
        .padding()
        .sheet(isPresented: $showAdd) {
            AddHospitalLinkView(childId: child.childId) { newLink in
                linked.append(newLink)
            }
        }
    }

    private func unlink(_ h: LinkedHospital) async {
        do {
            try await APIClient.shared.sendNoBody(
                .unlinkHospital(childId: child.childId, hospitalId: h.hospitalId)
            )
            linked.removeAll { $0.hospitalId == h.hospitalId }
        } catch { /* surface error */ }
    }
}

struct AddHospitalLinkView: View {
    @Environment(\.dismiss) private var dismiss
    let childId: String
    let onLinked: (LinkedHospital) -> Void

    @State private var hospitals: [HospitalSummary] = []
    @State private var search = ""
    @State private var selected: HospitalSummary?
    @State private var mrn = ""
    @State private var working = false
    @State private var error: String?

    var filtered: [HospitalSummary] {
        search.isEmpty ? hospitals :
        hospitals.filter { $0.name.localizedCaseInsensitiveContains(search)
                        || $0.code.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("hospital.section.select")) {
                    TextField("hospital.searchPlaceholder", text: $search)
                    if let s = selected {
                        HStack { Text(s.name); Spacer(); Text(s.code).foregroundStyle(.secondary) }
                    } else {
                        ForEach(filtered) { h in
                            Button { selected = h } label: {
                                HStack { Text(h.name); Spacer(); Text(h.code).foregroundStyle(.secondary) }
                            }
                        }
                    }
                }
                Section(header: Text("hospital.regNumberSection")) {
                    TextField("hospital.regNumberPlaceholder", text: $mrn)
                        .keyboardType(.asciiCapable)
                        .textInputAutocapitalization(.never)
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle("hospital.linkAdd")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("common.cancel") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await link() } } label: { Text("hospital.linkSubmit") }
                        .disabled(selected == nil || mrn.isEmpty || working)
                }
            }
            .task {
                do { hospitals = try await APIClient.shared.send(.hospitals) }
                catch { self.error = error.localizedDescription }
            }
        }
    }

    private func link() async {
        guard let s = selected else { return }
        working = true; defer { working = false }
        do {
            let link: LinkedHospital = try await APIClient.shared.send(
                .linkHospital(childId: childId, code: s.code, mrn: mrn)
            )
            onLinked(link)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
