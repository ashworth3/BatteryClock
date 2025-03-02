// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BatteryClock",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "BatteryClock",
            type: .dynamic,
            targets: ["BatteryClock"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pock/pockkit.git", branch: "master")
    ],
    targets: [
        .target(
            name: "BatteryClock",
            dependencies: [
                .product(name: "PockKit", package: "pockkit")
            ],
            resources: [
                .process("Resources/Info.plist")
            ])
    ]
)
