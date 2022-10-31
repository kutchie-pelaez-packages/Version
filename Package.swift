// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "Version",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "Version", targets: ["Version"])
    ],
    dependencies: [
        .package(url: "https://github.com/kutchie-pelaez-packages/Core.git", branch: "master")
    ],
    targets: [
        .target(name: "Version", dependencies: [
            .product(name: "Core", package: "Core"),
            .product(name: "CoreUtils", package: "Core")
        ], path: "Sources"),
        .testTarget(name: "VersionTests", dependencies: [
            .target(name: "Version")
        ], path: "Tests")
    ]
)
