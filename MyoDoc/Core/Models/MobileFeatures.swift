import Foundation

//
// Hand-written app models for the mobile-only feature endpoints added on top
// of the clinical read-only API:
//
//   • POST /api/mobile/chat                 — AI 상담 챗봇 (RAG)
//   • GET  /api/mobile/hospitals/search     — 기관 찾기 (안과·안경점·라식)
//   • GET  /api/mobile/columns[/:id]        — 전문가 칼럼
//
// These live OUTSIDE Core/Generated so re-running the openapi generator never
// clobbers them. Field names match the backend JSON exactly (see
// docs/API_SPEC.md). Timestamps that may arrive as date-only strings are kept
// as String and formatted in the UI, to avoid the strict ISO-8601 Date decoder.
//

// MARK: - AI Chat

/// Grounding / safety mode returned per answer. Drives the reference badge and,
/// for `.emergency`, a red "see a doctor now" banner instead of a chat bubble.
enum ChatMode: String, Codable {
    case qa          // 📚 감수 자료 기반
    case general     // 🌐 일반 정보
    case consult     // 🏥 진료 시 상담 권장
    case emergency   // 🚨 즉시 진료 안내
    case limited     // 사용량 한도 안내
    case error

    /// Unknown/other values decode to `.general` rather than throwing.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ChatMode(rawValue: raw) ?? .general
    }

    var badgeText: String {
        switch self {
        case .qa:        return "📚 감수 자료 기반"
        case .general:   return "🌐 일반 정보"
        case .consult:   return "🏥 진료 시 상담 권장"
        case .emergency: return "🚨 즉시 진료 안내"
        case .limited:   return "안내"
        case .error:     return "오류"
        }
    }
}

/// A single turn sent back to the server for context (role is "user"|"model").
struct ChatTurn: Codable, Hashable {
    let role: String
    let text: String
}

/// Request body for POST /api/mobile/chat.
struct ChatRequest: Encodable {
    let question: String
    let history: [ChatTurn]
}

/// A web source attached to a grounded (general) answer.
struct ChatSource: Codable, Hashable, Identifiable {
    let title: String
    let url: String
    var id: String { url }
}

/// Server response for POST /api/mobile/chat.
struct ChatResponse: Decodable {
    let mode: ChatMode
    let answer: String
    let refs: [String]
    let suggestions: [String]
    let sources: [ChatSource]

    enum CodingKeys: String, CodingKey { case mode, answer, refs, suggestions, sources }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mode        = try c.decodeIfPresent(ChatMode.self, forKey: .mode) ?? .general
        answer      = try c.decodeIfPresent(String.self, forKey: .answer) ?? ""
        refs        = try c.decodeIfPresent([String].self, forKey: .refs) ?? []
        suggestions = try c.decodeIfPresent([String].self, forKey: .suggestions) ?? []
        sources     = try c.decodeIfPresent([ChatSource].self, forKey: .sources) ?? []
    }
}

/// UI-side message model (not wire). Author side + optional grounding metadata.
struct ChatMessage: Identifiable, Hashable {
    enum Author { case user, assistant }
    let id = UUID()
    let author: Author
    var text: String
    var mode: ChatMode? = nil
    var suggestions: [String] = []
    var sources: [ChatSource] = []
    var isPending: Bool = false
}

// MARK: - 기관 찾기 (Hospital / Optical / LASIK finder)

enum PlaceType: String, Codable, CaseIterable, Identifiable {
    case clinic   // 안과
    case optical  // 안경점
    case lasik    // 라식·라섹

    public var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .clinic:  return "finder.type.clinic"
        case .optical: return "finder.type.optical"
        case .lasik:   return "finder.type.lasik"
        }
    }

    var symbol: String {
        switch self {
        case .clinic:  return "cross.case"
        case .optical: return "eyeglasses"
        case .lasik:   return "eye"
        }
    }
}

/// One place returned by GET /api/mobile/hospitals/search.
struct HospitalPlace: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let type: PlaceType
    let address: String?
    let lat: Double?
    let lng: Double?
    let distanceKm: Double?
    let phone: String?
    let rating: Double?
    let isPartner: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, type, address, lat, lng, distanceKm, phone, rating, isPartner
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id         = try c.decode(String.self, forKey: .id)
        name       = try c.decode(String.self, forKey: .name)
        type       = (try? c.decode(PlaceType.self, forKey: .type)) ?? .clinic
        address    = try c.decodeIfPresent(String.self, forKey: .address)
        lat        = try c.decodeIfPresent(Double.self, forKey: .lat)
        lng        = try c.decodeIfPresent(Double.self, forKey: .lng)
        distanceKm = try c.decodeIfPresent(Double.self, forKey: .distanceKm)
        phone      = try c.decodeIfPresent(String.self, forKey: .phone)
        rating     = try c.decodeIfPresent(Double.self, forKey: .rating)
        isPartner  = try c.decodeIfPresent(Bool.self, forKey: .isPartner) ?? false
    }
}

struct HospitalSearchResponse: Decodable {
    let places: [HospitalPlace]
}

// MARK: - 전문가 칼럼 (Expert columns)

struct ColumnSummary: Decodable, Identifiable, Hashable {
    let id: String
    let title: String
    let excerpt: String
    let category: String
    let author: String
    let authorRole: String
    let thumbnailEmoji: String?
    let likeCount: Int
    let commentCount: Int
    let publishedAt: String

    enum CodingKeys: String, CodingKey {
        case id, title, excerpt, category, author, authorRole
        case thumbnailEmoji, likeCount, commentCount, publishedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id             = try c.decode(String.self, forKey: .id)
        title          = try c.decode(String.self, forKey: .title)
        excerpt        = try c.decodeIfPresent(String.self, forKey: .excerpt) ?? ""
        category       = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        author         = try c.decodeIfPresent(String.self, forKey: .author) ?? ""
        authorRole     = try c.decodeIfPresent(String.self, forKey: .authorRole) ?? ""
        thumbnailEmoji = try c.decodeIfPresent(String.self, forKey: .thumbnailEmoji)
        likeCount      = try c.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
        commentCount   = try c.decodeIfPresent(Int.self, forKey: .commentCount) ?? 0
        publishedAt    = try c.decodeIfPresent(String.self, forKey: .publishedAt) ?? ""
    }
}

struct ColumnListResponse: Decodable {
    let items: [ColumnSummary]
    let nextCursor: String?
}

struct ColumnDetail: Decodable, Identifiable {
    let id: String
    let title: String
    let body: String
    let category: String
    let author: String
    let authorRole: String
    let likeCount: Int
    let commentCount: Int
    let publishedAt: String

    enum CodingKeys: String, CodingKey {
        case id, title, body, category, author, authorRole
        case likeCount, commentCount, publishedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decode(String.self, forKey: .id)
        title        = try c.decode(String.self, forKey: .title)
        body         = try c.decodeIfPresent(String.self, forKey: .body) ?? ""
        category     = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        author       = try c.decodeIfPresent(String.self, forKey: .author) ?? ""
        authorRole   = try c.decodeIfPresent(String.self, forKey: .authorRole) ?? ""
        likeCount    = try c.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
        commentCount = try c.decodeIfPresent(Int.self, forKey: .commentCount) ?? 0
        publishedAt  = try c.decodeIfPresent(String.self, forKey: .publishedAt) ?? ""
    }
}
