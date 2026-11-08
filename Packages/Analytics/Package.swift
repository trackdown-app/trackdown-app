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
    targets: [
        .target(name: "Analytics", swiftSettings: strictWarnings),
        .testTarget(name: "AnalyticsTests", dependencies: ["Analytics"], swiftSettings: strictWarnings),
    ],
    swiftLanguageModes: [.v6]
)
