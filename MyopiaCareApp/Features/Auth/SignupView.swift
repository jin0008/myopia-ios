import SwiftUI

struct SignupView: View {
    @EnvironmentObject var session: SessionStore
    @State private var username = ""
    @State private var password = ""
    @State private var email = ""
    @State private var receiveUpdates = false
    @State private var isWorking = false
    @State private var error: String?

    var body: some View {
        Form {
            Section("계정") {
                TextField("아이디", text: $username)
                    .textInputAutocapitalization(.never)
                SecureField("비밀번호", text: $password)
                TextField("이메일", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                Toggle("이메일 업데이트 수신", isOn: $receiveUpdates)
            }
            Section {
                Button("가입하기") { Task { await submit() } }
                    .disabled(isWorking || username.isEmpty || password.isEmpty)
                if let error { Text(error).foregroundStyle(.red) }
            }
        }
        .navigationTitle("회원가입")
    }

    private func submit() async {
        error = nil; isWorking = true; defer { isWorking = false }
        struct Body: Encodable {
            let username: String; let password: String; let email: String; let receiveEmailUpdates: Bool
        }
        do {
            let r: AuthResponse = try await APIClient.shared.send(
                Endpoint(path: "auth/signup", method: .POST,
                         body: Body(username: username, password: password,
                                    email: email, receiveEmailUpdates: receiveUpdates))
            )
            await session.signIn(with: r)
        } catch { self.error = error.localizedDescription }
    }
}
