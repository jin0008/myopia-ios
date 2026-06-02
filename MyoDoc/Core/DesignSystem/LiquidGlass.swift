import SwiftUI

/// iOS 26 "Liquid Glass" adoption helpers for 마이오닥 / MyoDoc.
///
/// Liquid Glass is applied to the **navigation / control layer only** — bars,
/// the tab bar, buttons, sheets and small custom controls. Content (lists,
/// cards, the axial-length chart) stays opaque and legible.
///
/// Each helper applies the Liquid Glass treatment on iOS 26 and **falls back**
/// to the previous (iOS 17) appearance on earlier systems, so the app keeps
/// running against an older deployment target during rollout.
///
/// > Build requirement: compile with the **Xcode 26 / iOS 26 SDK**. The
/// > `#available` checks gate *runtime* behavior; the new symbols still must
/// > exist at *compile* time.
enum GlassRadius {
    /// Continuous corner radius for content cards (was 12).
    static let card: CGFloat = 20
    /// Continuous corner radius for fields.
    static let field: CGFloat = 14
}

extension View {

    /// Primary brand action. iOS 26: tinted Liquid Glass capsule
    /// (`.glassProminent`). Fallback: `.borderedProminent`.
    @ViewBuilder
    func glassProminentButton() -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }

    /// Secondary / neutral action. iOS 26: clear Liquid Glass capsule
    /// (`.glass`). Fallback: `.bordered`.
    @ViewBuilder
    func glassButton() -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    /// Floating glass surface for a *custom* control (language pill, compose
    /// bar, chip). iOS 26: real `.glassEffect`. Fallback: `.thinMaterial`.
    @ViewBuilder
    func glassControl<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.thinMaterial, in: shape)
        }
    }

    /// Opaque content card with the rounder iOS-26 continuous geometry.
    /// Used for the summary card, chart card and nav rows — NOT glass, because
    /// these sit on an opaque screen and must stay legible.
    func glassCard(cornerRadius: CGFloat = GlassRadius.card) -> some View {
        self.background(
            Color(.secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }

    /// Tab bar shrink-on-scroll. No-op before iOS 26.
    @ViewBuilder
    func glassTabBarMinimize() -> some View {
        if #available(iOS 26.0, *) {
            self.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }
}
