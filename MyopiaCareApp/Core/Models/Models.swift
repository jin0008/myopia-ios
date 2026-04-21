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
    var display: String { self == .male ? "남아" : "여아" }
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
}
