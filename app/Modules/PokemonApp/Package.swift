// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PokemonApp",
    defaultLocalization: "en",
    platforms: [.iOS(.v14)],
    products: [
        .library(name: "PokemonApp", targets: ["PokemonApp"])
    ],
    targets: [
        .target(name: "PokemonApp")
    ],
    swiftLanguageModes: [.v6]
)
