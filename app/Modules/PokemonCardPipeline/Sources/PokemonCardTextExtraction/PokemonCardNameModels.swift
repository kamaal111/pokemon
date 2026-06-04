//
//  PokemonCardNameModels.swift
//  PokemonCardPipeline
//
//  Created by Codex on 6/4/26.
//

import CoreGraphics
import Foundation
import UIKit

public enum PokemonCardNameExtractionError: LocalizedError, Equatable, Sendable {
    case emptyTitleCrop
    case textRecognitionFailed

    public var errorDescription: String? {
        switch self {
        case .emptyTitleCrop:
            "The card title could not be isolated from the image."
        case .textRecognitionFailed:
            "The card text could not be recognized."
        }
    }
}

public struct PokemonCardNameExtractionResult {
    public let originalImage: UIImage
    public let titleCropImage: UIImage
    public let rawCandidates: [PokemonCardNameCandidate]
    public let selectedCandidate: PokemonCardNameCandidate?
    public let pokemonName: String?
}

public struct PokemonCardNameCandidate: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let text: String
    public let normalizedText: String
    public let confidence: Float
    public let boundingBox: CGRect

    init(
        text: String,
        confidence: Float,
        boundingBox: CGRect,
        normalizedText: String? = nil
    ) {
        self.id = UUID()
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.normalizedText = normalizedText ?? PokemonCardTitleNormalizer.normalize(text)
    }

    public static func == (lhs: PokemonCardNameCandidate, rhs: PokemonCardNameCandidate) -> Bool {
        lhs.text == rhs.text
            && lhs.normalizedText == rhs.normalizedText
            && lhs.confidence == rhs.confidence
            && lhs.boundingBox == rhs.boundingBox
    }
}
