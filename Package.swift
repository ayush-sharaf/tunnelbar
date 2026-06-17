// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Tunnelbar",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Tunnelbar",
            path: "Sources/Tunnelbar"
        )
    ]
)
