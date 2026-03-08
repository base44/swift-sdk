import Foundation

// MARK: - Users Module

/// Lists and manages users in your Base44 app.
public struct UsersModule: Sendable {
    private let http: HTTPClient
    private let appId: String

    init(http: HTTPClient, appId: String) {
        self.http = http
        self.appId = appId
    }

    /// Returns all users in the app.
    public func list(limit: Int? = nil, skip: Int? = nil) async throws -> JSONArray {
        var items = [URLQueryItem]()
        if let limit = limit { items.append(URLQueryItem(name: "limit", value: "\(limit)")) }
        if let skip = skip { items.append(URLQueryItem(name: "skip", value: "\(skip)")) }
        let data = try await http.get(
            path: "/apps/\(appId)/users",
            queryItems: items.isEmpty ? nil : items
        )
        return (try? JSONSerialization.jsonObject(with: data) as? JSONArray) ?? []
    }

    /// Invites a user to the app by email.
    public func inviteUser(email: String, role: String) async throws -> JSONObject {
        let body: JSONObject = ["user_email": email, "role": role]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let data = try await http.post(path: "/apps/\(appId)/users/invite-user", body: RawJSONEncodable(data: bodyData))
        return (try? JSONSerialization.jsonObject(with: data) as? JSONObject) ?? [:]
    }
}
