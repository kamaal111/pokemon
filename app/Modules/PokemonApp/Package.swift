// swift-tools-version: 6.2.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PokemonApp",
    defaultLocalization: "en",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "PokemonApp", targets: ["PokemonApp"])
    ],
    dependencies: [
        .package(path: "../PokemonFeatures")
    ],
    targets: [
        .target(
            name: "PokemonApp",
            dependencies: [
                .product(name: "PokemonOcr", package: "PokemonFeatures")
            ],
            swiftSettings: [
                .treatAllWarnings(as: .error)
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
