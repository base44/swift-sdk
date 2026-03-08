// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Base44",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8),
    ],
    products: [
        .library(
            name: "Base44",
            targets: ["Base44"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Base44",
            dependencies: [],
            path: "Sources/Base44"
        ),
        .testTarget(
            name: "Base44Tests",
            dependencies: ["Base44"],
            path: "Tests/Base44Tests"
        ),
    ]
)
