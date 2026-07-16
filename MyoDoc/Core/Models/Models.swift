import Foundation

// Endpoint factories. Model types now come from Core/Generated (openapi).

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

    // MARK: - AI 상담 챗봇 / 기관 찾기 / 전문가 칼럼

    /// POST /api/mobile/chat — RAG 챗봇 프록시. 서버가 감수 Q&A를 근거로 답한다.
    static func chat(question: String, history: [ChatTurn]) -> Endpoint {
        Endpoint(path: "chat", method: .POST,
                 body: ChatRequest(question: question, history: history))
    }

    /// GET /api/mobile/hospitals/search — 안과/안경점/라식 기관 검색.
    static func hospitalSearch(type: PlaceType,
                               query: String? = nil,
                               lat: Double? = nil,
                               lng: Double? = nil,
                               limit: Int = 20) -> Endpoint {
        var q: [(String, String)] = [("type", type.rawValue), ("limit", String(limit))]
        if let query, !query.isEmpty { q.append(("q", query)) }
        if let lat { q.append(("lat", String(lat))) }
        if let lng { q.append(("lng", String(lng))) }
        return Endpoint(path: "hospitals/search", query: q)
    }

    /// GET /api/mobile/columns — 전문가 칼럼 목록.
    static func columns(category: String? = nil,
                        cursor: String? = nil,
                        pageSize: Int = 20) -> Endpoint {
        var q: [(String, String)] = [("pageSize", String(pageSize))]
        if let category, !category.isEmpty { q.append(("category", category)) }
        if let cursor { q.append(("cursor", cursor)) }
        return Endpoint(path: "columns", query: q)
    }

    /// GET /api/mobile/columns/:id — 칼럼 상세.
    static func column(_ id: String) -> Endpoint {
        Endpoint(path: "columns/\(id)")
    }
}
