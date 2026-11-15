// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Sift",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "SiftCore", targets: ["SiftCore"]),
        .executable(name: "Sift", targets: ["SiftApp"])
    ],
    targets: [
        .target(name: "SiftCore", path: "SiftSources/SiftCore"),
        .executableTarget(name: "SiftApp", dependencies: ["SiftCore"], path: "SiftSources/SiftApp"),
        .testTarget(name: "SiftCoreTests", dependencies: ["SiftCore"], path: "Tests/SiftCoreTests")
    ],
    swiftLanguageModes: [.v6]
)
