import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var localization: LocalizationStore

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("settings.account")) {
                    if case .signedIn(let user) = session.state {
                        LabeledContent("settings.account", value: user.username ?? user.email ?? user.id)
                    }
                }

                Section(header: Text("settings.language")) {
                    Picker(selection: $localization.selection) {
                        ForEach(LocalizationStore.Selection.allCases) { sel in
                            Text(sel.displayName).tag(sel)
                        }
                    } label: {
                        Text("settings.language")
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section {
                    Link("settings.terms", destination: URL(string: "https://myopiamanage.org/tos")!)
                    Link("settings.privacy", destination: URL(string: "https://myopiamanage.org/privacy")!)
                }

                Section {
                    Button(role: .destructive) {
                        Task { await session.signOut() }
                    } label: {
                        Text("settings.logout")
                    }
                }
            }
            .navigationTitle("settings.title")
        }
    }
}
