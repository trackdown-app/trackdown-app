// swift-tools-version: 6.2
import PackageDescription

// CI sets TRACKDOWN_WARNINGS_AS_ERRORS=YES. Applied per target so remote dependencies, which
// Xcode builds with warnings suppressed, are not affected.
let strictWarnings: [SwiftSetting] =
    Context.environment["TRACKDOWN_WARNINGS_AS_ERRORS"] == "YES" ? [.treatAllWarnings(as: .error)] : []

let package = Package(
    name: "Analytics",
    // macOS only so CI can run the tests on the host with `swift test`.
    platforms: [.iOS("27.0"), .macOS("27.0")],
    products: [
        .library(name: "Analytics", targets: ["Analytics"])
    ],
    dependencies: [
        .package(url: "https://github.com/PostHog/posthog-ios", from: "3.93.6")
    ],
    targets: [
        .target(
            name: "Analytics",
            dependencies: [
                .product(name: "PostHog", package: "posthog-ios")
            ],
            swiftSettings: strictWarnings
        ),
        .testTarget(
            name: "AnalyticsTests",
            dependencies: [
                "Analytics",
                .product(name: "PostHog", package: "posthog-ios"),
            ],
            swiftSettings: strictWarnings
        ),
    ],
    swiftLanguageModes: [.v6]
)
