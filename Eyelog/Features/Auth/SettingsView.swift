import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var session: SessionStore

    var body: some View {
        NavigationStack {
            Form {
                Section("계정") {
                    if case .signedIn(let user) = session.state {
                        LabeledContent("사용자", value: user.username ?? user.email ?? user.id)
                        LabeledContent("역할", value: user.role)
                    }
                }
                Section("법적 고지") {
                    Link("이용약관", destination: URL(string: "https://myopiamanage.org/tos")!)
                    Link("개인정보처리방침", destination: URL(string: "https://myopiamanage.org/privacy")!)
                }
                Section {
                    Button("로그아웃", role: .destructive) {
                        Task { await session.signOut() }
                    }
                }
            }
            .navigationTitle("설정")
        }
    }
}
