import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import Base44

final class AgentsTests: XCTestCase {

    let appId = "agents-test-app"

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

    // MARK: - createConversation

    func testCreateConversation() async throws {
        let convJSON: [String: Any] = [
            "id": "conv-123",
            "agent_name": "SupportBot",
            "title": "Help with order",
            "status": "active",
            "created_at": "2024-01-01T00:00:00Z"
        ]
        MockURLProtocol.mockJSONObject(
            path: "/api/apps/\(appId)/agents/conversations",
            object: convJSON
        )

        let client = makeClient()
        let params = CreateConversationParams(agentName: "SupportBot", title: "Help with order")
        let conv = try await client.agents.createConversation(params)

        XCTAssertEqual(conv.id, "conv-123")
        XCTAssertEqual(conv.agent_name, "SupportBot")
        XCTAssertEqual(MockURLProtocol.lastRequest?.httpMethod, "POST")
    }

    func testCreateConversationRequestPath() async throws {
        let convJSON: [String: Any] = ["id": "conv-456", "agent_name": "Bot"]
        MockURLProtocol.mockJSONObject(
            path: "/api/apps/\(appId)/agents/conversations",
            object: convJSON
        )

        let client = makeClient()
        _ = try await client.agents.createConversation(CreateConversationParams(agentName: "Bot"))

        let path = MockURLProtocol.lastRequest?.url?.path ?? ""
        XCTAssertTrue(path.hasSuffix("/agents/conversations"), "Unexpected path: \(path)")
    }

    // MARK: - getConversation

    func testGetConversation() async throws {
        let convJSON: [String: Any] = [
            "id": "conv-789",
            "agent_name": "QueryBot",
            "status": "completed",
            "messages": [
                ["id": "msg-1", "role": "user", "content": "Hello", "created_at": "2024-01-01T00:00:01Z"],
                ["id": "msg-2", "role": "assistant", "content": "Hi there!", "created_at": "2024-01-01T00:00:02Z"]
            ]
        ]
        MockURLProtocol.mockJSONObject(
            path: "/api/apps/\(appId)/agents/conversations/conv-789",
            object: convJSON
        )

        let client = makeClient()
        let conv = try await client.agents.getConversation(id: "conv-789")

        XCTAssertEqual(conv.id, "conv-789")
        XCTAssertEqual(conv.messages?.count, 2)
        XCTAssertEqual(conv.messages?[0].role, "user")
        XCTAssertEqual(conv.messages?[1].content, "Hi there!")
    }

    // MARK: - getConversations (listConversations)

    func testGetConversations() async throws {
        let convsJSON: [[String: Any]] = [
            ["id": "c1", "agent_name": "BotA"],
            ["id": "c2", "agent_name": "BotB"]
        ]
        MockURLProtocol.mockJSONArray(
            path: "/api/apps/\(appId)/agents/conversations",
            array: convsJSON
        )

        let client = makeClient()
        let convs = try await client.agents.getConversations()

        XCTAssertEqual(convs.count, 2)
        XCTAssertEqual(convs[0].id, "c1")
        XCTAssertEqual(convs[1].agent_name, "BotB")
    }

    // MARK: - addMessage

    func testAddMessage() async throws {
        let msgJSON: [String: Any] = [
            "id": "msg-new",
            "role": "user",
            "content": "Tell me about Base44",
            "created_at": "2024-01-01T12:00:00Z"
        ]
        MockURLProtocol.mockJSONObject(
            path: "/api/apps/\(appId)/agents/conversations/v2/conv-123/messages",
            object: msgJSON
        )

        let client = makeClient()
        let conv = try JSONDecoder().decode(AgentConversation.self, from: "{\"id\":\"conv-123\",\"agent_name\":\"TestBot\"}".data(using: .utf8)!)
        let message = try JSONDecoder().decode(AgentMessage.self, from: "{\"id\":null,\"role\":\"user\",\"content\":\"Tell me about Base44\"}".data(using: .utf8)!)
        let result = try await client.agents.addMessage(conversation: conv, message: message)

        XCTAssertEqual(result.id, "msg-new")
        XCTAssertEqual(result.role, "user")
        XCTAssertEqual(MockURLProtocol.lastRequest?.httpMethod, "POST")
    }

    func testAddMessageRequestPath() async throws {
        let msgJSON: [String: Any] = ["id": "msg-1", "role": "user", "content": "Hi"]
        MockURLProtocol.mockJSONObject(
            path: "/api/apps/\(appId)/agents/conversations/v2/test-conv/messages",
            object: msgJSON
        )

        let client = makeClient()
        let conv = try JSONDecoder().decode(AgentConversation.self, from: "{\"id\":\"test-conv\"}".data(using: .utf8)!)
        let msg = try JSONDecoder().decode(AgentMessage.self, from: "{\"id\":null,\"role\":\"user\",\"content\":\"Hi\"}".data(using: .utf8)!)
        _ = try await client.agents.addMessage(conversation: conv, message: msg)

        let path = MockURLProtocol.lastRequest?.url?.path ?? ""
        XCTAssertTrue(path.contains("/conversations/v2/test-conv/messages"), "Unexpected path: \(path)")
    }

    // MARK: - sendMessage (with polling)

    func testSendMessagePolls() async throws {
        // Register handler for posting a message
        let msgJSON = "{\"id\":\"msg-user\",\"role\":\"user\",\"content\":\"Q\"}".data(using: .utf8)!
        MockURLProtocol.mockRaw(
            path: "/api/apps/\(appId)/agents/conversations/v2/poll-conv/messages",
            statusCode: 200,
            data: msgJSON
        )

        // Register a conversation that already has an assistant reply (simulates completion)
        let completedConvJSON = """
        {
            "id": "poll-conv",
            "agent_name": "Bot",
            "status": "completed",
            "messages": [
                {"id": "msg-1", "role": "user", "content": "Q"},
                {"id": "msg-2", "role": "assistant", "content": "A"}
            ]
        }
        """.data(using: .utf8)!
        MockURLProtocol.mockRaw(
            path: "/api/apps/\(appId)/agents/conversations/poll-conv",
            statusCode: 200,
            data: completedConvJSON
        )

        let client = makeClient()
        let convData = "{\"id\":\"poll-conv\",\"agent_name\":\"Bot\"}".data(using: .utf8)!
        let conv = try JSONDecoder().decode(AgentConversation.self, from: convData)
        let result = try await client.agents.sendMessage(conversation: conv, content: "Q", pollInterval: 0.01, maxAttempts: 5)

        XCTAssertEqual(result.messages?.count, 2, "Expected 2 messages after polling")
        let lastMsg = result.messages?.last
        XCTAssertEqual(lastMsg?.role, "assistant")
        XCTAssertEqual(lastMsg?.content, "A")
    }
}

// MARK: - Model tests

final class AgentModelTests: XCTestCase {

    func testAgentConversationDecoding() throws {
        let json = """
        {
            "id": "conv-1",
            "agent_name": "MyBot",
            "title": "Test Session",
            "status": "active",
            "messages": [
                {"id": "m1", "role": "user", "content": "Hello", "created_at": "2024-01-01T00:00:00Z"}
            ],
            "created_at": "2024-01-01T00:00:00Z",
            "updated_at": "2024-01-01T00:00:01Z"
        }
        """.data(using: .utf8)!

        let conv = try JSONDecoder().decode(AgentConversation.self, from: json)
        XCTAssertEqual(conv.id, "conv-1")
        XCTAssertEqual(conv.agent_name, "MyBot")
        XCTAssertEqual(conv.status, "active")
        XCTAssertEqual(conv.messages?.count, 1)
        XCTAssertEqual(conv.messages?[0].role, "user")
        XCTAssertEqual(conv.messages?[0].content, "Hello")
    }

    func testCreateConversationParamsEncoding() throws {
        let params = CreateConversationParams(agentName: "TestBot", title: "My Session")
        let data = try JSONEncoder().encode(params)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(obj?["agent_name"] as? String, "TestBot")
        XCTAssertEqual(obj?["title"] as? String, "My Session")
    }
}
