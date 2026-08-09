// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ctdoshot",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "ctdoshot", targets: ["ctdoshot"]),
        .library(name: "ctdoshotCore", targets: ["ctdoshotCore"]),
    ],
    targets: [
        .target(name: "ctdoshotCore", path: "Sources/ctdoshotCore"),
        .executableTarget(
            name: "ctdoshot",
            dependencies: ["ctdoshotCore"],
            path: "Sources/ctdoshotApp"
        ),
        .testTarget(
            name: "ctdoshotTests",
            dependencies: ["ctdoshotCore"],
            path: "Tests/ctdoshotTests"
        ),
    ]
)
