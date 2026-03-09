import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Client Configuration

/// Configuration for creating a Base44 client.
public struct CreateClientConfig: @unchecked Sendable {
    /// Base44 server URL. Defaults to `https://base44.app`.
    public let serverUrl: String
    /// Your Base44 application ID.
    public let appId: String
    /// Optional user authentication token.
    public let token: String?
    /// Optional service-role token for elevated permissions.
    public let serviceToken: String?
    /// Optional app base URL (for SSO redirect).
    public let appBaseUrl: String?
    /// Optional functions version header value.
    public let functionsVersion: String?
    /// Additional HTTP headers.
    public let headers: [String: String]
    /// URLSession to use for all requests. Defaults to `.shared`. Inject a custom session for testing.
    public let urlSession: URLSession

    public init(
        appId: String,
        serverUrl: String = "https://base44.app",
        token: String? = nil,
        serviceToken: String? = nil,
        appBaseUrl: String? = nil,
        functionsVersion: String? = nil,
        headers: [String: String] = [:],
        urlSession: URLSession = .shared
    ) {
        self.appId = appId
        self.serverUrl = serverUrl
        self.token = token
        self.serviceToken = serviceToken
        self.appBaseUrl = appBaseUrl
        self.functionsVersion = functionsVersion
        self.headers = headers
        self.urlSession = urlSession
    }
}

// MARK: - Base44 Client

/// The main Base44 SDK client.
///
/// Create a client using `createClient(config:)`:
/// ```swift
/// import Base44
///
/// let base44 = createClient(config: CreateClientConfig(appId: "my-app-id"))
///
/// // Use entities
/// let products = try await base44.entities.Products.list()
///
/// // Authenticate
/// let response = try await base44.auth.loginViaEmailPassword(email: "user@example.com", password: "password")
/// base44.setToken(response.access_token)
///
/// // Use service role
/// let allOrders = try await base44.asServiceRole.entities.Orders.list()
/// ```
public final class Base44Client: @unchecked Sendable {

    // MARK: User-scoped modules

    /// Access and manipulate entities in your app.
    public let entities: EntitiesModule
    /// Authentication operations.
    public let auth: AuthModule
    /// Invoke backend functions.
    public let functions: FunctionsModule
    /// Access built-in integrations (AI, storage, email).
    public let integrations: IntegrationsModule
    /// Create and manage AI agent conversations.
    public let agents: AgentsModule
    /// View application logs.
    public let appLogs: AppLogsModule
    /// Manage app users.
    public let users: UsersModule

    // MARK: Private

    private let http: HTTPClient
    private let functionsHTTP: HTTPClient
    private let serviceHTTP: HTTPClient?
    private let serviceFunctionsHTTP: HTTPClient?
    private let appId: String
    private let serverUrl: String
    private let serviceToken: String?

    // MARK: Init

    init(
        http: HTTPClient,
        functionsHTTP: HTTPClient,
        serviceHTTP: HTTPClient?,
        serviceFunctionsHTTP: HTTPClient?,
        appId: String,
        serverUrl: String,
        appBaseUrl: String,
        serviceToken: String?
    ) {
        self.http = http
        self.functionsHTTP = functionsHTTP
        self.serviceHTTP = serviceHTTP
        self.serviceFunctionsHTTP = serviceFunctionsHTTP
        self.appId = appId
        self.serverUrl = serverUrl
        self.serviceToken = serviceToken

        let tokenStore = TokenStore()

        self.entities = EntitiesModule(http: http, appId: appId)
        self.auth = AuthModule(
            http: http,
            functionsHTTP: functionsHTTP,
            appId: appId,
            appBaseUrl: appBaseUrl,
            serverUrl: serverUrl,
            tokenStore: tokenStore
        )
        self.functions = FunctionsModule(http: functionsHTTP, appId: appId)
        self.integrations = IntegrationsModule(http: http, appId: appId)
        self.agents = AgentsModule(http: http, appId: appId)
        self.appLogs = AppLogsModule(http: http, appId: appId)
        self.users = UsersModule(http: http, appId: appId)
    }

    // MARK: - Token

    /// Updates the authentication token used by all user-scoped modules.
    public func setToken(_ token: String) {
        auth.setToken(token)
    }

    // MARK: - Service role

    /// Provides access to service-role modules with elevated permissions.
    ///
    /// Requires `serviceToken` to be set during client creation.
    public var asServiceRole: ServiceRoleClient {
        guard let serviceHTTP = serviceHTTP, let serviceFunctionsHTTP = serviceFunctionsHTTP else {
            fatalError("Service token is required to use asServiceRole. Provide a serviceToken in CreateClientConfig.")
        }
        return ServiceRoleClient(
            http: serviceHTTP,
            functionsHTTP: serviceFunctionsHTTP,
            appId: appId
        )
    }

    // MARK: - Config

    /// Returns the client's current configuration values.
    public func getConfig() -> (serverUrl: String, appId: String) {
        (serverUrl: serverUrl, appId: appId)
    }
}

// MARK: - Service Role Client

/// A client scoped to service-role (admin) permissions.
public struct ServiceRoleClient: Sendable {
    /// Access and manipulate entities with admin permissions.
    public let entities: EntitiesModule
    /// Invoke backend functions with admin permissions.
    public let functions: FunctionsModule
    /// Access integrations with admin permissions.
    public let integrations: IntegrationsModule
    /// Manage AI agent conversations with admin permissions.
    public let agents: AgentsModule
    /// View application logs with admin permissions.
    public let appLogs: AppLogsModule

    init(http: HTTPClient, functionsHTTP: HTTPClient, appId: String) {
        self.entities = EntitiesModule(http: http, appId: appId)
        self.functions = FunctionsModule(http: functionsHTTP, appId: appId)
        self.integrations = IntegrationsModule(http: http, appId: appId)
        self.agents = AgentsModule(http: http, appId: appId)
        self.appLogs = AppLogsModule(http: http, appId: appId)
    }
}

// MARK: - Factory function

/// Creates a Base44 client with the given configuration.
///
/// - Parameter config: Client configuration including `appId` and optional tokens.
/// - Returns: A configured `Base44Client` instance.
///
/// Example:
/// ```swift
/// let base44 = createClient(config: CreateClientConfig(appId: "my-app-id"))
/// ```
public func createClient(config: CreateClientConfig) -> Base44Client {
    let baseURL = "\(config.serverUrl)/api"
    var headers = config.headers
    headers["X-App-Id"] = config.appId

    var functionHeaders = headers
    if let v = config.functionsVersion {
        functionHeaders["Base44-Functions-Version"] = v
    }

    let http = HTTPClient(baseURL: baseURL, headers: headers, token: config.token, session: config.urlSession)
    let functionsHTTP = HTTPClient(baseURL: baseURL, headers: functionHeaders, token: config.token, session: config.urlSession)

    var serviceHTTP: HTTPClient?
    var serviceFunctionsHTTP: HTTPClient?
    if let st = config.serviceToken {
        serviceHTTP = HTTPClient(baseURL: baseURL, headers: headers, token: st, session: config.urlSession)
        serviceFunctionsHTTP = HTTPClient(baseURL: baseURL, headers: functionHeaders, token: st, session: config.urlSession)
    }

    return Base44Client(
        http: http,
        functionsHTTP: functionsHTTP,
        serviceHTTP: serviceHTTP,
        serviceFunctionsHTTP: serviceFunctionsHTTP,
        appId: config.appId,
        serverUrl: config.serverUrl,
        appBaseUrl: config.appBaseUrl ?? "",
        serviceToken: config.serviceToken
    )
}
