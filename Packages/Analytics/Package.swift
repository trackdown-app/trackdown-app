// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Analytics",
    platforms: [.iOS("27.0")],
    products: [
        .library(name: "Analytics", targets: ["Analytics"])
    ],
    targets: [
        .target(name: "Analytics"),
        .testTarget(name: "AnalyticsTests", dependencies: ["Analytics"]),
    ],
    swiftLanguageModes: [.v6]
)
