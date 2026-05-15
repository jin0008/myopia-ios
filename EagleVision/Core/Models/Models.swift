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

/// Where a `Child` originally came from. The backend reports this as a
/// string field in the response and we treat unknown values as `.app`
/// for forward-compatibility.
enum ChildSource: String, Codable {
    /// Created via the iOS "add child" flow → `parent_child_link` row.
    /// The user can edit nickname / DOB / sex and link multiple hospitals.
    case app

    /// Originated from myopiamanage.org's regular-user "register child"
    /// flow → `user_patient` row. Read-only on the iOS side; the user
    /// can delete the link (drops the user_patient row) but cannot
    /// rename or add additional hospitals.
    case web
}

struct Child: Codable, Identifiable {
    let childId: String
    /// Defaults to `.app` if the backend response omits the field
    /// (older backends or migration in progress).
    var source: ChildSource = .app
    var nickname: String
    var dateOfBirth: String   // YYYY-MM-DD from backend
    var sex: Sex
    var linkedHospitals: [LinkedHospital]

    var id: String { childId }

    /// True for children that came from the web side. UI should hide
    /// edit-nickname and add-hospital affordances for these.
    var isReadOnly: Bool { source == .web }

    private enum CodingKeys: String, CodingKey {
        case childId, source, nickname, dateOfBirth, sex, linkedHospitals
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.childId         = try c.decode(String.self, forKey: .childId)
        self.source          = try c.decodeIfPresent(ChildSource.self, forKey: .source) ?? .app
        self.nickname        = try c.decode(String.self, forKey: .nickname)
        self.dateOfBirth     = try c.decode(String.self, forKey: .dateOfBirth)
        self.sex             = try c.decode(Sex.self,    forKey: .sex)
        self.linkedHospitals = try c.decode([LinkedHospital].self, forKey: .linkedHospitals)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(childId, forKey: .childId)
        try c.encode(source, forKey: .source)
        try c.encode(nickname, forKey: .nickname)
        try c.encode(dateOfBirth, forKey: .dateOfBirth)
        try c.encode(sex, forKey: .sex)
        try c.encode(linkedHospitals, forKey: .linkedHospitals)
    }
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

// MARK: - Community board (자유게시판)

struct CommunityAuthor: Codable, Equatable, Hashable {
    let id: String
    let username: String?
    let isMe: Bool
}

/// Used by the list endpoint — `body` is a server-truncated preview.
struct CommunityPostSummary: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let bodyPreview: String
    let author: CommunityAuthor
    let createdAt: Date
    let updatedAt: Date
    let commentCount: Int
    let likeCount: Int
    let likedByMe: Bool
}

struct CommunityPostListResponse: Codable {
    let posts: [CommunityPostSummary]
    let nextCursor: String?
}

/// Full post payload returned by the detail endpoint. Note `body`
/// rather than `bodyPreview` — same fields otherwise.
struct CommunityPostDetail: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let body: String
    let author: CommunityAuthor
    let createdAt: Date
    let updatedAt: Date
    let commentCount: Int
    let likeCount: Int
    let likedByMe: Bool
}

struct CommunityComment: Codable, Identifiable, Equatable {
    let id: String
    let postId: String
    /// Non-nil → this is a reply to that comment. `nil` → top-level
    /// comment. The server flattens reply depth to one level.
    let parentCommentId: String?
    /// `nil` when the comment has been soft-deleted (`deleted == true`).
    /// The UI shows a "(deleted)" placeholder in that case.
    let body: String?
    let deleted: Bool
    let author: CommunityAuthor
    let createdAt: Date
    let updatedAt: Date
    let likeCount: Int
    let likedByMe: Bool
}

struct CommunityCommentListResponse: Codable {
    let comments: [CommunityComment]
}

struct CommunityLikeResponse: Codable {
    let liked: Bool
    let likeCount: Int
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

    // MARK: Community board

    static func communityPosts(cursor: String? = nil, pageSize: Int = 20) -> Endpoint {
        var q: [(String, String)] = [("pageSize", String(pageSize))]
        if let cursor { q.append(("cursor", cursor)) }
        return Endpoint(path: "community/posts", query: q)
    }

    static func createCommunityPost(title: String, body: String) -> Endpoint {
        struct Body: Encodable { let title: String; let body: String }
        return Endpoint(path: "community/posts", method: .POST,
                        body: Body(title: title, body: body))
    }

    static func communityPost(_ id: String) -> Endpoint {
        Endpoint(path: "community/posts/\(id)")
    }

    static func updateCommunityPost(_ id: String, title: String?, body: String?) -> Endpoint {
        struct Body: Encodable {
            let title: String?
            let body: String?
            enum CodingKeys: String, CodingKey { case title, body }
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                if let title { try c.encode(title, forKey: .title) }
                if let body { try c.encode(body, forKey: .body) }
            }
        }
        return Endpoint(path: "community/posts/\(id)", method: .PATCH,
                        body: Body(title: title, body: body))
    }

    static func deleteCommunityPost(_ id: String) -> Endpoint {
        Endpoint(path: "community/posts/\(id)", method: .DELETE)
    }

    static func communityComments(postId: String) -> Endpoint {
        Endpoint(path: "community/posts/\(postId)/comments")
    }

    static func createCommunityComment(postId: String,
                                       body: String,
                                       parentCommentId: String? = nil) -> Endpoint {
        struct Body: Encodable {
            let body: String
            let parentCommentId: String?
            enum CodingKeys: String, CodingKey { case body, parentCommentId }
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(body, forKey: .body)
                if let parentCommentId {
                    try c.encode(parentCommentId, forKey: .parentCommentId)
                }
            }
        }
        return Endpoint(path: "community/posts/\(postId)/comments",
                        method: .POST,
                        body: Body(body: body, parentCommentId: parentCommentId))
    }

    static func deleteCommunityComment(_ id: String) -> Endpoint {
        Endpoint(path: "community/comments/\(id)", method: .DELETE)
    }

    static func likeCommunityPost(_ id: String) -> Endpoint {
        Endpoint(path: "community/posts/\(id)/like", method: .POST)
    }
    static func unlikeCommunityPost(_ id: String) -> Endpoint {
        Endpoint(path: "community/posts/\(id)/like", method: .DELETE)
    }
    static func likeCommunityComment(_ id: String) -> Endpoint {
        Endpoint(path: "community/comments/\(id)/like", method: .POST)
    }
    static func unlikeCommunityComment(_ id: String) -> Endpoint {
        Endpoint(path: "community/comments/\(id)/like", method: .DELETE)
    }
}
