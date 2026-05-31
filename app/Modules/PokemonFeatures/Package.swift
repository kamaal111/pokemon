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
        .package(url: "https://github.com/Kamaalio/KamaalSwift.git", from: "3.5.0"),
        .package(path: "../PokemonCardPipeline"),
    ],
    targets: [
        .target(
            name: "PokemonOcr",
            dependencies: [
                .product(name: "PokemonCardPipeline", package: "PokemonCardPipeline"),
                .product(name: "PokemonCardCropping", package: "PokemonCardPipeline"),
                .product(name: "PokemonCardDetection", package: "PokemonCardPipeline"),
                .product(name: "PokemonCardFocusQuality", package: "PokemonCardPipeline"),
                .product(name: "PokemonCardImageProcessing", package: "PokemonCardPipeline"),
                .product(name: "PokemonCardStability", package: "PokemonCardPipeline"),
                .product(name: "PokemonCardTextExtraction", package: "PokemonCardPipeline"),
                .product(name: "PokemonCardUtilities", package: "PokemonCardPipeline"),
                .product(name: "KamaalLogger", package: "KamaalSwift"),
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
                .product(name: "PokemonCardPipeline", package: "PokemonCardPipeline"),
                .product(name: "PokemonCardCropping", package: "PokemonCardPipeline"),
                .product(name: "PokemonCardDetection", package: "PokemonCardPipeline"),
                .product(name: "PokemonCardFocusQuality", package: "PokemonCardPipeline"),
                .product(name: "PokemonCardImageProcessing", package: "PokemonCardPipeline"),
                .product(name: "PokemonCardStability", package: "PokemonCardPipeline"),
                .product(name: "PokemonCardTextExtraction", package: "PokemonCardPipeline"),
                .product(name: "KamaalLogger", package: "KamaalSwift"),
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
