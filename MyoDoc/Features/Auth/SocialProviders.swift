import Foundation
import UIKit

// These are intentionally thin adapters around the vendor SDKs.
// The main app calls `signIn()` on each provider; every one returns
// the token string we then POST to /auth/social.

// MARK: - Google (using Google Sign-In iOS SDK)

import GoogleSignIn

enum GoogleLoginProvider {
    static func signIn() async throws -> String {
        guard let root = UIApplication.shared.rootViewController else {
            throw NSError(domain: "google", code: 1)
        }
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: root)
        guard let idToken = result.user.idToken?.tokenString else {
            throw NSError(domain: "google", code: 2, userInfo: [NSLocalizedDescriptionKey: "missing id token"])
        }
        return idToken
    }
}

// MARK: - Kakao

import KakaoSDKUser
import KakaoSDKAuth

enum KakaoLoginProvider {
    static func signIn() async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            let completion: (OAuthToken?, Error?) -> Void = { token, error in
                if let error { cont.resume(throwing: error); return }
                guard let accessToken = token?.accessToken else {
                    cont.resume(throwing: NSError(domain: "kakao", code: 1)); return
                }
                cont.resume(returning: accessToken)
            }
            if UserApi.isKakaoTalkLoginAvailable() {
                UserApi.shared.loginWithKakaoTalk(completion: completion)
            } else {
                UserApi.shared.loginWithKakaoAccount(completion: completion)
            }
        }
    }
}

// MARK: - Naver

import NaverThirdPartyLogin

enum NaverLoginProvider {
    static func signIn() async throws -> String {
        // NaverThirdPartyLogin uses a delegate callback; wrap it.
        try await withCheckedThrowingContinuation { cont in
            let delegate = NaverDelegate { result in
                switch result {
                case .success(let token): cont.resume(returning: token)
                case .failure(let err):   cont.resume(throwing: err)
                }
            }
            // Keep delegate alive until callback.
            objc_setAssociatedObject(NaverThirdPartyLoginConnection.getSharedInstance()!,
                                     &naverDelegateKey, delegate, .OBJC_ASSOCIATION_RETAIN)
            NaverThirdPartyLoginConnection.getSharedInstance()?.delegate = delegate
            NaverThirdPartyLoginConnection.getSharedInstance()?.requestThirdPartyLogin()
        }
    }
}

private var naverDelegateKey: UInt8 = 0

private final class NaverDelegate: NSObject, NaverThirdPartyLoginConnectionDelegate {
    let completion: (Result<String, Error>) -> Void
    init(_ completion: @escaping (Result<String, Error>) -> Void) { self.completion = completion }

    func oauth20ConnectionDidFinishRequestACTokenWithAuthCode() {
        let token = NaverThirdPartyLoginConnection.getSharedInstance()?.accessToken ?? ""
        if token.isEmpty { completion(.failure(NSError(domain: "naver", code: 1))) }
        else { completion(.success(token)) }
    }
    func oauth20ConnectionDidFinishRequestACTokenWithRefreshToken() {}
    func oauth20ConnectionDidFinishDeleteToken() {}
    func oauth20Connection(_ oauthConnection: NaverThirdPartyLoginConnection!, didFailWithError error: Error!) {
        completion(.failure(error))
    }
}

// MARK: - Helper

private extension UIApplication {
    var rootViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: \.isKeyWindow)?
            .rootViewController
    }
}
