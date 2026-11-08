// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TrackdownAPI",
    // macOS only so CI can run the tests on the host with `swift test`.
    platforms: [.iOS("27.0"), .macOS("27.0")],
    products: [
        .library(name: "TrackdownAPI", targets: ["TrackdownAPI"])
    ],
    targets: [
        .target(name: "TrackdownAPI"),
        .testTarget(name: "TrackdownAPITests", dependencies: ["TrackdownAPI"]),
    ],
    swiftLanguageModes: [.v6]
)
