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

/// App-level tabs. `children` stays the clinical core (axial-length viewer);
/// `home` is the portal landing dashboard added alongside it.
enum MainTab: Hashable {
    case home, children, columns, community, settings
}

struct MainTabView: View {
    @State private var selection: MainTab = .home

    var body: some View {
        TabView(selection: $selection) {
            HomeDashboardView(selectTab: { selection = $0 })
                .tabItem {
                    Label { Text("tab.home") } icon: { Image(systemName: "house") }
                }
                .tag(MainTab.home)

            ChildrenListView()
                .tabItem {
                    Label {
                        Text("tab.children")
                    } icon: {
                        Image(systemName: "figure.2.and.child.holdinghands")
                    }
                }
                .tag(MainTab.children)

            ColumnsListView()
                .tabItem {
                    Label { Text("tab.columns") } icon: { Image(systemName: "book") }
                }
                .tag(MainTab.columns)

            CommunityListView()
                .tabItem {
                    Label {
                        Text("tab.community")
                    } icon: {
                        Image(systemName: "bubble.left.and.bubble.right")
                    }
                }
                .tag(MainTab.community)

            SettingsView()
                .tabItem {
                    Label {
                        Text("tab.settings")
                    } icon: {
                        Image(systemName: "gear")
                    }
                }
                .tag(MainTab.settings)
        }
        // Floating AI 상담 launcher over every tab.
        .chatLauncher()
        // Liquid Glass (iOS 26): the system renders the floating glass tab bar
        // automatically; this opts into the shrink-on-scroll behavior.
        .glassTabBarMinimize()
    }
}
