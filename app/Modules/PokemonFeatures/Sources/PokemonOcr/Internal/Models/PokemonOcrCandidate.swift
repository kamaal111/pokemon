//
//  PokemonOcrCandidate.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/16/26.
//

import CoreGraphics
import Foundation

struct PokemonOcrCandidate: Identifiable, Equatable {
    private let identity = UUID()
    let text: String
    let normalizedText: String
    let confidence: Float
    let boundingBox: CGRect

    var id: UUID {
        identity
    }

    init(
        text: String,
        confidence: Float,
        boundingBox: CGRect,
        normalizedText: String? = nil
    ) {
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.normalizedText = normalizedText ?? PokemonCardTitleNormalizer.normalize(text)
    }

    static func == (lhs: PokemonOcrCandidate, rhs: PokemonOcrCandidate) -> Bool {
        lhs.text == rhs.text
            && lhs.normalizedText == rhs.normalizedText
            && lhs.confidence == rhs.confidence
            && lhs.boundingBox == rhs.boundingBox
    }
}
