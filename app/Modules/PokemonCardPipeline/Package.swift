// swift-tools-version: 6.2.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PokemonCardPipeline",
    defaultLocalization: "en",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "PokemonCardPipeline", targets: ["PokemonCardPipeline"]),
        .library(name: "PokemonCardImageProcessing", targets: ["PokemonCardImageProcessing"]),
        .library(name: "PokemonCardCropping", targets: ["PokemonCardCropping"]),
        .library(name: "PokemonCardDetection", targets: ["PokemonCardDetection"]),
        .library(name: "PokemonCardFocusQuality", targets: ["PokemonCardFocusQuality"]),
        .library(name: "PokemonCardOrientationCorrection", targets: ["PokemonCardOrientationCorrection"]),
        .library(name: "PokemonCardStability", targets: ["PokemonCardStability"]),
        .library(name: "PokemonCardTextExtraction", targets: ["PokemonCardTextExtraction"]),
        .library(name: "PokemonCardTextRecognition", targets: ["PokemonCardTextRecognition"]),
        .library(name: "PokemonCardUtilities", targets: ["PokemonCardUtilities"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Kamaalio/KamaalSwift.git", from: "3.5.0")
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
            dependencies: [
                "PokemonCardImageProcessing",
                "PokemonCardUtilities",
            ],
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
            name: "PokemonCardFocusQuality",
            dependencies: ["PokemonCardUtilities"],
            swiftSettings: [
                .treatAllWarnings(as: .error)
            ]
        ),
        .target(
            name: "PokemonCardOrientationCorrection",
            dependencies: [
                "PokemonCardImageProcessing",
                "PokemonCardTextRecognition",
                "PokemonCardUtilities",
            ],
            swiftSettings: [
                .treatAllWarnings(as: .error)
            ]
        ),
        .target(
            name: "PokemonCardStability",
            dependencies: [
                "PokemonCardDetection",
                "PokemonCardFocusQuality",
            ],
            swiftSettings: [
                .treatAllWarnings(as: .error)
            ]
        ),
        .target(
            name: "PokemonCardPipeline",
            dependencies: [
                "PokemonCardCropping",
                "PokemonCardDetection",
                "PokemonCardFocusQuality",
                "PokemonCardOrientationCorrection",
                "PokemonCardStability",
                "PokemonCardTextExtraction",
                "PokemonCardUtilities",
            ],
            swiftSettings: [
                .treatAllWarnings(as: .error)
            ]
        ),
        .target(
            name: "PokemonCardTextExtraction",
            dependencies: [
                "PokemonCardImageProcessing",
                "PokemonCardTextRecognition",
                "PokemonCardUtilities",
                .product(name: "KamaalLogger", package: "KamaalSwift"),
                .product(name: "KamaalExtensions", package: "KamaalSwift"),
            ],
            swiftSettings: [
                .treatAllWarnings(as: .error)
            ]
        ),
        .target(
            name: "PokemonCardTextRecognition",
            dependencies: [],
            swiftSettings: [
                .treatAllWarnings(as: .error)
            ]
        ),
        .target(
            name: "PokemonCardUtilities",
            dependencies: [],
            swiftSettings: [
                .treatAllWarnings(as: .error)
            ]
        ),
        .target(
            name: "PokemonCardPipelineTestSupport",
            dependencies: [],
            path: "Tests/PokemonCardPipelineTestSupport",
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
                "PokemonCardFocusQuality",
                "PokemonCardStability",
            ],
            swiftSettings: [
                .treatAllWarnings(as: .error)
            ]
        ),
        .testTarget(
            name: "PokemonCardFocusQualityTests",
            dependencies: [
                "PokemonCardFocusQuality",
                "PokemonCardPipelineTestSupport",
            ],
            swiftSettings: [
                .treatAllWarnings(as: .error)
            ]
        ),
        .testTarget(
            name: "PokemonCardPipelineTests",
            dependencies: [
                "PokemonCardPipeline",
                "PokemonCardCropping",
                "PokemonCardDetection",
                "PokemonCardFocusQuality",
                "PokemonCardOrientationCorrection",
                "PokemonCardTextExtraction",
                "PokemonCardPipelineTestSupport",
            ],
            swiftSettings: [
                .treatAllWarnings(as: .error)
            ]
        ),
        .testTarget(
            name: "PokemonCardOrientationCorrectionTests",
            dependencies: [
                "PokemonCardCropping",
                "PokemonCardDetection",
                "PokemonCardOrientationCorrection",
                "PokemonCardTextExtraction",
                "PokemonCardTextRecognition",
            ],
            resources: [
                .process("Internal/Resources")
            ],
            swiftSettings: [
                .treatAllWarnings(as: .error)
            ]
        ),
        .testTarget(
            name: "PokemonCardTextExtractionTests",
            dependencies: [
                "PokemonCardTextExtraction",
                "PokemonCardTextRecognition",
                "PokemonCardUtilities",
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
