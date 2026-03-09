import XCTest
@testable import Base44

final class FunctionsTests: XCTestCase {

    let appId = "functions-test-app"

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

    // MARK: - invoke

    func testInvokeFunction() async throws {
        let responseBody: [String: Any] = ["result": "ok", "count": 42]
        MockURLProtocol.mockJSONObject(
            path: "/api/apps/\(appId)/functions/myFunction",
            object: responseBody
        )

        let client = makeClient()
        let result = try await client.functions.invoke("myFunction", data: ["key": "value"])

        XCTAssertEqual(result["result"] as? String, "ok")
        XCTAssertEqual(result["count"] as? Int, 42)
    }

    func testInvokeRequestMethod() async throws {
        MockURLProtocol.mockJSONObject(path: "/api/apps/\(appId)/functions/doStuff", object: [:])

        let client = makeClient()
        _ = try await client.functions.invoke("doStuff")

        XCTAssertEqual(MockURLProtocol.lastRequest?.httpMethod, "POST")
    }

    func testInvokeRequestPath() async throws {
        MockURLProtocol.mockJSONObject(path: "/api/apps/\(appId)/functions/sendEmail", object: [:])

        let client = makeClient()
        _ = try await client.functions.invoke("sendEmail", data: ["to": "user@example.com"])

        let path = MockURLProtocol.lastRequest?.url?.path ?? ""
        XCTAssertTrue(path.hasSuffix("/functions/sendEmail"), "Unexpected path: \(path)")
    }

    func testInvokePassesBodyData() async throws {
        MockURLProtocol.mockJSONObject(path: "/api/apps/\(appId)/functions/process", object: ["done": true])

        let client = makeClient()
        _ = try await client.functions.invoke("process", data: ["userId": "u123", "action": "activate"])

        let req = MockURLProtocol.lastRequest
        if let bodyData = req?.httpBody {
            let body = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
            XCTAssertEqual(body?["userId"] as? String, "u123")
            XCTAssertEqual(body?["action"] as? String, "activate")
        }
    }

    func testInvokeEmptyBody() async throws {
        let responseBody: [String: Any] = ["status": "executed"]
        MockURLProtocol.mockJSONObject(path: "/api/apps/\(appId)/functions/noArgs", object: responseBody)

        let client = makeClient()
        let result = try await client.functions.invoke("noArgs")

        XCTAssertEqual(result["status"] as? String, "executed")
    }

    func testInvokeNestedResponse() async throws {
        let responseBody: [String: Any] = [
            "data": ["items": [1, 2, 3], "total": 3],
            "success": true
        ]
        MockURLProtocol.mockJSONObject(path: "/api/apps/\(appId)/functions/getItems", object: responseBody)

        let client = makeClient()
        let result = try await client.functions.invoke("getItems")

        XCTAssertEqual(result["success"] as? Bool, true)
        let data = result["data"] as? [String: Any]
        XCTAssertNotNil(data)
    }

    // MARK: - Error handling

    func testInvokeThrowsOnHTTPError() async throws {
        let errorBody = "{\"message\": \"Function not found\"}".data(using: .utf8)!
        MockURLProtocol.mockRaw(
            path: "/api/apps/\(appId)/functions/missing",
            statusCode: 404,
            data: errorBody
        )

        let client = makeClient()
        do {
            _ = try await client.functions.invoke("missing")
            XCTFail("Expected error")
        } catch let error as Base44Error {
            XCTAssertEqual(error.status, 404)
            XCTAssertEqual(error.message, "Function not found")
        }
    }
}
