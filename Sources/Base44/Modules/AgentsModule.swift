import Foundation

// MARK: - Agents Module

/// Provides conversation and messaging operations for AI agents in your Base44 app.
///
/// ```swift
/// // Create a conversation
/// let conv = try await base44.agents.createConversation(CreateConversationParams(agentName: "MyBot"))
///
/// // Send a message and poll for the response
/// let message = AgentMessage(role: "user", content: "Hello!")
/// let response = try await base44.agents.addMessage(conversation: conv, message: message)
/// ```
public struct AgentsModule: Sendable {
    private let http: HTTPClient
    private let appId: String

    init(http: HTTPClient, appId: String) {
        self.http = http
        self.appId = appId
    }

    private var basePath: String { "/apps/\(appId)/agents" }

    // MARK: - Conversations

    /// Returns all conversations for the current user.
    public func getConversations() async throws -> [AgentConversation] {
        let data = try await http.get(path: "\(basePath)/conversations")
        return try JSONDecoder().decode([AgentConversation].self, from: data)
    }

    /// Returns a single conversation by ID.
    public func getConversation(id: String) async throws -> AgentConversation {
        let data = try await http.get(path: "\(basePath)/conversations/\(id)")
        return try JSONDecoder().decode(AgentConversation.self, from: data)
    }

    /// Lists conversations with optional filter params.
    public func listConversations(filter: JSONObject = [:]) async throws -> [AgentConversation] {
        var items = [URLQueryItem]()
        for (k, v) in filter {
            items.append(URLQueryItem(name: k, value: "\(v)"))
        }
        let data = try await http.get(path: "\(basePath)/conversations", queryItems: items.isEmpty ? nil : items)
        return try JSONDecoder().decode([AgentConversation].self, from: data)
    }

    /// Creates a new conversation.
    public func createConversation(_ params: CreateConversationParams = CreateConversationParams()) async throws -> AgentConversation {
        let bodyData = try JSONEncoder().encode(params)
        let data = try await http.post(path: "\(basePath)/conversations", body: RawJSONEncodable(data: bodyData))
        return try JSONDecoder().decode(AgentConversation.self, from: data)
    }

    // MARK: - Messages

    /// Adds a message to a conversation and returns the updated message (may trigger agent processing).
    public func addMessage(conversation: AgentConversation, message: AgentMessage) async throws -> AgentMessage {
        let bodyData = try JSONEncoder().encode(message)
        let data = try await http.post(
            path: "\(basePath)/conversations/v2/\(conversation.id)/messages",
            body: RawJSONEncodable(data: bodyData)
        )
        return try JSONDecoder().decode(AgentMessage.self, from: data)
    }

    /// Sends a user message and polls for the agent's response.
    /// - Parameters:
    ///   - conversation: The conversation to send the message to.
    ///   - content: The user's message text.
    ///   - pollInterval: Seconds between polls (default 1.5).
    ///   - maxAttempts: Maximum polling attempts (default 30, ~45 seconds).
    /// - Returns: The agent's reply message.
    public func sendMessage(
        conversation: AgentConversation,
        content: String,
        pollInterval: TimeInterval = 1.5,
        maxAttempts: Int = 30
    ) async throws -> AgentConversation {
        let message = AgentMessage(id: nil, role: "user", content: content, created_at: nil)
        _ = try await addMessage(conversation: conversation, message: message)

        // Poll for the updated conversation (agent processing is async)
        for _ in 0..<maxAttempts {
            try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
            let updated = try await getConversation(id: conversation.id)
            // Check if the last message is from the agent
            if let lastMessage = updated.messages?.last, lastMessage.role != "user" {
                return updated
            }
        }
        // Return whatever state the conversation is in
        return try await getConversation(id: conversation.id)
    }
}
