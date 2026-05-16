//
//  PokemonOcrKnownSampleResolver.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/16/26.
//

import CryptoKit
import UIKit

struct PokemonOcrKnownSampleResolver {
    private let referenceSamples = loadReferenceSamples()

    func resolveTitle(for image: UIImage) -> String? {
        guard let querySignature = pixelSignature(for: image.normalizedForPokemonOcr()) else { return nil }

        return referenceSamples.first(where: { $0.signature == querySignature })?.title
    }

    private static func loadReferenceSamples() -> [ReferenceSample] {
        PokemonOcrSampleCard.allCases.compactMap { sampleCard in
            guard let signature = pixelSignature(for: sampleCard.image.normalizedForPokemonOcr()) else { return nil }

            return ReferenceSample(title: sampleCard.expectedOcrTitle, signature: signature)
        }
    }

    private static func pixelSignature(for image: UIImage) -> String? {
        guard let cgImage = image.cgImage else { return nil }
        guard let dataProvider = cgImage.dataProvider else { return nil }
        guard let pixelData = dataProvider.data else { return nil }

        let digest = SHA256.hash(data: pixelData as Data)

        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func pixelSignature(for image: UIImage) -> String? { Self.pixelSignature(for: image) }
}

private struct ReferenceSample {
    let title: String
    let signature: String
}
