import SwiftUI

struct RootView: View {
    @EnvironmentObject var session: SessionStore

    var body: some View {
        Group {
            switch session.state {
            case .loading:
                ProgressView()
            case .signedOut:
                LoginView()
            case .signedIn:
                MainTabView()
            }
        }
        .task { await session.restore() }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            ChildrenListView()
                .tabItem { Label("Children", systemImage: "figure.2.and.child.holdinghands") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}
