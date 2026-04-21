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
                Section("아이 정보") {
                    TextField("별명 (Nickname)", text: $nickname)
                    DatePicker("생년월일", selection: $dob, in: ...Date(), displayedComponents: .date)
                    Picker("성별", selection: $sex) {
                        ForEach(Sex.allCases) { Text($0.display).tag($0) }
                    }
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle("아이 등록")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { Task { await save() } }
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
