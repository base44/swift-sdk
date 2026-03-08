import Foundation

// MARK: - Base44 Error

/// An error returned by the Base44 API or SDK.
public struct Base44Error: Error, LocalizedError {
    /// HTTP status code.
    public let status: Int
    /// Machine-readable error code from the API.
    public let code: String?
    /// Human-readable error message.
    public let message: String
    /// Raw response data from the server.
    public let data: [String: Any]?

    public var errorDescription: String? { message }

    public init(status: Int, code: String? = nil, message: String, data: [String: Any]? = nil) {
        self.status = status
        self.code = code
        self.message = message
        self.data = data
    }
}

// MARK: - JSON helpers

public typealias JSONObject = [String: Any]
public typealias JSONArray = [[String: Any]]

// MARK: - Delete results

public struct DeleteResult: Codable {
    public let id: String?
    public let deleted: Bool?
}

public struct DeleteManyResult: Codable {
    public let deleted: Int?
}

public struct ImportResult: Codable {
    public let created: Int?
    public let updated: Int?
    public let errors: [String]?
}

// MARK: - Auth types

public struct LoginResponse: Codable {
    public let access_token: String
    public let user: JSONValue?
}

public struct MeResponse: Codable {
    public let id: String?
    public let email: String?
    // Additional user fields decoded as dynamic JSON
    private let extra: [String: JSONValue]

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        var id: String?
        var email: String?
        var extra = [String: JSONValue]()
        for key in container.allKeys {
            switch key.stringValue {
            case "id":   id = try? container.decode(String.self, forKey: key)
            case "email": email = try? container.decode(String.self, forKey: key)
            default:
                if let v = try? container.decode(JSONValue.self, forKey: key) {
                    extra[key.stringValue] = v
                }
            }
        }
        self.id = id
        self.email = email
        self.extra = extra
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        if let id = id { try container.encode(id, forKey: DynamicCodingKey(stringValue: "id")!) }
        if let email = email { try container.encode(email, forKey: DynamicCodingKey(stringValue: "email")!) }
        for (k, v) in extra { try container.encode(v, forKey: DynamicCodingKey(stringValue: k)!) }
    }
}

// MARK: - Dynamic JSON

/// Represents any JSON value (string, number, bool, null, array, object).
public indirect enum JSONValue: Codable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(String.self) { self = .string(v); return }
        if let v = try? container.decode(Bool.self) { self = .bool(v); return }
        if let v = try? container.decode(Int.self) { self = .int(v); return }
        if let v = try? container.decode(Double.self) { self = .double(v); return }
        if let v = try? container.decode([JSONValue].self) { self = .array(v); return }
        if let v = try? container.decode([String: JSONValue].self) { self = .object(v); return }
        if container.decodeNil() { self = .null; return }
        throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown JSON value"))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .null: try container.encodeNil()
        case .array(let v): try container.encode(v)
        case .object(let v): try container.encode(v)
        }
    }
}

// MARK: - Coding key helpers

public struct DynamicCodingKey: CodingKey {
    public var stringValue: String
    public var intValue: Int?
    public init?(stringValue: String) { self.stringValue = stringValue }
    public init?(intValue: Int) { self.intValue = intValue; self.stringValue = "\(intValue)" }
}

// MARK: - Agent types

public struct AgentConversation: Codable, Sendable {
    public let id: String
    public let messages: [AgentMessage]?
    public let agent_name: String?
    public let created_at: String?
    public let updated_at: String?
}

public struct AgentMessage: Codable, Sendable {
    public let id: String?
    public let role: String?
    public let content: String?
    public let created_at: String?
}

public struct CreateConversationParams: Codable, Sendable {
    public let agent_name: String?
    public let title: String?
    public let metadata: [String: JSONValue]?

    public init(agentName: String? = nil, title: String? = nil, metadata: [String: JSONValue]? = nil) {
        self.agent_name = agentName
        self.title = title
        self.metadata = metadata
    }
}
