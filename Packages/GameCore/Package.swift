// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "GameCore",
    // macOS only so CI can run the tests on the host with `swift test`.
    platforms: [.iOS("27.0"), .macOS("27.0")],
    products: [
        .library(name: "GameCore", targets: ["GameCore"])
    ],
    targets: [
        .target(name: "GameCore")
    ],
    swiftLanguageModes: [.v6]
)
