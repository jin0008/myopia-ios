import Foundation

//
// App-side conveniences layered onto the openapi-generated models
// (Core/Generated). Kept here — NOT in the generated files — so that
// re-running `myopia-shared/scripts/generate.sh` never clobbers them.
//
// Adds: SwiftUI `Identifiable` conformances (so models can be used directly
// in `List`/`ForEach`), localization keys for enums, and the `isReadOnly`
// helper the UI relies on.
//

// MARK: - Identifiable conformances

// Types with a computed identity.
extension Child: Identifiable {
    public var id: String { childId }

    /// Web-source children are read-only on iOS: hide edit-nickname and
    /// add-hospital affordances for these.
    var isReadOnly: Bool { source == .web }
}

extension LinkedHospital: Identifiable {
    public var id: String { hospitalId }
}

extension HospitalSummary: Identifiable {
    public var id: String { hospitalId }
}

extension AxialLengthSample: Identifiable {
    // `date` is a YYYY-MM-DD String; combine with hospital for a stable id.
    public var id: String { date + hospitalId }
}

// Types that already carry a stored `id` property — the stored property
// satisfies Identifiable, we just declare the conformance.
extension LifestyleEntry: Identifiable {}
extension TreatmentSample: Identifiable {}
extension CommunityPostSummary: Identifiable {}
extension CommunityPostDetail: Identifiable {}
extension CommunityComment: Identifiable {}

// MARK: - Enum identity + localization

extension Sex: Identifiable {
    public var id: String { rawValue }

    /// Localization key — render with
    /// `Text(LocalizedStringKey(sex.localizationKey))`.
    var localizationKey: String {
        self == .male ? "child.sex.male" : "child.sex.female"
    }
}

extension MyopiaStatus: Identifiable {
    public var id: String { rawValue }

    /// Localization key for the parental-refraction picker labels.
    var localizationKey: String {
        switch self {
        case .myopia:     return "parental.status.myopia"
        case .highMyopia: return "parental.status.highMyopia"
        case .emmetropia: return "parental.status.emmetropia"
        case .hyperopia:  return "parental.status.hyperopia"
        case .unknown:    return "parental.status.unknown"
        }
    }
}
