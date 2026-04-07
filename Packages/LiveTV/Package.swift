// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LiveTV",
    platforms: [.tvOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "LiveTV", targets: ["LiveTV"]),
    ],
    dependencies: [
        .package(path: "../JellyfinAPI"),
        .package(path: "../DesignSystem"),
    ],
    targets: [
        .target(
            name: "LiveTV",
            dependencies: [
                .product(name: "JellyfinAPI", package: "JellyfinAPI"),
                .product(name: "DesignSystem", package: "DesignSystem"),
            ]
        ),
        .testTarget(
            name: "LiveTVTests",
            dependencies: ["LiveTV"]
        ),
    ]
)
