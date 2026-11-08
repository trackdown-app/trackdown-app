// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "GameCore",
    platforms: [.iOS("27.0")],
    products: [
        .library(name: "GameCore", targets: ["GameCore"])
    ],
    targets: [
        .target(name: "GameCore")
    ],
    swiftLanguageModes: [.v6]
)
