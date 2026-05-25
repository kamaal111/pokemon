// swift-tools-version: 6.2.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PokemonFeatures",
    defaultLocalization: "en",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "PokemonOcr", targets: ["PokemonOcr"])
    ],
    dependencies: [
        .package(path: "../PokemonCardPipeline")
    ],
    targets: [
        .target(
            name: "PokemonOcr",
            dependencies: [
                .product(name: "PokemonCardCropping", package: "PokemonCardPipeline"),
                .product(name: "PokemonCardDetection", package: "PokemonCardPipeline"),
                .product(name: "PokemonCardImageProcessing", package: "PokemonCardPipeline"),
                .product(name: "PokemonCardStability", package: "PokemonCardPipeline"),
            ],
            resources: [
                .process("Internal/Resources")
            ],
            swiftSettings: [
                .treatAllWarnings(as: .error)
            ]
        ),
        .testTarget(
            name: "PokemonOcrTests",
            dependencies: [
                "PokemonOcr",
                .product(name: "PokemonCardCropping", package: "PokemonCardPipeline"),
                .product(name: "PokemonCardDetection", package: "PokemonCardPipeline"),
                .product(name: "PokemonCardImageProcessing", package: "PokemonCardPipeline"),
                .product(name: "PokemonCardStability", package: "PokemonCardPipeline"),
            ],
            resources: [
                .process("Internal/Resources")
            ],
            swiftSettings: [
                .treatAllWarnings(as: .error)
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
