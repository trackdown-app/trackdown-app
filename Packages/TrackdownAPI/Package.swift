// swift-tools-version: 6.2
import PackageDescription

// CI sets TRACKDOWN_WARNINGS_AS_ERRORS=YES. Applied per target so remote dependencies, which
// Xcode builds with warnings suppressed, are not affected.
let strictWarnings: [SwiftSetting] =
    Context.environment["TRACKDOWN_WARNINGS_AS_ERRORS"] == "YES" ? [.treatAllWarnings(as: .error)] : []

let package = Package(
    name: "TrackdownAPI",
    // macOS only so CI can run the tests on the host with `swift test`.
    platforms: [.iOS("27.0"), .macOS("27.0")],
    products: [
        .library(name: "TrackdownAPI", targets: ["TrackdownAPI"])
    ],
    dependencies: [
        .package(path: "../GameCore"),
        .package(url: "https://github.com/apple/swift-http-types", from: "1.8.0"),
        .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.14.4"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.13.4"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession", from: "1.4.0"),
    ],
    targets: [
        .target(
            name: "TrackdownAPI",
            dependencies: [
                .product(name: "GameCore", package: "GameCore"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
            ],
            swiftSettings: strictWarnings,
            // Generates `Client`, `Operations` and `Components` from
            // Sources/TrackdownAPI/openapi.json, a symlink to openapi/v1.json.
            plugins: [
                .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")
            ]
        ),
        .testTarget(
            name: "TrackdownAPITests",
            dependencies: [
                "TrackdownAPI",
                .product(name: "GameCore", package: "GameCore"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
            ],
            swiftSettings: strictWarnings
        ),
    ],
    swiftLanguageModes: [.v6]
)
