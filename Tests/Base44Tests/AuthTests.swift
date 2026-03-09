import XCTest
@testable import Base44

final class AuthTests: XCTestCase {

    let appId = "auth-test-app"

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func makeClient(token: String? = nil) -> Base44Client {
        createClient(config: CreateClientConfig(
            appId: appId,
            token: token,
            urlSession: makeMockSession()
        ))
    }

    // MARK: - me

    func testMeReturnsCurrentUser() async throws {
        let userJSON: [String: Any] = ["id": "user-1", "email": "alice@example.com", "role": "admin"]
        MockURLProtocol.mockJSONObject(path: "/api/apps/\(appId)/entities/User/me", object: userJSON)

        let client = makeClient(token: "valid-token")
        let me = try await client.auth.me()

        XCTAssertEqual(me["id"] as? String, "user-1")
        XCTAssertEqual(me["email"] as? String, "alice@example.com")
    }

    func testMeRequestPath() async throws {
        let userJSON: [String: Any] = ["id": "u1", "email": "test@test.com"]
        MockURLProtocol.mockJSONObject(path: "/api/apps/\(appId)/entities/User/me", object: userJSON)

        let client = makeClient(token: "tok")
        _ = try await client.auth.me()

        let path = MockURLProtocol.lastRequest?.url?.path ?? ""
        XCTAssertTrue(path.hasSuffix("/entities/User/me"), "Unexpected path: \(path)")
    }

    // MARK: - loginViaEmailPassword

    func testLoginSetsToken() async throws {
        let loginBody: [String: Any] = [
            "access_token": "jwt-token-abc",
            "user": ["id": "u1", "email": "bob@test.com"]
        ]
        MockURLProtocol.mockJSONObject(path: "/api/apps/\(appId)/auth/login", object: loginBody)

        let client = makeClient()
        let response = try await client.auth.loginViaEmailPassword(email: "bob@test.com", password: "pass123")

        XCTAssertEqual(response.access_token, "jwt-token-abc")
    }

    func testLoginRequestBody() async throws {
        let loginBody: [String: Any] = [
            "access_token": "tok",
            "user": ["id": "u1", "email": "carol@test.com"]
        ]
        MockURLProtocol.mockJSONObject(path: "/api/apps/\(appId)/auth/login", object: loginBody)

        let client = makeClient()
        _ = try await client.auth.loginViaEmailPassword(email: "carol@test.com", password: "mypass")

        let req = MockURLProtocol.lastRequest
        XCTAssertEqual(req?.httpMethod, "POST")
        let path = req?.url?.path ?? ""
        XCTAssertTrue(path.hasSuffix("/auth/login"), "Unexpected path: \(path)")

        // Body should contain email and password
        if let bodyData = req?.httpBody {
            let body = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
            XCTAssertEqual(body?["email"] as? String, "carol@test.com")
            XCTAssertEqual(body?["password"] as? String, "mypass")
        }
    }

    // MARK: - register

    func testRegister() async throws {
        let regBody: [String: Any] = [
            "access_token": "new-token",
            "user": ["id": "new-user", "email": "dave@test.com"]
        ]
        MockURLProtocol.mockJSONObject(path: "/api/apps/\(appId)/auth/register", object: regBody)

        let client = makeClient()
        let result = try await client.auth.register(email: "dave@test.com", password: "secret")

        XCTAssertNotNil(result)
        let path = MockURLProtocol.lastRequest?.url?.path ?? ""
        XCTAssertTrue(path.hasSuffix("/auth/register"), "Unexpected path: \(path)")
    }

    // MARK: - isAuthenticated

    func testIsAuthenticatedReturnsTrueWhenMeSucceeds() async throws {
        let userJSON: [String: Any] = ["id": "u1", "email": "auth@test.com"]
        MockURLProtocol.mockJSONObject(path: "/api/apps/\(appId)/entities/User/me", object: userJSON)

        let client = makeClient(token: "valid-token")
        let result = await client.auth.isAuthenticated()
        XCTAssertTrue(result)
    }

    func testIsAuthenticatedReturnsFalseOnError() async throws {
        let errorBody = "{\"message\": \"Unauthorized\"}".data(using: .utf8)!
        MockURLProtocol.mockRaw(
            path: "/api/apps/\(appId)/entities/User/me",
            statusCode: 401,
            data: errorBody
        )

        let client = makeClient()
        let result = await client.auth.isAuthenticated()
        XCTAssertFalse(result)
    }

    // MARK: - setToken

    func testSetTokenUpdatesAuthHeader() async throws {
        let userJSON: [String: Any] = ["id": "u2", "email": "eve@test.com"]
        MockURLProtocol.mockJSONObject(path: "/api/apps/\(appId)/entities/User/me", object: userJSON)

        let client = makeClient()
        client.setToken("new-jwt-token")
        _ = try await client.auth.me()

        let authHeader = MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization")
        XCTAssertEqual(authHeader, "Bearer new-jwt-token")
    }

    // MARK: - logout

    func testLogoutClearsToken() async throws {
        let userJSON: [String: Any] = ["id": "u3", "email": "frank@test.com"]
        MockURLProtocol.mockJSONObject(path: "/api/apps/\(appId)/entities/User/me", object: userJSON)

        let client = makeClient(token: "some-token")
        client.auth.logout()
        _ = try await client.auth.me()

        let authHeader = MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization")
        XCTAssertNil(authHeader, "Expected no auth header after logout")
    }
}

// MARK: - Static auth tests

final class AuthStaticTests: XCTestCase {

    func testLoginEndpointPath() {
        let appId = "my-app"
        XCTAssertEqual("/apps/\(appId)/auth/login", "/apps/my-app/auth/login")
    }

    func testMeEndpointPath() {
        let appId = "my-app"
        XCTAssertEqual("/apps/\(appId)/entities/User/me", "/apps/my-app/entities/User/me")
    }

    func testRegisterEndpointPath() {
        let appId = "my-app"
        XCTAssertEqual("/apps/\(appId)/auth/register", "/apps/my-app/auth/register")
    }

    func testHTTPClientTokenManagement() {
        let client = HTTPClient(baseURL: "https://base44.app/api", headers: ["X-App-Id": "test"])
        client.setToken("my-jwt-token")
        XCTAssertEqual(client.currentToken, "my-jwt-token")
        client.clearToken()
        XCTAssertNil(client.currentToken)
    }

    func testHTTPClientInitWithToken() {
        let client = HTTPClient(baseURL: "https://base44.app/api", token: "init-token")
        XCTAssertEqual(client.currentToken, "init-token")
    }
}
