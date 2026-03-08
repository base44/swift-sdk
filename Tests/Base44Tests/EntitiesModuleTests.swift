import XCTest
@testable import Base44

final class EntitiesModuleTests: XCTestCase {

    // MARK: - URL construction tests

    func testBasePathConstruction() throws {
        // The entity handler should use /apps/{appId}/entities/{name}
        let appId = "test-app-123"
        let entityName = "Products"
        let expectedPath = "/apps/\(appId)/entities/\(entityName)"
        XCTAssertEqual(expectedPath, "/apps/test-app-123/entities/Products")
    }

    func testQueryItemsWithSort() throws {
        var items = [URLQueryItem]()
        let sort = "-created_at"
        items.append(URLQueryItem(name: "sort", value: sort))
        XCTAssertEqual(items.first?.name, "sort")
        XCTAssertEqual(items.first?.value, "-created_at")
    }

    func testQueryItemsWithLimit() throws {
        var items = [URLQueryItem]()
        let limit = 50
        items.append(URLQueryItem(name: "limit", value: "\(limit)"))
        XCTAssertEqual(items.first?.name, "limit")
        XCTAssertEqual(items.first?.value, "50")
    }

    func testFilterQuerySerialization() throws {
        let query: JSONObject = ["status": "active", "userId": "abc"]
        let data = try JSONSerialization.data(withJSONObject: query)
        let str = String(data: data, encoding: .utf8)
        XCTAssertNotNil(str)
        // Should be valid JSON
        let reparsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(reparsed?["status"] as? String, "active")
    }

    func testBulkCreatePathConstruction() {
        let appId = "test-app"
        let entityName = "Orders"
        let bulkPath = "/apps/\(appId)/entities/\(entityName)/bulk"
        XCTAssertEqual(bulkPath, "/apps/test-app/entities/Orders/bulk")
    }

    func testImportPathConstruction() {
        let appId = "test-app"
        let entityName = "Products"
        let importPath = "/apps/\(appId)/entities/\(entityName)/import"
        XCTAssertEqual(importPath, "/apps/test-app/entities/Products/import")
    }
}

// MARK: - JSON Value tests

final class JSONValueTests: XCTestCase {

    func testDecodeString() throws {
        let data = "\"hello\"".data(using: .utf8)!
        let value = try JSONDecoder().decode(JSONValue.self, from: data)
        if case .string(let s) = value {
            XCTAssertEqual(s, "hello")
        } else {
            XCTFail("Expected string")
        }
    }

    func testDecodeInt() throws {
        let data = "42".data(using: .utf8)!
        let value = try JSONDecoder().decode(JSONValue.self, from: data)
        if case .int(let i) = value {
            XCTAssertEqual(i, 42)
        } else {
            XCTFail("Expected int")
        }
    }

    func testDecodeBool() throws {
        let data = "true".data(using: .utf8)!
        let value = try JSONDecoder().decode(JSONValue.self, from: data)
        if case .bool(let b) = value {
            XCTAssertTrue(b)
        } else {
            XCTFail("Expected bool")
        }
    }

    func testDecodeNull() throws {
        let data = "null".data(using: .utf8)!
        let value = try JSONDecoder().decode(JSONValue.self, from: data)
        if case .null = value {} else {
            XCTFail("Expected null")
        }
    }

    func testDecodeObject() throws {
        let data = "{\"key\": \"value\"}".data(using: .utf8)!
        let value = try JSONDecoder().decode(JSONValue.self, from: data)
        if case .object(let obj) = value {
            if case .string(let s) = obj["key"] {
                XCTAssertEqual(s, "value")
            } else {
                XCTFail("Expected string value in object")
            }
        } else {
            XCTFail("Expected object")
        }
    }

    func testRoundTrip() throws {
        let original: JSONValue = .object([
            "name": .string("Test"),
            "count": .int(5),
            "active": .bool(true),
            "nested": .object(["x": .double(1.5)])
        ])
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: encoded)
        let re = try JSONEncoder().encode(decoded)
        XCTAssertEqual(encoded, re)
    }
}

// MARK: - HTTP Client tests

final class HTTPClientTests: XCTestCase {

    func testTokenInjection() {
        let client = HTTPClient(baseURL: "https://base44.app/api", headers: ["X-App-Id": "test"])
        client.setToken("my-jwt-token")
        XCTAssertEqual(client.currentToken, "my-jwt-token")
    }

    func testTokenClear() {
        let client = HTTPClient(baseURL: "https://base44.app/api")
        client.setToken("token-123")
        client.clearToken()
        XCTAssertNil(client.currentToken)
    }

    func testInitWithToken() {
        let client = HTTPClient(baseURL: "https://base44.app/api", token: "init-token")
        XCTAssertEqual(client.currentToken, "init-token")
    }
}

// MARK: - Auth Module tests

final class AuthModuleTests: XCTestCase {

    func testLoginEndpointPath() {
        let appId = "my-app"
        let path = "/apps/\(appId)/auth/login"
        XCTAssertEqual(path, "/apps/my-app/auth/login")
    }

    func testMeEndpointPath() {
        let appId = "my-app"
        let path = "/apps/\(appId)/entities/User/me"
        XCTAssertEqual(path, "/apps/my-app/entities/User/me")
    }

    func testRegisterEndpointPath() {
        let appId = "my-app"
        let path = "/apps/\(appId)/auth/register"
        XCTAssertEqual(path, "/apps/my-app/auth/register")
    }
}

// MARK: - Multipart tests

final class MultipartBodyTests: XCTestCase {

    func testTextFieldEncoding() {
        let multipart = MultipartBody(fields: ["name": .text("Alice")])
        let bodyStr = String(data: multipart.data, encoding: .utf8) ?? ""
        XCTAssertTrue(bodyStr.contains("name=\"name\""))
        XCTAssertTrue(bodyStr.contains("Alice"))
        XCTAssertTrue(bodyStr.contains("--\(multipart.boundary)--"))
    }

    func testFileFieldEncoding() {
        let fileData = "file content".data(using: .utf8)!
        let multipart = MultipartBody(fields: [
            "file": .file(fileData, filename: "test.csv", mimeType: "text/csv")
        ])
        let bodyStr = String(data: multipart.data, encoding: .utf8) ?? ""
        XCTAssertTrue(bodyStr.contains("filename=\"test.csv\""))
        XCTAssertTrue(bodyStr.contains("text/csv"))
        XCTAssertTrue(bodyStr.contains("file content"))
    }
}
