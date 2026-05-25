// swift-tools-version: 6.2.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PokemonCardPipeline",
    defaultLocalization: "en",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "PokemonCardImageProcessing", targets: ["PokemonCardImageProcessing"]),
        .library(name: "PokemonCardCropping", targets: ["PokemonCardCropping"]),
        .library(name: "PokemonCardDetection", targets: ["PokemonCardDetection"]),
        .library(name: "PokemonCardStability", targets: ["PokemonCardStability"]),
    ],
    targets: [
        .target(
            name: "PokemonCardImageProcessing",
            swiftSettings: [
                .treatAllWarnings(as: .error)
            ]
        ),
        .target(
            name: "PokemonCardCropping",
            dependencies: ["PokemonCardImageProcessing"],
            swiftSettings: [
                .treatAllWarnings(as: .error)
            ]
        ),
        .target(
            name: "PokemonCardDetection",
            dependencies: ["PokemonCardImageProcessing"],
            swiftSettings: [
                .treatAllWarnings(as: .error)
            ]
        ),
        .target(
            name: "PokemonCardStability",
            dependencies: ["PokemonCardDetection"],
            swiftSettings: [
                .treatAllWarnings(as: .error)
            ]
        ),
        .testTarget(
            name: "PokemonCardCroppingTests",
            dependencies: ["PokemonCardCropping"],
            resources: [
                .process("Internal/Resources")
            ],
            swiftSettings: [
                .treatAllWarnings(as: .error)
            ]
        ),
        .testTarget(
            name: "PokemonCardDetectionTests",
            dependencies: [
                "PokemonCardCropping",
                "PokemonCardDetection",
            ],
            resources: [
                .process("Internal/Resources")
            ],
            swiftSettings: [
                .treatAllWarnings(as: .error)
            ]
        ),
        .testTarget(
            name: "PokemonCardStabilityTests",
            dependencies: [
                "PokemonCardDetection",
                "PokemonCardStability",
            ],
            swiftSettings: [
                .treatAllWarnings(as: .error)
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
