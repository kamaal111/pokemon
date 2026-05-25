//
//  PokemonCardTextModels.swift
//  PokemonCardPipeline
//
//  Created by Kamaal M Farah on 5/25/26.
//

import CoreGraphics
import UIKit

public enum PokemonCardTextExtractionError: LocalizedError, Equatable, Sendable {
    case invalidImage
    case requestFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidImage:
            "The card image could not be prepared for text extraction."
        case .requestFailed(let message):
            "The card text could not be extracted. \(message)"
        }
    }
}

public struct PokemonCardTextCandidate: Equatable, Sendable {
    public let text: String
    public let confidence: Float

    public init(text: String, confidence: Float) {
        self.text = text
        self.confidence = confidence
    }
}

public struct PokemonCardTextObservation: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let text: String
    public let normalizedText: String
    public let topCandidates: [PokemonCardTextCandidate]
    public let confidence: Float
    public let normalizedBoundingBox: CGRect
    public let sourcePassLabel: String
    public let imageRect: CGRect

    init(
        id: UUID = UUID(),
        text: String,
        normalizedText: String,
        topCandidates: [PokemonCardTextCandidate],
        confidence: Float,
        normalizedBoundingBox: CGRect,
        sourcePassLabel: String,
        imageRect: CGRect
    ) {
        self.id = id
        self.text = text
        self.normalizedText = normalizedText
        self.topCandidates = topCandidates
        self.confidence = confidence
        self.normalizedBoundingBox = normalizedBoundingBox
        self.sourcePassLabel = sourcePassLabel
        self.imageRect = imageRect
    }
}

public struct PokemonCardTextRecognitionPassReport: Equatable, Sendable {
    public let label: String
    public let regionOfInterest: CGRect?
    public let recognitionLevel: String
    public let minimumTextHeight: Float
    public let supportedLanguageCount: Int
    public let automaticallyDetectsLanguage: Bool
    public let usedExplicitRecognitionLanguages: Bool
    public let candidateCount: Int
    public let topStrings: [String]
    public let errorMessage: String?

    init(
        label: String,
        regionOfInterest: CGRect?,
        recognitionLevel: String,
        minimumTextHeight: Float,
        supportedLanguageCount: Int,
        automaticallyDetectsLanguage: Bool,
        usedExplicitRecognitionLanguages: Bool,
        candidateCount: Int,
        topStrings: [String],
        errorMessage: String? = nil
    ) {
        self.label = label
        self.regionOfInterest = regionOfInterest
        self.recognitionLevel = recognitionLevel
        self.minimumTextHeight = minimumTextHeight
        self.supportedLanguageCount = supportedLanguageCount
        self.automaticallyDetectsLanguage = automaticallyDetectsLanguage
        self.usedExplicitRecognitionLanguages = usedExplicitRecognitionLanguages
        self.candidateCount = candidateCount
        self.topStrings = topStrings
        self.errorMessage = errorMessage
    }
}

public struct PokemonCardTextDebugImage: Identifiable {
    public let id: UUID
    public let label: String
    public let image: UIImage
    public let regionOfInterest: CGRect?

    init(
        id: UUID = UUID(),
        label: String,
        image: UIImage,
        regionOfInterest: CGRect? = nil
    ) {
        self.id = id
        self.label = label
        self.image = image
        self.regionOfInterest = regionOfInterest
    }
}

public struct PokemonCardTextExtractionResult {
    public let observations: [PokemonCardTextObservation]
    public let passes: [PokemonCardTextRecognitionPassReport]
    public let debugImages: [PokemonCardTextDebugImage]
    public let combinedText: String
}
