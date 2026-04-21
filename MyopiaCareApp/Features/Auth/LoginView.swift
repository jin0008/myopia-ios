import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var session: SessionStore
    @State private var username = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("MyopiaCare")
                    .font(.largeTitle.bold())
                    .padding(.top, 40)
                Text("부모님 · 보호자를 위한 근시 관리 앱")
                    .foregroundStyle(.secondary)

                Spacer(minLength: 12)

                TextField("아이디", text: $username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .padding().background(.thinMaterial).cornerRadius(10)
                SecureField("비밀번호", text: $password)
                    .textContentType(.password)
                    .padding().background(.thinMaterial).cornerRadius(10)

                Button("로그인") { Task { await passwordLogin() } }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(isWorking)

                Divider().padding(.vertical, 8)

                SignInWithAppleButton(.signIn,
                    onRequest: { $0.requestedScopes = [.email, .fullName] },
                    onCompletion: { result in Task { await handleApple(result) } }
                )
                .frame(height: 48)
                .signInWithAppleButtonStyle(.black)

                SocialButton(title: "Google로 계속하기", image: "g.circle.fill") {
                    Task { await handleGoogle() }
                }
                SocialButton(title: "카카오 로그인", image: "bubble.fill", color: .yellow) {
                    Task { await handleKakao() }
                }
                SocialButton(title: "네이버 로그인", image: "n.circle.fill", color: .green) {
                    Task { await handleNaver() }
                }

                NavigationLink("회원가입") { SignupView() }
                    .padding(.top, 8)

                if let error { Text(error).foregroundStyle(.red).font(.footnote) }

                Spacer()
            }
            .padding(.horizontal, 24)
            .disabled(isWorking)
            .overlay { if isWorking { ProgressView() } }
        }
    }

    // MARK: - Handlers

    private func passwordLogin() async {
        error = nil; isWorking = true; defer { isWorking = false }
        struct Body: Encodable { let username: String; let password: String }
        do {
            let r: AuthResponse = try await APIClient.shared.send(
                Endpoint(path: "auth/login", method: .POST, body: Body(username: username, password: password))
            )
            await session.signIn(with: r)
        } catch { self.error = error.localizedDescription }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) async {
        error = nil; isWorking = true; defer { isWorking = false }
        do {
            let auth = try result.get()
            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = cred.identityToken,
                  let token = String(data: tokenData, encoding: .utf8)
            else { throw NSError(domain: "apple", code: -1) }
            let r = try await SocialLogin.exchange(provider: "apple", token: token)
            await session.signIn(with: r)
        } catch { self.error = error.localizedDescription }
    }

    private func handleGoogle() async {
        error = nil; isWorking = true; defer { isWorking = false }
        do {
            let token = try await GoogleLoginProvider.signIn()
            let r = try await SocialLogin.exchange(provider: "google", token: token)
            await session.signIn(with: r)
        } catch { self.error = error.localizedDescription }
    }

    private func handleKakao() async {
        error = nil; isWorking = true; defer { isWorking = false }
        do {
            let token = try await KakaoLoginProvider.signIn()
            let r = try await SocialLogin.exchange(provider: "kakao", token: token)
            await session.signIn(with: r)
        } catch { self.error = error.localizedDescription }
    }

    private func handleNaver() async {
        error = nil; isWorking = true; defer { isWorking = false }
        do {
            let token = try await NaverLoginProvider.signIn()
            let r = try await SocialLogin.exchange(provider: "naver", token: token)
            await session.signIn(with: r)
        } catch { self.error = error.localizedDescription }
    }
}

private struct SocialButton: View {
    let title: String
    let image: String
    var color: Color = .blue
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: image); Text(title).fontWeight(.semibold); Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(color.opacity(0.15))
            .foregroundStyle(.primary)
            .cornerRadius(10)
        }
    }
}

enum SocialLogin {
    static func exchange(provider: String, token: String) async throws -> AuthResponse {
        struct Body: Encodable { let provider: String; let token: String }
        return try await APIClient.shared.send(
            Endpoint(path: "auth/social", method: .POST, body: Body(provider: provider, token: token))
        )
    }
}
