import Foundation

// MARK: - Integrations Module

/// Provides access to Base44 built-in integrations (AI, storage, email, etc.).
///
/// Integrations are accessed via the package name and endpoint name:
/// ```swift
/// // Invoke LLM
/// let result = try await base44.integrations.core.invokeLLM(prompt: "Hello!")
///
/// // Upload a file
/// let uploaded = try await base44.integrations.core.uploadFile(data: imageData, filename: "photo.png", mimeType: "image/png")
///
/// // Send email
/// try await base44.integrations.core.sendEmail(to: "user@example.com", subject: "Hi", html: "<p>Hello!</p>", text: "Hello!")
///
/// // Dynamic invocation
/// let response = try await base44.integrations.invoke(package: "Core", endpoint: "InvokeLLM", data: ["prompt": "Hi"])
/// ```
public struct IntegrationsModule: Sendable {
    private let http: HTTPClient
    private let appId: String

    init(http: HTTPClient, appId: String) {
        self.http = http
        self.appId = appId
    }

    // MARK: - Core integration shortcuts

    /// Core integration endpoints.
    public var core: CoreIntegrations { CoreIntegrations(http: http, appId: appId) }

    // MARK: - Generic invocation

    /// Invokes any integration endpoint.
    /// - Parameters:
    ///   - package: Integration package name (e.g. `"Core"` or an installable package name).
    ///   - endpoint: Endpoint name (e.g. `"InvokeLLM"`).
    ///   - data: JSON body.
    public func invoke(package: String, endpoint: String, data: JSONObject = [:]) async throws -> JSONObject {
        let path: String
        if package == "Core" {
            path = "/apps/\(appId)/integration-endpoints/Core/\(endpoint)"
        } else {
            path = "/apps/\(appId)/integration-endpoints/installable/\(package)/integration-endpoints/\(endpoint)"
        }
        let bodyData = try JSONSerialization.data(withJSONObject: data)
        let responseData = try await http.post(path: path, body: RawJSONEncodable(data: bodyData))
        return (try? JSONSerialization.jsonObject(with: responseData) as? JSONObject) ?? [:]
    }

    /// Invokes any integration endpoint with file uploads.
    public func invokeWithFiles(
        package: String,
        endpoint: String,
        fields: [String: String] = [:],
        files: [String: (data: Data, filename: String, mimeType: String)] = [:]
    ) async throws -> JSONObject {
        let path: String
        if package == "Core" {
            path = "/apps/\(appId)/integration-endpoints/Core/\(endpoint)"
        } else {
            path = "/apps/\(appId)/integration-endpoints/installable/\(package)/integration-endpoints/\(endpoint)"
        }
        var multipartFields: [String: MultipartField] = fields.mapValues { .text($0) }
        for (name, file) in files {
            multipartFields[name] = .file(file.data, filename: file.filename, mimeType: file.mimeType)
        }
        let multipart = MultipartBody(fields: multipartFields)
        let responseData = try await http.post(path: path, multipart: multipart)
        return (try? JSONSerialization.jsonObject(with: responseData) as? JSONObject) ?? [:]
    }
}

// MARK: - Email Attachment

/// A file to attach to a `sendEmail` call.
///
/// Provide exactly one content source per attachment:
/// - `.inline(filename:content:)` — base64-encoded bytes generated at runtime.
/// - `.stored(filename:fileURL:)` — a URL returned by `uploadFile` or `uploadPrivateFile`.
///
/// Allowed extensions: pdf, png, jpg/jpeg, gif, webp, csv, txt, md, ics, xlsx, docx.
/// Limits: up to 5 attachments, 5 MB each, 10 MB total.
public enum EmailAttachment: Sendable {
    /// Inline base64-encoded content (e.g. a PDF generated in the function).
    case inline(filename: String, content: String)
    /// A file already in storage, referenced by its upload URL.
    case stored(filename: String, fileURL: String)

    var jsonObject: JSONObject {
        switch self {
        case let .inline(filename, content):
            return ["filename": filename, "content": content]
        case let .stored(filename, fileURL):
            return ["filename": filename, "file_url": fileURL]
        }
    }
}

// MARK: - Core Integrations

/// Convenient typed wrappers for Base44 Core integration endpoints.
public struct CoreIntegrations: Sendable {
    private let http: HTTPClient
    private let appId: String

    init(http: HTTPClient, appId: String) {
        self.http = http
        self.appId = appId
    }

    private func corePath(_ endpoint: String) -> String {
        "/apps/\(appId)/integration-endpoints/Core/\(endpoint)"
    }

    // MARK: - LLM

    /// Invokes an LLM with a prompt.
    public func invokeLLM(
        prompt: String,
        systemPrompt: String? = nil,
        model: String? = nil,
        responseFormat: String? = nil,
        imageURL: String? = nil
    ) async throws -> JSONObject {
        var body: JSONObject = ["prompt": prompt]
        if let s = systemPrompt { body["systemPrompt"] = s }
        if let m = model { body["model"] = m }
        if let r = responseFormat { body["responseFormat"] = r }
        if let i = imageURL { body["imageUrl"] = i }
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let data = try await http.post(path: corePath("InvokeLLM"), body: RawJSONEncodable(data: bodyData))
        return (try? JSONSerialization.jsonObject(with: data) as? JSONObject) ?? [:]
    }

    // MARK: - Image generation

    /// Generates an image from a text prompt.
    public func generateImage(prompt: String, model: String? = nil) async throws -> JSONObject {
        var body: JSONObject = ["prompt": prompt]
        if let m = model { body["model"] = m }
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let data = try await http.post(path: corePath("GenerateImage"), body: RawJSONEncodable(data: bodyData))
        return (try? JSONSerialization.jsonObject(with: data) as? JSONObject) ?? [:]
    }

    // MARK: - File upload

    /// Uploads a public file and returns the URL.
    public func uploadFile(fileData: Data, filename: String, mimeType: String = "application/octet-stream") async throws -> JSONObject {
        let multipart = MultipartBody(fields: ["file": .file(fileData, filename: filename, mimeType: mimeType)])
        let data = try await http.post(path: corePath("UploadFile"), multipart: multipart)
        return (try? JSONSerialization.jsonObject(with: data) as? JSONObject) ?? [:]
    }

    /// Uploads a private file and returns a signed URL.
    public func uploadPrivateFile(fileData: Data, filename: String, mimeType: String = "application/octet-stream") async throws -> JSONObject {
        let multipart = MultipartBody(fields: ["file": .file(fileData, filename: filename, mimeType: mimeType)])
        let data = try await http.post(path: corePath("UploadPrivateFile"), multipart: multipart)
        return (try? JSONSerialization.jsonObject(with: data) as? JSONObject) ?? [:]
    }

    /// Creates a signed URL for an existing private file.
    public func createFileSignedUrl(fileKey: String) async throws -> JSONObject {
        let body: JSONObject = ["fileKey": fileKey]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let data = try await http.post(path: corePath("CreateFileSignedUrl"), body: RawJSONEncodable(data: bodyData))
        return (try? JSONSerialization.jsonObject(with: data) as? JSONObject) ?? [:]
    }

    // MARK: - Email

    /// Sends an email.
    ///
    /// At least one of `body`, `html`, or `text` is required; the backend returns 422 otherwise.
    ///
    /// | Fields set | Result |
    /// |---|---|
    /// | `body` or `html` alone | `text/html` email |
    /// | `text` alone | `text/plain` email |
    /// | `body`/`html` + `text` | `multipart/alternative` — one email, two representations; recipient sees whichever their client prefers — both parts must say the same thing |
    /// | `body` + `html` | **422** — same slot, set one not both |
    ///
    /// - Parameters:
    ///   - to: Recipient email address.
    ///   - subject: Email subject line.
    ///   - body: HTML email body content. Alias of `html` — set one or the other, never both.
    ///   - html: HTML email body content. The same thing as `body` under an explicit name.
    ///   - text: Plain-text email body content. On its own sends a `text/plain` email; alongside
    ///     `body`/`html` produces a `multipart/alternative` email — both parts must say the same thing.
    ///   - from: The name of the sender. If omitted, the app's name will be used.
    ///   - attachments: Up to 5 files to attach (5 MB each, 10 MB total).
    ///     Use `.inline(filename:content:)` for base64-encoded bytes or
    ///     `.stored(filename:fileURL:)` for a storage URL.
    public func sendEmail(
        to: String,
        subject: String,
        body: String? = nil,
        html: String? = nil,
        text: String? = nil,
        from: String? = nil,
        attachments: [EmailAttachment]? = nil
    ) async throws -> JSONObject {
        var payload: JSONObject = ["to": to, "subject": subject]
        if let b = body { payload["body"] = b }
        if let h = html { payload["html"] = h }
        if let t = text { payload["text"] = t }
        if let f = from { payload["from"] = f }
        if let list = attachments { payload["attachments"] = list.map { $0.jsonObject } }
        let bodyData = try JSONSerialization.data(withJSONObject: payload)
        let data = try await http.post(path: corePath("SendEmail"), body: RawJSONEncodable(data: bodyData))
        return (try? JSONSerialization.jsonObject(with: data) as? JSONObject) ?? [:]
    }

    // MARK: - Data extraction

    /// Extracts structured data from an uploaded file.
    public func extractDataFromUploadedFile(fileURL: String, extractionPrompt: String) async throws -> JSONObject {
        let body: JSONObject = ["fileUrl": fileURL, "extractionPrompt": extractionPrompt]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let data = try await http.post(path: corePath("ExtractDataFromUploadedFile"), body: RawJSONEncodable(data: bodyData))
        return (try? JSONSerialization.jsonObject(with: data) as? JSONObject) ?? [:]
    }
}
