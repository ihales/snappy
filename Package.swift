// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Snappy",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Snappy", targets: ["Snappy"])
    ],
    targets: [
        .executableTarget(
            name: "Snappy",
            path: "Sources/Snappy"
        )
    ]
)
