// swift-tools-version: 6.2
import PackageDescription

// CI sets TRACKDOWN_WARNINGS_AS_ERRORS=YES. Applied per target so remote dependencies, which
// Xcode builds with warnings suppressed, are not affected.
let strictWarnings: [SwiftSetting] =
    Context.environment["TRACKDOWN_WARNINGS_AS_ERRORS"] == "YES" ? [.treatAllWarnings(as: .error)] : []

let package = Package(
    name: "DesignSystem",
    defaultLocalization: "en",
    // macOS only so CI can run the tests on the host with `swift test`.
    platforms: [.iOS("27.0"), .macOS("27.0")],
    products: [
        .library(name: "DesignSystem", targets: ["DesignSystem"])
    ],
    dependencies: [
        .package(path: "../GameCore")
    ],
    targets: [
        .target(
            name: "DesignSystem",
            dependencies: [
                .product(name: "GameCore", package: "GameCore")
            ],
            resources: [
                .process("Resources/Colors.xcassets"),
                .process("Resources/Images.xcassets"),
                .process("Resources/Localizable.xcstrings"),
                // Copied as a folder so the fonts and their OFL license ship together.
                .copy("Resources/Fonts"),
            ],
            swiftSettings: strictWarnings
        ),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"], swiftSettings: strictWarnings),
    ],
    swiftLanguageModes: [.v6]
)
