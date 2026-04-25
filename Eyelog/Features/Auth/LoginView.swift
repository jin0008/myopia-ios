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
                HStack {
                    Spacer()
                    LanguagePill()
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                Image("BrandLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 64)
                    .padding(.top, 8)
                Text("brand.full")
                    .font(.title2.bold())
                Text("login.tagline")
                    .foregroundStyle(.secondary)

                Spacer(minLength: 12)

                VStack(spacing: 16) {
                    TextField("login.username", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .padding().background(.thinMaterial).cornerRadius(10)
                    SecureField("login.password", text: $password)
                        .textContentType(.password)
                        .padding().background(.thinMaterial).cornerRadius(10)

                    Button { Task { await passwordLogin() } } label: {
                        Text("login.button").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isWorking)

                    Divider().padding(.vertical, 8)

                    SignInWithAppleButton(.signIn,
                        onRequest: { $0.requestedScopes = [.email, .fullName] },
                        onCompletion: { result in Task { await handleApple(result) } }
                    )
                    .frame(height: 48)
                    .signInWithAppleButtonStyle(.black)

                    SocialButton(titleKey: "login.google", image: "g.circle.fill") {
                        Task { await handleGoogle() }
                    }
                    SocialButton(titleKey: "login.kakao", image: "bubble.fill", color: .yellow) {
                        Task { await handleKakao() }
                    }
                    SocialButton(titleKey: "login.naver", image: "n.circle.fill", color: .green) {
                        Task { await handleNaver() }
                    }

                    NavigationLink {
                        SignupView()
                    } label: {
                        Text("login.signup")
                    }
                    .padding(.top, 8)

                    if let error { Text(error).foregroundStyle(.red).font(.footnote) }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
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
    let titleKey: LocalizedStringKey
    let image: String
    var color: Color = .blue
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: image)
                Text(titleKey).fontWeight(.semibold)
                Spacer()
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
