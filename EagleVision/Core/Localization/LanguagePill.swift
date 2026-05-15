import SwiftUI

/// Two-state pill that flips between Korean and English. Used on the
/// login screen (top-right) where we don't want a full settings sheet,
/// but the user might still want to switch before signing up.
///
/// On iPad / larger screens this could be replaced by a full segmented
/// control; on iPhone the pill is intentionally compact.
struct LanguagePill: View {
    @EnvironmentObject var localization: LocalizationStore

    var body: some View {
        HStack(spacing: 0) {
            segment("KOR", isOn: localization.selection == .korean) {
                localization.selection = .korean
            }
            Divider().frame(height: 14)
            segment("ENG", isOn: localization.selection == .english) {
                localization.selection = .english
            }
        }
        .font(.caption.weight(.semibold))
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.thinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("settings.language"))
    }

    @ViewBuilder
    private func segment(_ label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
                .background(isOn ? Color.accentColor.opacity(0.12) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}
