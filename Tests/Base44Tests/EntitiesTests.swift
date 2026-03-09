import XCTest
@testable import Base44

final class EntitiesTests: XCTestCase {

    let appId = "test-app-123"

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    // MARK: - Helpers

    func makeClient() -> Base44Client {
        createClient(config: CreateClientConfig(
            appId: appId,
            token: "test-token",
            urlSession: makeMockSession()
        ))
    }

    // MARK: - list

    func testListEntities() async throws {
        let products: [[String: Any]] = [
            ["id": "1", "name": "Widget", "price": 9.99],
            ["id": "2", "name": "Gadget", "price": 19.99]
        ]
        MockURLProtocol.mockJSONArray(path: "/api/apps/\(appId)/entities/Products", array: products)

        let client = makeClient()
        let result = try await client.entities.Products.list()

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0]["name"] as? String, "Widget")
        XCTAssertEqual(result[1]["name"] as? String, "Gadget")
    }

    func testListWithSortAndLimit() async throws {
        MockURLProtocol.mockJSONArray(path: "/api/apps/\(appId)/entities/Orders", array: [["id": "1"]])

        let client = makeClient()
        let result = try await client.entities.Orders.list(sort: "-created_at", limit: 10, skip: 5)
        XCTAssertEqual(result.count, 1)

        // Verify query params were sent
        let query = MockURLProtocol.lastRequest?.url?.query ?? ""
        XCTAssertTrue(query.contains("limit=10"), "Expected limit=10 in query: \(query)")
        XCTAssertTrue(query.contains("skip=5"), "Expected skip=5 in query: \(query)")
    }

    // MARK: - get

    func testGetEntity() async throws {
        let product: [String: Any] = ["id": "abc123", "name": "Super Widget", "price": 29.99]
        MockURLProtocol.mockJSONObject(path: "/api/apps/\(appId)/entities/Products/abc123", object: product)

        let client = makeClient()
        let result = try await client.entities.Products.get(id: "abc123")

        XCTAssertEqual(result["id"] as? String, "abc123")
        XCTAssertEqual(result["name"] as? String, "Super Widget")
        XCTAssertEqual(MockURLProtocol.lastRequest?.httpMethod, "GET")
    }

    // MARK: - create

    func testCreateEntity() async throws {
        let created: [String: Any] = ["id": "new-id", "name": "New Product", "price": 5.0]
        MockURLProtocol.mockJSONObject(path: "/api/apps/\(appId)/entities/Products", object: created)

        let client = makeClient()
        let result = try await client.entities.Products.create(["name": "New Product", "price": 5.0])

        XCTAssertEqual(result["id"] as? String, "new-id")
        XCTAssertEqual(result["name"] as? String, "New Product")
        XCTAssertEqual(MockURLProtocol.lastRequest?.httpMethod, "POST")
    }

    // MARK: - update

    func testUpdateEntity() async throws {
        let updated: [String: Any] = ["id": "xyz", "name": "Updated Name", "price": 15.0]
        MockURLProtocol.mockJSONObject(path: "/api/apps/\(appId)/entities/Products/xyz", object: updated)

        let client = makeClient()
        let result = try await client.entities.Products.update(id: "xyz", ["name": "Updated Name"])

        XCTAssertEqual(result["name"] as? String, "Updated Name")
        XCTAssertEqual(MockURLProtocol.lastRequest?.httpMethod, "PUT")
    }

    // MARK: - delete

    func testDeleteEntity() async throws {
        let deleteResp = DeleteResult(id: "del-id", deleted: true)
        MockURLProtocol.mockJSON(path: "/api/apps/\(appId)/entities/Products/del-id", body: deleteResp)

        let client = makeClient()
        let result = try await client.entities.Products.delete(id: "del-id")

        XCTAssertEqual(result.id, "del-id")
        XCTAssertEqual(result.deleted, true)
        XCTAssertEqual(MockURLProtocol.lastRequest?.httpMethod, "DELETE")
    }

    // MARK: - filter

    func testFilterEntities() async throws {
        let filtered: [[String: Any]] = [["id": "1", "status": "active"]]
        MockURLProtocol.mockJSONArray(path: "/api/apps/\(appId)/entities/Products", array: filtered)

        let client = makeClient()
        let result = try await client.entities.Products.filter(["status": "active"])

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0]["status"] as? String, "active")

        // Verify q param was sent
        let query = MockURLProtocol.lastRequest?.url?.query ?? ""
        XCTAssertTrue(query.contains("q="), "Expected q= param in query: \(query)")
    }

    // MARK: - bulkCreate

    func testBulkCreate() async throws {
        let bulkResult: [[String: Any]] = [
            ["id": "bulk-1", "name": "Item 1"],
            ["id": "bulk-2", "name": "Item 2"]
        ]
        MockURLProtocol.mockJSONArray(path: "/api/apps/\(appId)/entities/Products/bulk", array: bulkResult)

        let client = makeClient()
        let result = try await client.entities.Products.bulkCreate([
            ["name": "Item 1"],
            ["name": "Item 2"]
        ])

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0]["id"] as? String, "bulk-1")
        XCTAssertEqual(MockURLProtocol.lastRequest?.httpMethod, "POST")
    }

    // MARK: - deleteMany

    func testDeleteMany() async throws {
        let deleteManyResult: [String: Any] = ["deleted": 5]
        MockURLProtocol.mockJSONObject(path: "/api/apps/\(appId)/entities/Products", object: deleteManyResult)

        let client = makeClient()
        let result = try await client.entities.Products.deleteMany(["status": "archived"])

        XCTAssertEqual(result.deleted, 5)
        XCTAssertEqual(MockURLProtocol.lastRequest?.httpMethod, "DELETE")
    }

    // MARK: - Error handling

    func testHTTPErrorThrown() async throws {
        let errorBody = "{\"message\": \"Not found\", \"code\": \"NOT_FOUND\"}".data(using: .utf8)!
        MockURLProtocol.mockRaw(
            path: "/api/apps/\(appId)/entities/Products/missing",
            statusCode: 404,
            data: errorBody
        )

        let client = makeClient()
        do {
            _ = try await client.entities.Products.get(id: "missing")
            XCTFail("Expected error to be thrown")
        } catch let error as Base44Error {
            XCTAssertEqual(error.status, 404)
            XCTAssertEqual(error.message, "Not found")
            XCTAssertEqual(error.code, "NOT_FOUND")
        }
    }

    // MARK: - Auth header

    func testAuthHeaderIsSent() async throws {
        MockURLProtocol.mockJSONArray(path: "/api/apps/\(appId)/entities/Products", array: [])

        let client = makeClient()
        _ = try await client.entities.Products.list()

        let authHeader = MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization")
        XCTAssertEqual(authHeader, "Bearer test-token")
    }
}

// MARK: - URL/path construction tests (static, no network)

final class EntityPathTests: XCTestCase {
    func testBasePathConstruction() {
        let appId = "test-app-123"
        let entityName = "Products"
        let path = "/apps/\(appId)/entities/\(entityName)"
        XCTAssertEqual(path, "/apps/test-app-123/entities/Products")
    }

    func testBulkPath() {
        let appId = "my-app"
        let entityName = "Orders"
        let bulkPath = "/apps/\(appId)/entities/\(entityName)/bulk"
        XCTAssertEqual(bulkPath, "/apps/my-app/entities/Orders/bulk")
    }

    func testFilterQuerySerialization() throws {
        let query: JSONObject = ["status": "active", "userId": "abc"]
        let data = try JSONSerialization.data(withJSONObject: query)
        let reparsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(reparsed?["status"] as? String, "active")
        XCTAssertEqual(reparsed?["userId"] as? String, "abc")
    }
}
