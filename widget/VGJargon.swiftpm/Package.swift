// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VGJargon",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "VGJargon", targets: ["VGJargon"])
    ],
    targets: [
        .executableTarget(
            name: "VGJargon",
            path: "Sources",
            resources: [.process("Resources")]
        )
    ]
)
