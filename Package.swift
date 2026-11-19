// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Multitarefa",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Multitarefa",
            path: "Sources/Multitarefa"
        )
    ]
)
