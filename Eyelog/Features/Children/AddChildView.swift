import SwiftUI

struct AddChildView: View {
    @Environment(\.dismiss) private var dismiss
    let onCreated: (Child) -> Void

    @State private var nickname = ""
    @State private var dob: Date = Calendar.current.date(byAdding: .year, value: -7, to: Date())!
    @State private var sex: Sex = .male
    @State private var isWorking = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("children.section.info")) {
                    TextField("child.nicknamePlaceholder", text: $nickname)
                    DatePicker("child.dateOfBirth", selection: $dob, in: ...Date(), displayedComponents: .date)
                    Picker(selection: $sex) {
                        ForEach(Sex.allCases) {
                            Text(LocalizedStringKey($0.localizationKey)).tag($0)
                        }
                    } label: {
                        Text("child.sex")
                    }
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle("children.add")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("common.cancel") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await save() } } label: { Text("common.save") }
                        .disabled(nickname.isEmpty || isWorking)
                }
            }
            .disabled(isWorking)
        }
    }

    private func save() async {
        error = nil; isWorking = true; defer { isWorking = false }
        let fmt = ISO8601DateFormatter(); fmt.formatOptions = [.withFullDate]
        let dobString = fmt.string(from: dob)
        do {
            let created: Child = try await APIClient.shared.send(
                .createChild(nickname: nickname, dob: dobString, sex: sex)
            )
            onCreated(created)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
