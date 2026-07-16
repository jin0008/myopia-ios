import Foundation

/// Thin async/await HTTP client with automatic JWT refresh on 401.
actor APIClient {
    static let shared = APIClient()

    /// Backend timestamps come from `Date.toISOString()`, which always emits
    /// fractional seconds (e.g. 2026-04-21T11:00:00.123Z). Some values may
    /// omit them, so we try both.
    nonisolated static let iso8601WithFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    nonisolated static let iso8601Plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(session: URLSession = .shared) {
        self.session = session

        // NOTE: no global snake_case conversion. The generated models
        // (Core/Generated) carry explicit CodingKeys for every field, so the
        // wire keys map exactly — mixing a global strategy with those explicit
        // keys would break snake_case fields (e.g. od_sph) and camelCase
        // request bodies (e.g. hospitalCode). Date-only fields are modeled as
        // String; only true timestamps are Date, decoded below.
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            if let date = APIClient.iso8601WithFraction.date(from: raw)
                ?? APIClient.iso8601Plain.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath,
                      debugDescription: "Unrecognized ISO-8601 date: \(raw)"))
        }
        self.decoder = d

        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        self.encoder = e
    }

    enum APIError: Error, LocalizedError {
        case unauthorized
        case server(Int, String?)
        case network(Error)
        case decoding(Error)

        var errorDescription: String? {
            switch self {
            case .unauthorized:            return "Session expired. Please log in again."
            case .server(let code, let m): return "Server error \(code): \(m ?? "unknown")"
            case .network(let e):          return "Network error: \(e.localizedDescription)"
            case .decoding(let e):         return "Decoding error: \(e.localizedDescription)"
            }
        }
    }

    // MARK: - Public

    func send<T: Decodable>(_ endpoint: Endpoint, as type: T.Type = T.self) async throws -> T {
        var req = try buildRequest(endpoint)
        await attachAuth(&req)

        do {
            let (data, resp) = try await session.data(for: req)
            let http = resp as! HTTPURLResponse

            if http.statusCode == 401 {
                // Try refresh once, then retry
                try await TokenStore.shared.refreshIfPossible()
                var retry = try buildRequest(endpoint)
                await attachAuth(&retry)
                let (data2, resp2) = try await session.data(for: retry)
                let http2 = resp2 as! HTTPURLResponse
                if http2.statusCode == 401 { throw APIError.unauthorized }
                return try decode(data2, status: http2.statusCode)
            }

            return try decode(data, status: http.statusCode)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.network(error)
        }
    }

    func sendNoBody(_ endpoint: Endpoint) async throws {
        struct Empty: Decodable {}
        _ = try await send(endpoint, as: Empty.self)
    }

    // MARK: - Helpers

    private func buildRequest(_ endpoint: Endpoint) throws -> URLRequest {
        var url = APIConfig.baseURL.appendingPathComponent(endpoint.path)
        if let query = endpoint.query, !query.isEmpty {
            var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
            url = comps.url!
        }
        var req = URLRequest(url: url)
        req.httpMethod = endpoint.method.rawValue
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body = endpoint.body {
            req.httpBody = try encoder.encode(AnyEncodable(body))
        }
        return req
    }

    private func attachAuth(_ req: inout URLRequest) async {
        if endpointRequiresAuth(req) == false { return }
        if let token = await TokenStore.shared.accessToken {
            req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func endpointRequiresAuth(_ req: URLRequest) -> Bool {
        let path = req.url?.path ?? ""
        return !(path.hasSuffix("/auth/login")
                 || path.hasSuffix("/auth/signup")
                 || path.hasSuffix("/auth/social")
                 || path.hasSuffix("/auth/refresh")
                 || path.hasSuffix("/hospitals"))
    }

    private func decode<T: Decodable>(_ data: Data, status: Int) throws -> T {
        guard (200..<300).contains(status) else {
            let msg = (try? JSONDecoder().decode(ServerError.self, from: data))?.error
            throw APIError.server(status, msg)
        }
        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }
        do { return try decoder.decode(T.self, from: data) }
        catch { throw APIError.decoding(error) }
    }

    struct EmptyResponse: Decodable {}
    struct ServerError: Decodable { let error: String; let code: String? }
}

// MARK: - Endpoint

struct Endpoint {
    enum Method: String { case GET, POST, PUT, PATCH, DELETE }
    let path: String
    let method: Method
    let query: [(key: String, value: String)]?
    let body: Encodable?

    init(path: String, method: Method = .GET, query: [(String, String)]? = nil, body: Encodable? = nil) {
        self.path = path
        self.method = method
        self.query = query
        self.body = body
    }
}

// Type-erasing wrapper so Endpoint.body can be any Encodable.
struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init(_ wrapped: Encodable) { self._encode = wrapped.encode }
    func encode(to encoder: Encoder) throws { try _encode(encoder) }
}
