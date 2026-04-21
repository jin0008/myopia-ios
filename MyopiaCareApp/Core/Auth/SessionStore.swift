import Foundation
import SwiftUI

@MainActor
final class SessionStore: ObservableObject {
    enum State { case loading, signedOut, signedIn(User) }

    @Published private(set) var state: State = .loading

    func restore() async {
        // If we have a refresh token, try to load /auth/me.
        if await TokenStore.shared.accessToken == nil {
            state = .signedOut
            return
        }
        do {
            let me: User = try await APIClient.shared.send(.me)
            state = .signedIn(me)
        } catch {
            state = .signedOut
        }
    }

    func signIn(with response: AuthResponse) async {
        await TokenStore.shared.save(access: response.accessToken, refresh: response.refreshToken)
        state = .signedIn(response.user)
    }

    func signOut() async {
        try? await APIClient.shared.sendNoBody(.logout)
        await TokenStore.shared.clear()
        state = .signedOut
    }
}
