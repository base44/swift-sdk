import Foundation

// MARK: - Entities Module

/// Provides dynamic access to all entity types in your Base44 app.
///
/// Access any entity by name using dynamic member lookup:
/// ```swift
/// let products = try await base44.entities.Products.list()
/// let order = try await base44.entities.Orders.get(id: "123")
/// ```
@dynamicMemberLookup
public struct EntitiesModule: Sendable {
    private let http: HTTPClient
    private let appId: String

    init(http: HTTPClient, appId: String) {
        self.http = http
        self.appId = appId
    }

    /// Access an entity handler by name.
    public subscript(dynamicMember entityName: String) -> EntityHandler {
        EntityHandler(http: http, appId: appId, entityName: entityName)
    }
}

// MARK: - Entity Handler

/// Provides CRUD and query operations for a specific entity type.
public struct EntityHandler: Sendable {
    private let http: HTTPClient
    private let appId: String
    private let entityName: String

    private var basePath: String {
        "/apps/\(appId)/entities/\(entityName)"
    }

    init(http: HTTPClient, appId: String, entityName: String) {
        self.http = http
        self.appId = appId
        self.entityName = entityName
    }

    // MARK: - List

    /// Lists entities with optional sorting, pagination, and field selection.
    /// - Parameters:
    ///   - sort: Sort field, prefix with `-` for descending (e.g. `"-created_at"`).
    ///   - limit: Maximum number of results.
    ///   - skip: Number of results to skip (for pagination).
    ///   - fields: Specific fields to return.
    /// - Returns: Array of JSON objects.
    public func list(
        sort: String? = nil,
        limit: Int? = nil,
        skip: Int? = nil,
        fields: [String]? = nil
    ) async throws -> JSONArray {
        let items = queryItems(sort: sort, limit: limit, skip: skip, fields: fields)
        let data = try await http.get(path: basePath, queryItems: items.isEmpty ? nil : items)
        return try decode(JSONArray.self, from: data)
    }

    // MARK: - Filter

    /// Filters entities by a query object.
    /// - Parameters:
    ///   - query: Dictionary of field/value pairs to match.
    ///   - sort: Sort field.
    ///   - limit: Maximum results.
    ///   - skip: Skip count.
    ///   - fields: Fields to return.
    /// - Returns: Array of matching JSON objects.
    public func filter(
        _ query: JSONObject,
        sort: String? = nil,
        limit: Int? = nil,
        skip: Int? = nil,
        fields: [String]? = nil
    ) async throws -> JSONArray {
        let queryJSON = try JSONSerialization.data(withJSONObject: query)
        let queryStr = String(data: queryJSON, encoding: .utf8) ?? "{}"
        var items = queryItems(sort: sort, limit: limit, skip: skip, fields: fields)
        items.append(URLQueryItem(name: "q", value: queryStr))
        let data = try await http.get(path: basePath, queryItems: items)
        return try decode(JSONArray.self, from: data)
    }

    // MARK: - Get

    /// Gets a single entity by ID.
    public func get(id: String) async throws -> JSONObject {
        let data = try await http.get(path: "\(basePath)/\(id)")
        return try decode(JSONObject.self, from: data)
    }

    // MARK: - Create

    /// Creates a new entity.
    public func create(_ body: JSONObject) async throws -> JSONObject {
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let encoded = RawJSONEncodable(data: bodyData)
        let data = try await http.post(path: basePath, body: encoded)
        return try decode(JSONObject.self, from: data)
    }

    // MARK: - Update

    /// Updates an entity by ID.
    public func update(id: String, _ body: JSONObject) async throws -> JSONObject {
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let encoded = RawJSONEncodable(data: bodyData)
        let data = try await http.put(path: "\(basePath)/\(id)", body: encoded)
        return try decode(JSONObject.self, from: data)
    }

    // MARK: - Delete

    /// Deletes an entity by ID.
    public func delete(id: String) async throws -> DeleteResult {
        let data = try await http.delete(path: "\(basePath)/\(id)")
        return try decode(DeleteResult.self, from: data)
    }

    // MARK: - Delete Many

    /// Deletes all entities matching a query.
    public func deleteMany(_ query: JSONObject) async throws -> DeleteManyResult {
        let bodyData = try JSONSerialization.data(withJSONObject: query)
        let encoded = RawJSONEncodable(data: bodyData)
        let data = try await http.delete(path: basePath, body: encoded)
        return try decode(DeleteManyResult.self, from: data)
    }

    // MARK: - Bulk Create

    /// Creates multiple entities in a single request.
    public func bulkCreate(_ bodies: [JSONObject]) async throws -> JSONArray {
        let bodyData = try JSONSerialization.data(withJSONObject: bodies)
        let encoded = RawJSONEncodable(data: bodyData)
        let data = try await http.post(path: "\(basePath)/bulk", body: encoded)
        return try decode(JSONArray.self, from: data)
    }

    // MARK: - Import

    /// Imports entities from CSV/Excel file data.
    public func importEntities(fileData: Data, filename: String, mimeType: String = "text/csv") async throws -> ImportResult {
        let multipart = MultipartBody(fields: [
            "file": .file(fileData, filename: filename, mimeType: mimeType)
        ])
        let data = try await http.post(path: "\(basePath)/import", multipart: multipart)
        return try decode(ImportResult.self, from: data)
    }

    // MARK: - Helpers

    private func queryItems(sort: String?, limit: Int?, skip: Int?, fields: [String]?) -> [URLQueryItem] {
        var items = [URLQueryItem]()
        if let sort = sort { items.append(URLQueryItem(name: "sort", value: sort)) }
        if let limit = limit { items.append(URLQueryItem(name: "limit", value: "\(limit)")) }
        if let skip = skip { items.append(URLQueryItem(name: "skip", value: "\(skip)")) }
        if let fields = fields { items.append(URLQueryItem(name: "fields", value: fields.joined(separator: ","))) }
        return items
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            if let obj = try? JSONSerialization.jsonObject(with: data) as? T { return obj }
            throw error
        }
    }
}

// MARK: - Raw JSON Encodable

/// Wraps pre-encoded JSON data so it can be passed through the Encodable pipeline without double-encoding.
struct RawJSONEncodable: Encodable {
    let data: Data

    func encode(to encoder: Encoder) throws {
        guard let obj = try? JSONSerialization.jsonObject(with: data) else { return }
        if let arr = obj as? [Any] {
            var container = encoder.unkeyedContainer()
            for item in arr {
                let itemData = try JSONSerialization.data(withJSONObject: item)
                let nestedObj = try JSONDecoder().decode(JSONValue.self, from: itemData)
                try container.encode(nestedObj)
            }
        } else if let dict = obj as? [String: Any] {
            var container = encoder.container(keyedBy: DynamicCodingKey.self)
            for (k, v) in dict {
                let vData = try JSONSerialization.data(withJSONObject: v)
                let jv = try JSONDecoder().decode(JSONValue.self, from: vData)
                if let key = DynamicCodingKey(stringValue: k) {
                    try container.encode(jv, forKey: key)
                }
            }
        }
    }
}
