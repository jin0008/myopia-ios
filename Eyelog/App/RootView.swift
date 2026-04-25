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
                .tabItem {
                    Label {
                        Text("tab.children")
                    } icon: {
                        Image(systemName: "figure.2.and.child.holdinghands")
                    }
                }
            SettingsView()
                .tabItem {
                    Label {
                        Text("tab.settings")
                    } icon: {
                        Image(systemName: "gear")
                    }
                }
        }
    }
}
