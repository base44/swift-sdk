import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - HTTP Client

/// Lightweight URLSession-based HTTP client used internally by all SDK modules.
public final class HTTPClient: @unchecked Sendable {

    let baseURL: String
    private let session: URLSession
    private var defaultHeaders: [String: String]
    private let lock = NSLock()

    /// Creates an HTTP client.
    /// - Parameters:
    ///   - baseURL: Base URL for all requests.
    ///   - headers: Default headers merged into every request.
    ///   - token: Optional bearer token.
    ///   - session: URLSession to use (defaults to `.shared`; inject for testing).
    public init(baseURL: String, headers: [String: String] = [:], token: String? = nil, session: URLSession = .shared) {
        self.baseURL = baseURL
        var h = headers
        h["Content-Type"] = "application/json"
        h["Accept"] = "application/json"
        if let token = token {
            h["Authorization"] = "Bearer \(token)"
        }
        self.defaultHeaders = h
        self.session = session
    }

    // MARK: Token management

    public func setToken(_ token: String) {
        lock.lock()
        defer { lock.unlock() }
        defaultHeaders["Authorization"] = "Bearer \(token)"
    }

    public func clearToken() {
        lock.lock()
        defer { lock.unlock() }
        defaultHeaders.removeValue(forKey: "Authorization")
    }

    var currentToken: String? {
        lock.lock()
        defer { lock.unlock() }
        guard let auth = defaultHeaders["Authorization"],
              auth.hasPrefix("Bearer ") else { return nil }
        return String(auth.dropFirst("Bearer ".count))
    }

    // MARK: Request building

    private func buildRequest(
        method: String,
        path: String,
        queryItems: [URLQueryItem]? = nil,
        body: Data? = nil,
        headers: [String: String] = [:]
    ) throws -> URLRequest {
        guard var components = URLComponents(string: baseURL + path) else {
            throw Base44Error(status: 0, message: "Invalid URL: \(baseURL + path)")
        }
        if let q = queryItems, !q.isEmpty {
            components.queryItems = q
        }
        guard let url = components.url else {
            throw Base44Error(status: 0, message: "Could not build URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method

        lock.lock()
        let snapshot = defaultHeaders
        lock.unlock()

        for (k, v) in snapshot { request.setValue(v, forHTTPHeaderField: k) }
        for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
        request.httpBody = body
        return request
    }

    // MARK: Execution

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw Base44Error(status: 0, message: "Invalid response")
        }
        return (data, httpResponse)
    }

    // MARK: Convenience methods

    func get(path: String, queryItems: [URLQueryItem]? = nil) async throws -> Data {
        let req = try buildRequest(method: "GET", path: path, queryItems: queryItems)
        return try await execute(req)
    }

    func post(path: String, body: Encodable? = nil, multipart: MultipartBody? = nil) async throws -> Data {
        if let multipart = multipart {
            let req = try buildRequest(
                method: "POST", path: path,
                body: multipart.data,
                headers: ["Content-Type": "multipart/form-data; boundary=\(multipart.boundary)"]
            )
            return try await execute(req)
        }
        let bodyData = try body.map { try JSONEncoder().encode(AnyEncodable($0)) }
        let req = try buildRequest(method: "POST", path: path, body: bodyData)
        return try await execute(req)
    }

    func put(path: String, body: Encodable?) async throws -> Data {
        let bodyData = try body.map { try JSONEncoder().encode(AnyEncodable($0)) }
        let req = try buildRequest(method: "PUT", path: path, body: bodyData)
        return try await execute(req)
    }

    func delete(path: String, body: Encodable? = nil) async throws -> Data {
        let bodyData = try body.map { try JSONEncoder().encode(AnyEncodable($0)) }
        let req = try buildRequest(method: "DELETE", path: path, body: bodyData)
        return try await execute(req)
    }

    private func execute(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let message = errorJSON?["message"] as? String
                ?? errorJSON?["detail"] as? String
                ?? HTTPURLResponse.localizedString(forStatusCode: response.statusCode)
            let code = errorJSON?["code"] as? String
            throw Base44Error(status: response.statusCode, code: code, message: message, data: errorJSON)
        }
        return data
    }
}

// MARK: - Multipart helper

public struct MultipartBody {
    public let boundary: String
    public let data: Data

    public init(fields: [String: MultipartField]) {
        let boundary = "Base44Boundary\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        self.boundary = boundary
        var body = Data()
        let boundaryLine = "--\(boundary)\r\n"
        for (name, field) in fields {
            body.append(boundaryLine.data(using: .utf8)!)
            switch field {
            case .text(let value):
                body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(value)\r\n".data(using: .utf8)!)
            case .file(let data, let filename, let mimeType):
                body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
                body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
                body.append(data)
                body.append("\r\n".data(using: .utf8)!)
            }
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        self.data = body
    }
}

public enum MultipartField {
    case text(String)
    case file(Data, filename: String, mimeType: String)
}

// MARK: - AnyEncodable helper

struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init(_ value: Encodable) {
        _encode = value.encode(to:)
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
