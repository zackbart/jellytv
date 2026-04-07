// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Library",
    platforms: [.tvOS(.v26)],
    products: [
        .library(name: "Library", targets: ["Library"]),
    ],
    dependencies: [
        .package(path: "../JellyfinAPI"),
        .package(path: "../DesignSystem"),
    ],
    targets: [
        .target(
            name: "Library",
            dependencies: [
                .product(name: "JellyfinAPI", package: "JellyfinAPI"),
                .product(name: "DesignSystem", package: "DesignSystem"),
            ]
        ),
    ]
)
