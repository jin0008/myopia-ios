import Foundation
import SwiftUI
import Combine

/// 마이오닥 (MyoDoc) ships in Korean by default but the user can override the
/// language at any time via the toggle on the login screen or the
/// Settings tab. This object is the single source of truth for the
/// in-app language preference.
///
/// Implementation notes
/// --------------------
/// SwiftUI normally picks the localization at app launch from the
/// bundle's preferred languages list. To make a *runtime* switch
/// without restarting we publish two things:
///
///   1. `selection` — the user's choice (`.system`, `.korean`, `.english`).
///      Persisted in `UserDefaults` so the choice survives relaunches.
///   2. `locale` — the resolved `Locale` we feed into `.environment`,
///      which forces every Text/Label inside the view tree to re-pull
///      its localized string from the matching .lproj bundle.
///
/// All Text views in the app must use string-catalog keys (e.g.
/// `Text("login.title")`) so that the `.environment(\.locale, ...)`
/// flip actually changes the rendered copy.
@MainActor
final class LocalizationStore: ObservableObject {

    enum Selection: String, CaseIterable, Identifiable {
        case system
        case korean = "ko"
        case english = "en"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .system:  return NSLocalizedString("language.system", comment: "")
            case .korean:  return "한국어"
            case .english: return "English"
            }
        }
    }

    @Published var selection: Selection {
        didSet {
            UserDefaults.standard.set(selection.rawValue, forKey: Self.storageKey)
            updateLocale()
        }
    }

    @Published private(set) var locale: Locale = .current

    private static let storageKey = "myodoc.language.selection"

    init() {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey) ?? Selection.system.rawValue
        self.selection = Selection(rawValue: raw) ?? .system
        updateLocale()
    }

    /// Convenience for the inline `KOR | ENG` pill on the login screen.
    /// Tapping it cycles between Korean and English without an explicit
    /// "system" stop, which the login screen (pre-auth) doesn't expose.
    func toggleKorEng() {
        switch selection {
        case .english:           selection = .korean
        case .korean, .system:   selection = .english
        }
    }

    private func updateLocale() {
        switch selection {
        case .system:
            // Use whatever the OS picked — `Bundle.main.preferredLocalizations`
            // gives us the bundle's first-supported choice.
            let code = Bundle.main.preferredLocalizations.first ?? "ko"
            locale = Locale(identifier: code)
        case .korean:
            locale = Locale(identifier: "ko")
        case .english:
            locale = Locale(identifier: "en")
        }
    }
}

/// A small helper to look up a key from the *forced* language bundle
/// even outside of SwiftUI (e.g. inside `Alert` strings constructed in
/// non-View code, or NSLocalizedString-style call sites).
extension LocalizationStore {
    func string(_ key: String) -> String {
        let langCode = locale.identifier
        let path = Bundle.main.path(forResource: langCode, ofType: "lproj")
            ?? Bundle.main.path(forResource: "ko", ofType: "lproj")
        if let path, let bundle = Bundle(path: path) {
            return NSLocalizedString(key, bundle: bundle, comment: "")
        }
        return NSLocalizedString(key, comment: "")
    }
}
