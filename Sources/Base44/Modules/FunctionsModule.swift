import Foundation

// MARK: - Functions Module

/// Invokes custom backend functions defined in your Base44 app.
///
/// ```swift
/// let result = try await base44.functions.invoke("sendWelcomeEmail", data: ["userId": "abc123"])
/// ```
public struct FunctionsModule: Sendable {
    private let http: HTTPClient
    private let appId: String

    init(http: HTTPClient, appId: String) {
        self.http = http
        self.appId = appId
    }

    /// Invokes a backend function by name.
    /// - Parameters:
    ///   - functionName: The name of the function to invoke.
    ///   - data: JSON body to pass to the function.
    /// - Returns: The function's response as a JSON object.
    public func invoke(_ functionName: String, data: JSONObject = [:]) async throws -> JSONObject {
        let bodyData = try JSONSerialization.data(withJSONObject: data)
        let responseData = try await http.post(
            path: "/apps/\(appId)/functions/\(functionName)",
            body: RawJSONEncodable(data: bodyData)
        )
        return (try? JSONSerialization.jsonObject(with: responseData) as? JSONObject) ?? [:]
    }

    /// Invokes a backend function with file uploads (multipart form data).
    /// - Parameters:
    ///   - functionName: The name of the function to invoke.
    ///   - fields: Text fields.
    ///   - files: File fields.
    /// - Returns: The function's response as a JSON object.
    public func invokeWithFiles(
        _ functionName: String,
        fields: [String: String] = [:],
        files: [String: (data: Data, filename: String, mimeType: String)] = [:]
    ) async throws -> JSONObject {
        var multipartFields: [String: MultipartField] = fields.mapValues { .text($0) }
        for (name, file) in files {
            multipartFields[name] = .file(file.data, filename: file.filename, mimeType: file.mimeType)
        }
        let multipart = MultipartBody(fields: multipartFields)
        let responseData = try await http.post(path: "/apps/\(appId)/functions/\(functionName)", multipart: multipart)
        return (try? JSONSerialization.jsonObject(with: responseData) as? JSONObject) ?? [:]
    }
}
