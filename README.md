# Base44 Swift SDK

A Swift Package Manager SDK for [Base44](https://base44.app) — full parity with the JavaScript SDK for iOS, macOS, tvOS, watchOS, and Linux targets.

## Requirements

- Swift 5.9+
- iOS 15+ / macOS 12+ / tvOS 15+ / watchOS 8+
- Linux: Swift 5.9+ with FoundationNetworking

## Installation

### Swift Package Manager

Add to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/base44/swift-sdk.git", from: "0.1.0"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["Base44"]),
]
```

Or in Xcode: **File → Add Packages…** and enter the repo URL.

## Quick Start

```swift
import Base44

// Create a client
let base44 = createClient(config: CreateClientConfig(appId: "your-app-id"))

// Authenticate
let loginResponse = try await base44.auth.loginViaEmailPassword(
    email: "user@example.com",
    password: "password"
)
// Token is set automatically after login

// List entities
let products = try await base44.entities.Products.list()

// Create an entity
let newProduct = try await base44.entities.Products.create([
    "name": "Widget",
    "price": 9.99
])

// Filter entities
let activeProducts = try await base44.entities.Products.filter(
    ["status": "active"],
    sort: "-created_at",
    limit: 20
)
```

## Token Storage

The SDK stores the JWT token in-memory on all platforms. For persistent storage across app launches, save the token to the Keychain after login:

```swift
let loginResponse = try await base44.auth.loginViaEmailPassword(email: "...", password: "...")

// Save to Keychain (using your preferred Keychain wrapper)
Keychain.save(key: "base44_token", value: loginResponse.access_token)

// On next app launch, restore:
if let saved = Keychain.load(key: "base44_token") {
    base44.setToken(saved)
}
```

## Modules

### `entities`

Dynamic access to all entity types in your app.

| Method | Description |
|--------|-------------|
| `list(sort:limit:skip:fields:)` | List entities with optional pagination |
| `filter(_:sort:limit:skip:fields:)` | Filter by query object |
| `get(id:)` | Get by ID |
| `create(_:)` | Create a new entity |
| `update(id:_:)` | Update by ID |
| `delete(id:)` | Delete by ID |
| `deleteMany(_:)` | Delete matching entities |
| `bulkCreate(_:)` | Create multiple at once |
| `importEntities(fileData:filename:mimeType:)` | Import from CSV/Excel |

### `auth`

| Method | Description |
|--------|-------------|
| `me()` | Get current user |
| `updateMe(_:)` | Update current user |
| `loginViaEmailPassword(email:password:)` | Email/password login |
| `loginViaOtp(email:)` | Send OTP |
| `verifyOtp(email:otpCode:)` | Verify OTP |
| `register(email:password:)` | Create account |
| `resetPassword(email:)` | Request password reset |
| `resetPasswordConfirm(resetToken:newPassword:)` | Confirm reset |
| `changePassword(userId:currentPassword:newPassword:)` | Change password |
| `isAuthenticated()` | Check if token is valid |
| `setToken(_:)` | Set auth token |
| `logout()` | Clear auth token |

### `functions`

```swift
let result = try await base44.functions.invoke("myFunction", data: ["key": "value"])
```

### `integrations`

```swift
// LLM
let response = try await base44.integrations.core.invokeLLM(prompt: "What is 2+2?")

// Image generation
let image = try await base44.integrations.core.generateImage(prompt: "A sunset over mountains")

// File upload
let uploaded = try await base44.integrations.core.uploadFile(
    fileData: imageData,
    filename: "photo.jpg",
    mimeType: "image/jpeg"
)

// Email
try await base44.integrations.core.sendEmail(
    to: "user@example.com",
    subject: "Welcome!",
    body: "Thanks for joining."
)

// Generic invocation
let result = try await base44.integrations.invoke(
    package: "MyPackage",
    endpoint: "MyEndpoint",
    data: ["param": "value"]
)
```

### `agents`

```swift
// Create a conversation
let conversation = try await base44.agents.createConversation(
    CreateConversationParams(agentName: "SupportBot")
)

// Send a message and poll for reply
let updated = try await base44.agents.sendMessage(
    conversation: conversation,
    content: "Help me with my order"
)

// Or add a message and handle response manually
let msg = AgentMessage(id: nil, role: "user", content: "Hello", created_at: nil)
_ = try await base44.agents.addMessage(conversation: conversation, message: msg)
```

### `appLogs`

```swift
let logs = try await base44.appLogs.list(limit: 100)
```

### `users`

```swift
let users = try await base44.users.list()
try await base44.users.inviteUser(email: "new@example.com", role: "member")
```

### `asServiceRole`

Requires a `serviceToken` when creating the client:

```swift
let base44 = createClient(config: CreateClientConfig(
    appId: "my-app-id",
    serviceToken: "service-role-token"
))

let allOrders = try await base44.asServiceRole.entities.Orders.list()
```

## Error Handling

All async methods throw `Base44Error` on API errors:

```swift
do {
    let item = try await base44.entities.Products.get(id: "invalid-id")
} catch let error as Base44Error {
    print("Status:", error.status)    // 404
    print("Message:", error.message)  // "Not found"
    print("Code:", error.code ?? "")  // "NOT_FOUND"
}
```

## Realtime / WebSocket

Realtime entity subscriptions are not yet available in the Swift SDK. Use polling or check the JS SDK for reference. This feature is planned for a future release.

## License

MIT
