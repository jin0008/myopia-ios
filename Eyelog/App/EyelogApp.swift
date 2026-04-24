import SwiftUI
import GoogleSignIn
import KakaoSDKCommon
import KakaoSDKAuth
import NaverThirdPartyLogin

@main
struct EyelogApp: App {

    @StateObject private var session = SessionStore()

    init() {
        // Kakao SDK
        if let key = Bundle.main.object(forInfoDictionaryKey: "KAKAO_APP_KEY") as? String {
            KakaoSDK.initSDK(appKey: key)
        }
        // Naver SDK (configured in AppDelegate-style if needed)
        NaverThirdPartyLoginConnection
            .getSharedInstance()?
            .isNaverAppOauthEnable = true
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .onOpenURL { url in
                    // Route incoming OAuth callbacks to the right SDK
                    if GIDSignIn.sharedInstance.handle(url) { return }
                    if AuthApi.isKakaoTalkLoginUrl(url) {
                        _ = AuthController.handleOpenUrl(url: url)
                        return
                    }
                    NaverThirdPartyLoginConnection
                        .getSharedInstance()?
                        .application(UIApplication.shared, open: url, options: [:])
                }
        }
    }
}
