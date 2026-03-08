import Foundation

// MARK: - App Logs Module

/// Lists application log entries from your Base44 app.
public struct AppLogsModule: Sendable {
    private let http: HTTPClient
    private let appId: String

    init(http: HTTPClient, appId: String) {
        self.http = http
        self.appId = appId
    }

    /// Returns log entries for the app.
    public func list(limit: Int? = nil, skip: Int? = nil) async throws -> JSONArray {
        var items = [URLQueryItem]()
        if let limit = limit { items.append(URLQueryItem(name: "limit", value: "\(limit)")) }
        if let skip = skip { items.append(URLQueryItem(name: "skip", value: "\(skip)")) }
        let data = try await http.get(
            path: "/apps/\(appId)/app-logs",
            queryItems: items.isEmpty ? nil : items
        )
        return (try? JSONSerialization.jsonObject(with: data) as? JSONArray) ?? []
    }
}
