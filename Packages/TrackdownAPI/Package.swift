// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TrackdownAPI",
    platforms: [.iOS("27.0")],
    products: [
        .library(name: "TrackdownAPI", targets: ["TrackdownAPI"])
    ],
    targets: [
        .target(name: "TrackdownAPI"),
        .testTarget(name: "TrackdownAPITests", dependencies: ["TrackdownAPI"]),
    ],
    swiftLanguageModes: [.v6]
)
