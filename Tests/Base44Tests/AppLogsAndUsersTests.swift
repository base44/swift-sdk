import XCTest
@testable import Base44

// MARK: - AppLogs Tests

final class AppLogsTests: XCTestCase {

    let appId = "logs-test-app"

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

    func testListAppLogs() async throws {
        let logsJSON: [[String: Any]] = [
            ["id": "log-1", "app_id": appId, "created_at": "2024-01-01T00:00:00Z"],
            ["id": "log-2", "app_id": appId, "created_at": "2024-01-01T01:00:00Z"]
        ]
        MockURLProtocol.mockJSONArray(path: "/api/apps/\(appId)/app-logs", array: logsJSON)

        let client = makeClient()
        let logs = try await client.appLogs.list()

        XCTAssertEqual(logs.count, 2)
        XCTAssertEqual(logs[0]["id"] as? String, "log-1")
    }

    func testListAppLogsWithLimit() async throws {
        MockURLProtocol.mockJSONArray(path: "/api/apps/\(appId)/app-logs", array: [["id": "log-1"]])

        let client = makeClient()
        _ = try await client.appLogs.list(limit: 10, skip: 20)

        let query = MockURLProtocol.lastRequest?.url?.query ?? ""
        XCTAssertTrue(query.contains("limit=10"), "Expected limit=10 in query: \(query)")
        XCTAssertTrue(query.contains("skip=20"), "Expected skip=20 in query: \(query)")
    }

    func testListAppLogsEmptyResponse() async throws {
        MockURLProtocol.mockJSONArray(path: "/api/apps/\(appId)/app-logs", array: [])

        let client = makeClient()
        let logs = try await client.appLogs.list()

        XCTAssertTrue(logs.isEmpty)
    }

    func testListAppLogsRequestMethod() async throws {
        MockURLProtocol.mockJSONArray(path: "/api/apps/\(appId)/app-logs", array: [])

        let client = makeClient()
        _ = try await client.appLogs.list()

        XCTAssertEqual(MockURLProtocol.lastRequest?.httpMethod, "GET")
    }
}

// MARK: - Users Tests

final class UsersTests: XCTestCase {

    let appId = "users-test-app"

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
            token: "admin-token",
            urlSession: makeMockSession()
        ))
    }

    func testInviteUser() async throws {
        let responseBody: [String: Any] = ["success": true, "message": "Invitation sent"]
        MockURLProtocol.mockJSONObject(
            path: "/api/apps/\(appId)/users/invite-user",
            object: responseBody
        )

        let client = makeClient()
        let result = try await client.users.inviteUser(email: "new@example.com", role: "member")

        XCTAssertNotNil(result)
        XCTAssertEqual(MockURLProtocol.lastRequest?.httpMethod, "POST")
    }

    func testInviteUserRequestBody() async throws {
        MockURLProtocol.mockJSONObject(
            path: "/api/apps/\(appId)/users/invite-user",
            object: ["success": true]
        )

        let client = makeClient()
        _ = try await client.users.inviteUser(email: "invite@test.com", role: "viewer")

        if let bodyData = MockURLProtocol.lastRequest?.httpBody {
            let body = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
            XCTAssertEqual(body?["user_email"] as? String, "invite@test.com")
            XCTAssertEqual(body?["role"] as? String, "viewer")
        }
    }

    func testListUsers() async throws {
        let usersJSON: [[String: Any]] = [
            ["id": "u1", "email": "alice@example.com", "role": "admin"],
            ["id": "u2", "email": "bob@example.com", "role": "member"]
        ]
        MockURLProtocol.mockJSONArray(path: "/api/apps/\(appId)/users", array: usersJSON)

        let client = makeClient()
        let users = try await client.users.list()

        XCTAssertEqual(users.count, 2)
        XCTAssertEqual(users[0]["email"] as? String, "alice@example.com")
    }

    func testInviteUserPath() async throws {
        MockURLProtocol.mockJSONObject(
            path: "/api/apps/\(appId)/users/invite-user",
            object: ["success": true]
        )

        let client = makeClient()
        _ = try await client.users.inviteUser(email: "test@test.com", role: "admin")

        let path = MockURLProtocol.lastRequest?.url?.path ?? ""
        XCTAssertTrue(path.hasSuffix("/users/invite-user"), "Unexpected path: \(path)")
    }
}
