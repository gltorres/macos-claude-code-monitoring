import Foundation

actor ClaudeUsageClient {
    static let shared = ClaudeUsageClient()
    private var cachedOrgUUID: String?

    enum ClientError: Error, LocalizedError {
        case missingSessionKey
        case unauthorized
        case noOrganization
        case http(status: Int, body: String)
        case decoding(underlying: Error)

        var errorDescription: String? {
            switch self {
            case .missingSessionKey: return "No sessionKey saved."
            case .unauthorized:      return "Session expired — paste a new sessionKey."
            case .noOrganization:    return "No organizations on this account."
            case .http(let s, _):    return "claude.ai returned HTTP \(s)."
            case .decoding(let e):   return "Couldn't parse usage response: \(e)."
            }
        }
    }

    func fetchUsage() async throws -> UsageSnapshot {
        guard let key = KeychainStore.sessionKey() else { throw ClientError.missingSessionKey }
        let orgUUID = try await orgUUID(sessionKey: key)
        let url = URL(string: "https://claude.ai/api/organizations/\(orgUUID)/usage")!
        let data = try await get(url, sessionKey: key)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(UsageSnapshot.self, from: data)
        } catch {
            throw ClientError.decoding(underlying: error)
        }
    }

    private func orgUUID(sessionKey: String) async throws -> String {
        if let cached = cachedOrgUUID { return cached }
        let url = URL(string: "https://claude.ai/api/organizations")!
        let data = try await get(url, sessionKey: sessionKey)
        struct Org: Decodable { let uuid: String }
        let orgs = try JSONDecoder().decode([Org].self, from: data)
        guard let first = orgs.first?.uuid else { throw ClientError.noOrganization }
        cachedOrgUUID = first
        return first
    }

    private func get(_ url: URL, sessionKey: String) async throws -> Data {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        for (k, v) in HTTPHeaders.standard { req.setValue(v, forHTTPHeaderField: k) }
        req.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw ClientError.http(status: -1, body: "") }
        if http.statusCode == 401 || http.statusCode == 403 { throw ClientError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            throw ClientError.http(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }
}
