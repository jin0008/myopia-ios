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
            Section(header: Text("signup.section.account")) {
                TextField("login.username", text: $username)
                    .textInputAutocapitalization(.never)
                SecureField("login.password", text: $password)
                TextField("signup.email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                Toggle("signup.receiveUpdates", isOn: $receiveUpdates)
            }
            Section {
                Button { Task { await submit() } } label: {
                    Text("signup.button")
                }
                .disabled(isWorking || username.isEmpty || password.isEmpty)
                if let error { Text(error).foregroundStyle(.red) }
            }
        }
        .navigationTitle("signup.title")
    }

    private func submit() async {
        error = nil; isWorking = true; defer { isWorking = false }
        do {
            // Generated SignupRequest carries the correct wire key
            // (receive_email_updates) via its CodingKeys.
            let r: AuthResponse = try await APIClient.shared.send(
                Endpoint(path: "auth/signup", method: .POST,
                         body: SignupRequest(username: username, password: password,
                                             email: email, receiveEmailUpdates: receiveUpdates))
            )
            await session.signIn(with: r)
        } catch { self.error = error.localizedDescription }
    }
}
