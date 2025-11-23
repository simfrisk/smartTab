// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SmartTab",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "SmartTab",
            targets: ["SmartTab"]
        )
    ],
    targets: [
        .executableTarget(
            name: "SmartTab",
            dependencies: []
        )
    ]
)

