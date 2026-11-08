// swift-tools-version: 6.2
import PackageDescription

// CI sets TRACKDOWN_WARNINGS_AS_ERRORS=YES. Applied per target so remote dependencies, which
// Xcode builds with warnings suppressed, are not affected.
let strictWarnings: [SwiftSetting] =
    Context.environment["TRACKDOWN_WARNINGS_AS_ERRORS"] == "YES" ? [.treatAllWarnings(as: .error)] : []

let package = Package(
    name: "GameScreens",
    defaultLocalization: "en",
    // macOS only so CI can run the tests on the host with `swift test`.
    platforms: [.iOS("27.0"), .macOS("27.0")],
    products: [
        .library(name: "GameScreens", targets: ["GameScreens"])
    ],
    dependencies: [
        .package(path: "../GameCore"),
        .package(path: "../DesignSystem"),
        .package(path: "../Analytics"),
    ],
    targets: [
        .target(
            name: "GameScreens",
            dependencies: [
                .product(name: "GameCore", package: "GameCore"),
                .product(name: "DesignSystem", package: "DesignSystem"),
                .product(name: "Analytics", package: "Analytics"),
            ],
            resources: [
                .process("Resources/Localizable.xcstrings")
            ],
            swiftSettings: strictWarnings
        ),
        .testTarget(
            name: "GameScreensTests",
            dependencies: [
                "GameScreens",
                .product(name: "GameCore", package: "GameCore"),
            ],
            swiftSettings: strictWarnings
        ),
    ],
    swiftLanguageModes: [.v6]
)
