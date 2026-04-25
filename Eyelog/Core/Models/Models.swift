import Foundation

// MARK: - Auth

struct User: Codable, Equatable, Identifiable {
    let id: String
    let username: String?
    let email: String?
    let role: String
}

struct AuthResponse: Codable {
    let user: User
    let accessToken: String
    let refreshToken: String
    let accessTokenExpiresIn: Int
}

// MARK: - Children

enum Sex: String, Codable, CaseIterable, Identifiable {
    case male, female
    var id: String { rawValue }
    /// Localization key — use `Text(LocalizedStringKey(sex.localizationKey))`
    /// or `LocalizationStore.shared.string(sex.localizationKey)` to render.
    var localizationKey: String {
        self == .male ? "child.sex.male" : "child.sex.female"
    }
}

struct Child: Codable, Identifiable {
    let childId: String
    var nickname: String
    var dateOfBirth: String   // YYYY-MM-DD from backend
    var sex: Sex
    var linkedHospitals: [LinkedHospital]

    var id: String { childId }
}

struct LinkedHospital: Codable, Identifiable {
    let hospitalId: String
    let hospitalName: String
    let hospitalCode: String
    let registrationNumber: String
    let linkedAt: Date

    var id: String { hospitalId }
}

struct HospitalSummary: Codable, Identifiable {
    let hospitalId: String
    let name: String
    let code: String
    let country: String?

    var id: String { hospitalId }
}

// MARK: - Measurements

struct AxialLengthSample: Codable, Identifiable {
    let date: String       // YYYY-MM-DD
    let od: Double?
    let os: Double?
    let instrumentId: String?
    let hospitalId: String
    let hospitalName: String

    var id: String { date + hospitalId }
}

struct ChildSummary: Codable {
    let latestAxial: LatestAxial?
    let riskStatus: String?
    let measurementCount: Int

    struct LatestAxial: Codable {
        let date: String
        let od: Double?
        let os: Double?
    }
}

// MARK: - Parental refraction

enum MyopiaStatus: String, Codable, CaseIterable, Identifiable {
    case myopia
    case high_myopia
    case emmetropia
    case hyperopia
    case unknown

    var id: String { rawValue }

    /// Localization-key for the picker label.
    var localizationKey: String {
        switch self {
        case .myopia:      return "parental.status.myopia"
        case .high_myopia: return "parental.status.highMyopia"
        case .emmetropia:  return "parental.status.emmetropia"
        case .hyperopia:   return "parental.status.hyperopia"
        case .unknown:     return "parental.status.unknown"
        }
    }
}

struct ParentalMyopiaResponse: Codable {
    let mother: ParentalMyopiaEntry?
    let father: ParentalMyopiaEntry?

    struct ParentalMyopiaEntry: Codable {
        let status: MyopiaStatus
        let recordedAt: Date
    }
}

// MARK: - Lifestyle activity

struct LifestyleEntry: Codable, Identifiable {
    let id: String
    let hours: Int?
    let recordedAt: Date
}

struct LifestyleEntries: Codable {
    let entries: [LifestyleEntry]
}

struct LifestyleReminder: Codable {
    let dueForUpdate: Bool
    let nearwork: LatestActivity?
    let outdoor: LatestActivity?

    struct LatestActivity: Codable {
        let hours: Int?
        let recordedAt: Date
    }
}

// MARK: - Endpoint factories

extension Endpoint {
    static let me = Endpoint(path: "auth/me")
    static let logout = Endpoint(path: "auth/logout", method: .POST)
    static let hospitals = Endpoint(path: "hospitals")
    static let children = Endpoint(path: "children")
    static func child(_ id: String) -> Endpoint { Endpoint(path: "children/\(id)") }
    static func axialLength(childId: String) -> Endpoint {
        Endpoint(path: "children/\(childId)/axial-length")
    }
    static func summary(childId: String) -> Endpoint {
        Endpoint(path: "children/\(childId)/summary")
    }
    static func linkHospital(childId: String, code: String, mrn: String) -> Endpoint {
        struct Body: Encodable { let hospitalCode: String; let registrationNumber: String }
        return Endpoint(
            path: "children/\(childId)/hospital-links",
            method: .POST,
            body: Body(hospitalCode: code, registrationNumber: mrn)
        )
    }
    static func unlinkHospital(childId: String, hospitalId: String) -> Endpoint {
        Endpoint(path: "children/\(childId)/hospital-links/\(hospitalId)", method: .DELETE)
    }
    static func createChild(nickname: String, dob: String, sex: Sex) -> Endpoint {
        struct Body: Encodable { let nickname: String; let dateOfBirth: String; let sex: String }
        return Endpoint(path: "children", method: .POST,
                        body: Body(nickname: nickname, dateOfBirth: dob, sex: sex.rawValue))
    }
    static func deleteChild(_ id: String) -> Endpoint {
        Endpoint(path: "children/\(id)", method: .DELETE)
    }

    // MARK: Parental refraction
    static func parentalMyopia(childId: String) -> Endpoint {
        Endpoint(path: "children/\(childId)/parental-myopia")
    }
    static func updateParentalMyopia(
        childId: String,
        mother: MyopiaStatus?,
        father: MyopiaStatus?,
        clearMother: Bool,
        clearFather: Bool
    ) -> Endpoint {
        // Encode "skip this parent" by *omitting* the key, "clear this
        // parent" by sending `null`, and "set" by sending `{ status }`.
        struct Body: Encodable {
            let mother: Wrapped?
            let father: Wrapped?
            struct Wrapped: Encodable { let status: String }

            enum CodingKeys: String, CodingKey { case mother, father }

            // Custom encoder: include nil only if the caller asked us to
            // explicitly clear; otherwise omit the field.
            let includeMother: Bool
            let includeFather: Bool

            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                if includeMother {
                    if let mother { try c.encode(mother, forKey: .mother) }
                    else { try c.encodeNil(forKey: .mother) }
                }
                if includeFather {
                    if let father { try c.encode(father, forKey: .father) }
                    else { try c.encodeNil(forKey: .father) }
                }
            }
        }
        let body = Body(
            mother: mother.map { .init(status: $0.rawValue) },
            father: father.map { .init(status: $0.rawValue) },
            includeMother: mother != nil || clearMother,
            includeFather: father != nil || clearFather
        )
        return Endpoint(
            path: "children/\(childId)/parental-myopia",
            method: .PUT,
            body: body
        )
    }

    // MARK: Lifestyle
    static func nearworkActivity(childId: String) -> Endpoint {
        Endpoint(path: "children/\(childId)/nearwork-activity")
    }
    static func outdoorActivity(childId: String) -> Endpoint {
        Endpoint(path: "children/\(childId)/outdoor-activity")
    }
    static func addNearwork(childId: String, hours: Int) -> Endpoint {
        struct Body: Encodable { let hours: Int }
        return Endpoint(
            path: "children/\(childId)/nearwork-activity",
            method: .POST,
            body: Body(hours: hours)
        )
    }
    static func addOutdoor(childId: String, hours: Int) -> Endpoint {
        struct Body: Encodable { let hours: Int }
        return Endpoint(
            path: "children/\(childId)/outdoor-activity",
            method: .POST,
            body: Body(hours: hours)
        )
    }
    static func lifestyleReminder(childId: String) -> Endpoint {
        Endpoint(path: "children/\(childId)/lifestyle-reminder")
    }
}
