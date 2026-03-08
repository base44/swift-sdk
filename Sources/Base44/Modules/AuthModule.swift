import Foundation

// MARK: - Auth Module

/// Provides authentication operations for your Base44 app.
///
/// ```swift
/// let response = try await base44.auth.loginViaEmailPassword(email: "user@example.com", password: "secret")
/// base44.setToken(response.access_token)
/// let me = try await base44.auth.me()
/// ```
public struct AuthModule: Sendable {
    private let http: HTTPClient
    private let functionsHTTP: HTTPClient
    private let appId: String
    let appBaseUrl: String
    let serverUrl: String

    // Token storage: in-memory (caller can persist to Keychain)
    private let tokenStore: TokenStore

    init(http: HTTPClient, functionsHTTP: HTTPClient, appId: String, appBaseUrl: String, serverUrl: String, tokenStore: TokenStore) {
        self.http = http
        self.functionsHTTP = functionsHTTP
        self.appId = appId
        self.appBaseUrl = appBaseUrl
        self.serverUrl = serverUrl
        self.tokenStore = tokenStore
    }

    // MARK: - Me

    /// Returns the currently authenticated user.
    public func me() async throws -> JSONObject {
        let data = try await http.get(path: "/apps/\(appId)/entities/User/me")
        return (try? JSONSerialization.jsonObject(with: data) as? JSONObject) ?? [:]
    }

    /// Updates the current user's profile.
    public func updateMe(_ body: JSONObject) async throws -> JSONObject {
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let data = try await http.put(path: "/apps/\(appId)/entities/User/me", body: RawJSONEncodable(data: bodyData))
        return (try? JSONSerialization.jsonObject(with: data) as? JSONObject) ?? [:]
    }

    // MARK: - Token management

    /// Sets the authentication token used for all subsequent requests.
    /// - Parameters:
    ///   - token: JWT bearer token.
    ///   - saveToStore: Whether to persist the token in the in-memory store (default true). Callers can write to Keychain separately.
    public func setToken(_ token: String, saveToStore: Bool = true) {
        guard !token.isEmpty else { return }
        http.setToken(token)
        functionsHTTP.setToken(token)
        if saveToStore {
            tokenStore.token = token
        }
    }

    /// Removes the current authentication token.
    public func logout() {
        http.clearToken()
        functionsHTTP.clearToken()
        tokenStore.token = nil
    }

    /// Returns `true` if the current token is valid (calls `me()` and checks for success).
    public func isAuthenticated() async -> Bool {
        do {
            _ = try await me()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Login / Register

    /// Authenticates with email and password.
    /// - Returns: `LoginResponse` containing the access token and user object.
    @discardableResult
    public func loginViaEmailPassword(email: String, password: String, turnstileToken: String? = nil) async throws -> LoginResponse {
        var body: JSONObject = ["email": email, "password": password]
        if let t = turnstileToken { body["turnstile_token"] = t }
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let data = try await http.post(path: "/apps/\(appId)/auth/login", body: RawJSONEncodable(data: bodyData))
        let response = try JSONDecoder().decode(LoginResponse.self, from: data)
        setToken(response.access_token)
        return response
    }

    /// Registers a new user account.
    public func register(email: String, password: String, turnstileToken: String? = nil, referralCode: String? = nil) async throws -> JSONObject {
        var body: JSONObject = ["email": email, "password": password]
        if let t = turnstileToken { body["turnstile_token"] = t }
        if let r = referralCode { body["referral_code"] = r }
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let data = try await http.post(path: "/apps/\(appId)/auth/register", body: RawJSONEncodable(data: bodyData))
        return (try? JSONSerialization.jsonObject(with: data) as? JSONObject) ?? [:]
    }

    // MARK: - OTP

    /// Sends an OTP login code to the user's email.
    public func loginViaOtp(email: String) async throws -> JSONObject {
        let body: JSONObject = ["email": email]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let data = try await http.post(path: "/apps/\(appId)/auth/resend-otp", body: RawJSONEncodable(data: bodyData))
        return (try? JSONSerialization.jsonObject(with: data) as? JSONObject) ?? [:]
    }

    /// Verifies an OTP code.
    @discardableResult
    public func verifyOtp(email: String, otpCode: String) async throws -> LoginResponse {
        let body: JSONObject = ["email": email, "otp_code": otpCode]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let data = try await http.post(path: "/apps/\(appId)/auth/verify-otp", body: RawJSONEncodable(data: bodyData))
        let response = try JSONDecoder().decode(LoginResponse.self, from: data)
        setToken(response.access_token)
        return response
    }

    /// Resends an OTP code.
    public func resendOtp(email: String) async throws {
        let body: JSONObject = ["email": email]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        _ = try await http.post(path: "/apps/\(appId)/auth/resend-otp", body: RawJSONEncodable(data: bodyData))
    }

    // MARK: - Password reset

    /// Requests a password reset email.
    public func resetPassword(email: String) async throws {
        let body: JSONObject = ["email": email]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        _ = try await http.post(path: "/apps/\(appId)/auth/reset-password-request", body: RawJSONEncodable(data: bodyData))
    }

    /// Completes a password reset using the token from the reset email.
    public func resetPasswordConfirm(resetToken: String, newPassword: String) async throws {
        let body: JSONObject = ["reset_token": resetToken, "new_password": newPassword]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        _ = try await http.post(path: "/apps/\(appId)/auth/reset-password", body: RawJSONEncodable(data: bodyData))
    }

    /// Changes the authenticated user's password.
    public func changePassword(userId: String, currentPassword: String, newPassword: String) async throws {
        let body: JSONObject = ["user_id": userId, "current_password": currentPassword, "new_password": newPassword]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        _ = try await http.post(path: "/apps/\(appId)/auth/change-password", body: RawJSONEncodable(data: bodyData))
    }
}

// MARK: - Token Store

/// Thread-safe in-memory token store.
/// Callers should persist to Keychain for durable storage.
final class TokenStore: @unchecked Sendable {
    private let lock = NSLock()
    private var _token: String?

    var token: String? {
        get { lock.lock(); defer { lock.unlock() }; return _token }
        set { lock.lock(); defer { lock.unlock() }; _token = newValue }
    }
}
