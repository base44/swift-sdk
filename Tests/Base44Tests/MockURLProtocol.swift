import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest

/// A URLProtocol subclass that intercepts requests and returns mock responses.
/// Use this in tests to avoid live network calls.
///
/// Usage:
/// ```swift
/// let config = URLSessionConfiguration.ephemeral
/// config.protocolClasses = [MockURLProtocol.self]
/// let session = URLSession(configuration: config)
/// MockURLProtocol.mockJSON(path: "/apps/test/entities/Products", body: [["id": "1", "name": "Widget"]])
/// // ... make requests using a client built with this session
/// MockURLProtocol.reset()
/// ```
final class MockURLProtocol: URLProtocol {
    typealias Handler = (URLRequest) throws -> (Data, HTTPURLResponse)

    static var handlers: [String: Handler] = [:]
    static var requestLog: [URLRequest] = []
    private static let lock = NSLock()

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        handlers.removeAll()
        requestLog.removeAll()
    }

    /// Register a handler for a specific URL path.
    static func register(path: String, handler: @escaping Handler) {
        lock.lock()
        defer { lock.unlock() }
        handlers[path] = handler
    }

    /// Convenience: register a JSON-encodable response for a path.
    static func mockJSON<T: Encodable>(path: String, statusCode: Int = 200, body: T) {
        let data = try! JSONEncoder().encode(body)
        lock.lock()
        defer { lock.unlock() }
        handlers[path] = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (data, response)
        }
    }

    /// Convenience: register a raw data response for a path.
    static func mockRaw(path: String, statusCode: Int = 200, data: Data, contentType: String = "application/json") {
        lock.lock()
        defer { lock.unlock() }
        handlers[path] = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": contentType]
            )!
            return (data, response)
        }
    }

    /// Convenience: register a JSON dictionary response for a path.
    static func mockJSONObject(path: String, statusCode: Int = 200, object: [String: Any]) {
        let data = try! JSONSerialization.data(withJSONObject: object)
        lock.lock()
        defer { lock.unlock() }
        handlers[path] = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (data, response)
        }
    }

    /// Convenience: register a JSON array response for a path.
    static func mockJSONArray(path: String, statusCode: Int = 200, array: [[String: Any]]) {
        let data = try! JSONSerialization.data(withJSONObject: array)
        lock.lock()
        defer { lock.unlock() }
        handlers[path] = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (data, response)
        }
    }

    /// Returns the most recent logged request.
    static var lastRequest: URLRequest? {
        lock.lock()
        defer { lock.unlock() }
        return requestLog.last
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        MockURLProtocol.lock.lock()
        MockURLProtocol.requestLog.append(request)
        let path = request.url?.path ?? ""
        // Try exact match first, then prefix match
        let handler = MockURLProtocol.handlers[path]
            ?? MockURLProtocol.handlers.first(where: { path.hasPrefix($0.key) })?.value
        MockURLProtocol.lock.unlock()

        guard let handler = handler else {
            let error = URLError(.unsupportedURL)
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        do {
            let (data, response) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Test helpers

extension XCTestCase {
    /// Creates a URLSession backed by MockURLProtocol.
    func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}
