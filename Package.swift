// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "TunnelManager",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "TunnelManager",
            path: "Sources/TunnelManager"
        )
    ]
)
