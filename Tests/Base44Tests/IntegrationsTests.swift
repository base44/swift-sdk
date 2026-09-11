import XCTest
@testable import Base44

final class IntegrationsTests: XCTestCase {

    let appId = "integrations-test-app"

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func makeClient() -> Base44Client {
        createClient(config: CreateClientConfig(
            appId: appId,
            token: "test-token",
            urlSession: makeMockSession()
        ))
    }

    // MARK: - invokeLLM

    func testInvokeLLM() async throws {
        let responseBody: [String: Any] = ["response": "The answer is 42.", "model": "gpt-4"]
        MockURLProtocol.mockJSONObject(
            path: "/api/apps/\(appId)/integration-endpoints/Core/InvokeLLM",
            object: responseBody
        )

        let client = makeClient()
        let result = try await client.integrations.core.invokeLLM(prompt: "What is the answer?")

        XCTAssertEqual(result["response"] as? String, "The answer is 42.")
    }

    func testInvokeLLMRequestPath() async throws {
        MockURLProtocol.mockJSONObject(
            path: "/api/apps/\(appId)/integration-endpoints/Core/InvokeLLM",
            object: ["response": "ok"]
        )

        let client = makeClient()
        _ = try await client.integrations.core.invokeLLM(prompt: "Hello")

        let path = MockURLProtocol.lastRequest?.url?.path ?? ""
        XCTAssertTrue(path.contains("integration-endpoints/Core/InvokeLLM"), "Unexpected path: \(path)")
        XCTAssertEqual(MockURLProtocol.lastRequest?.httpMethod, "POST")
    }

    func testInvokeLLMPassesPrompt() async throws {
        MockURLProtocol.mockJSONObject(
            path: "/api/apps/\(appId)/integration-endpoints/Core/InvokeLLM",
            object: ["response": "result"]
        )

        let client = makeClient()
        _ = try await client.integrations.core.invokeLLM(prompt: "What is Swift?", model: "claude-3")

        if let bodyData = MockURLProtocol.lastRequest?.httpBody {
            let body = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
            XCTAssertEqual(body?["prompt"] as? String, "What is Swift?")
            XCTAssertEqual(body?["model"] as? String, "claude-3")
        }
    }

    // MARK: - generateImage

    func testGenerateImage() async throws {
        let responseBody: [String: Any] = ["url": "https://cdn.example.com/image.png"]
        MockURLProtocol.mockJSONObject(
            path: "/api/apps/\(appId)/integration-endpoints/Core/GenerateImage",
            object: responseBody
        )

        let client = makeClient()
        let result = try await client.integrations.core.generateImage(prompt: "A beautiful sunset")

        XCTAssertEqual(result["url"] as? String, "https://cdn.example.com/image.png")
    }

    func testGenerateImageRequestPath() async throws {
        MockURLProtocol.mockJSONObject(
            path: "/api/apps/\(appId)/integration-endpoints/Core/GenerateImage",
            object: ["url": "https://example.com/img.png"]
        )

        let client = makeClient()
        _ = try await client.integrations.core.generateImage(prompt: "test")

        let path = MockURLProtocol.lastRequest?.url?.path ?? ""
        XCTAssertTrue(path.contains("GenerateImage"), "Unexpected path: \(path)")
    }

    // MARK: - uploadFile

    func testUploadFile() async throws {
        let responseBody: [String: Any] = ["file_url": "https://storage.example.com/uploads/photo.jpg"]
        MockURLProtocol.mockJSONObject(
            path: "/api/apps/\(appId)/integration-endpoints/Core/UploadFile",
            object: responseBody
        )

        let client = makeClient()
        let fileData = "fake image data".data(using: .utf8)!
        let result = try await client.integrations.core.uploadFile(
            fileData: fileData,
            filename: "photo.jpg",
            mimeType: "image/jpeg"
        )

        XCTAssertEqual(result["file_url"] as? String, "https://storage.example.com/uploads/photo.jpg")
    }

    func testUploadFileUsesMultipart() async throws {
        MockURLProtocol.mockJSONObject(
            path: "/api/apps/\(appId)/integration-endpoints/Core/UploadFile",
            object: ["file_url": "https://example.com/file.txt"]
        )

        let client = makeClient()
        let fileData = "test content".data(using: .utf8)!
        _ = try await client.integrations.core.uploadFile(fileData: fileData, filename: "test.txt", mimeType: "text/plain")

        let contentType = MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Content-Type") ?? ""
        XCTAssertTrue(contentType.contains("multipart/form-data"), "Expected multipart content type, got: \(contentType)")
    }

    // MARK: - sendEmail

    func testSendEmail() async throws {
        let responseBody: [String: Any] = ["sent": true, "message_id": "msg-123"]
        MockURLProtocol.mockJSONObject(
            path: "/api/apps/\(appId)/integration-endpoints/Core/SendEmail",
            object: responseBody
        )

        let client = makeClient()
        let result = try await client.integrations.core.sendEmail(
            to: "recipient@example.com",
            subject: "Hello!",
            body: "This is a test email."
        )

        XCTAssertEqual(result["sent"] as? Bool, true)
    }

    func testSendEmailRequestBody() async throws {
        MockURLProtocol.mockJSONObject(
            path: "/api/apps/\(appId)/integration-endpoints/Core/SendEmail",
            object: ["sent": true]
        )

        let client = makeClient()
        _ = try await client.integrations.core.sendEmail(
            to: "user@example.com",
            subject: "Test Subject",
            body: "Test body text"
        )

        if let bodyData = MockURLProtocol.lastRequest?.httpBody {
            let body = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
            XCTAssertEqual(body?["to"] as? String, "user@example.com")
            XCTAssertEqual(body?["subject"] as? String, "Test Subject")
            XCTAssertEqual(body?["body"] as? String, "Test body text")
        }
    }

    func testSendEmailWithHtmlAndText() async throws {
        MockURLProtocol.mockJSONObject(
            path: "/api/apps/\(appId)/integration-endpoints/Core/SendEmail",
            object: ["sent": true]
        )

        let client = makeClient()
        _ = try await client.integrations.core.sendEmail(
            to: "user@example.com",
            subject: "Multipart",
            html: "<p>Hello</p>",
            text: "Hello"
        )

        if let bodyData = MockURLProtocol.lastRequest?.httpBody {
            let body = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
            XCTAssertEqual(body?["html"] as? String, "<p>Hello</p>")
            XCTAssertEqual(body?["text"] as? String, "Hello")
            XCTAssertNil(body?["body"], "body should not be sent when html is used")
        }
    }

    func testSendEmailTextOnly() async throws {
        MockURLProtocol.mockJSONObject(
            path: "/api/apps/\(appId)/integration-endpoints/Core/SendEmail",
            object: ["sent": true]
        )

        let client = makeClient()
        _ = try await client.integrations.core.sendEmail(
            to: "user@example.com",
            subject: "Plain text",
            text: "Hello plain"
        )

        if let bodyData = MockURLProtocol.lastRequest?.httpBody {
            let body = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
            XCTAssertEqual(body?["text"] as? String, "Hello plain")
            XCTAssertNil(body?["html"])
            XCTAssertNil(body?["body"])
        }
    }

    // MARK: - extractDataFromUploadedFile

    func testExtractDataFromUploadedFile() async throws {
        let responseBody: [String: Any] = ["extracted": ["name": "John Doe", "amount": 150.0]]
        MockURLProtocol.mockJSONObject(
            path: "/api/apps/\(appId)/integration-endpoints/Core/ExtractDataFromUploadedFile",
            object: responseBody
        )

        let client = makeClient()
        let result = try await client.integrations.core.extractDataFromUploadedFile(
            fileURL: "https://storage.example.com/invoice.pdf",
            extractionPrompt: "Extract name and amount from the invoice"
        )

        XCTAssertEqual(result["extracted"] as? [String: Any] != nil, true)
    }

    // MARK: - Generic invoke

    func testGenericInvoke() async throws {
        let responseBody: [String: Any] = ["result": "success"]
        MockURLProtocol.mockJSONObject(
            path: "/api/apps/\(appId)/integration-endpoints/Core/InvokeLLM",
            object: responseBody
        )

        let client = makeClient()
        let result = try await client.integrations.invoke(
            package: "Core",
            endpoint: "InvokeLLM",
            data: ["prompt": "Test prompt"]
        )

        XCTAssertEqual(result["result"] as? String, "success")
    }
}
