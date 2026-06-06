//
//  PokemonCardTextRecognizer.swift
//  PokemonCardPipeline
//
//  Created by Codex on 6/6/26.
//

import CoreGraphics
import UIKit
import Vision

public struct PokemonCardTextRecognizerConfiguration: Equatable, Sendable {
    public let recognitionLevel: VNRequestTextRecognitionLevel
    public let automaticallyDetectsLanguage: Bool
    public let recognitionLanguages: [String]
    public let minimumTextHeight: Float
    public let regionOfInterest: CGRect?

    public init(
        recognitionLevel: VNRequestTextRecognitionLevel,
        automaticallyDetectsLanguage: Bool,
        recognitionLanguages: [String],
        minimumTextHeight: Float,
        regionOfInterest: CGRect?
    ) {
        self.recognitionLevel = recognitionLevel
        self.automaticallyDetectsLanguage = automaticallyDetectsLanguage
        self.recognitionLanguages = recognitionLanguages
        self.minimumTextHeight = minimumTextHeight
        self.regionOfInterest = regionOfInterest
    }
}

public struct PokemonCardRecognizedTextCandidate: Equatable, Sendable {
    public let text: String
    public let confidence: Float

    public init(text: String, confidence: Float) {
        self.text = text
        self.confidence = confidence
    }
}

public struct PokemonCardRawTextObservation: Equatable, Sendable {
    public let text: String
    public let topCandidates: [PokemonCardRecognizedTextCandidate]
    public let confidence: Float
    public let boundingBox: CGRect

    public init(
        text: String,
        topCandidates: [PokemonCardRecognizedTextCandidate],
        confidence: Float,
        boundingBox: CGRect
    ) {
        self.text = text
        self.topCandidates = topCandidates
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}

public enum PokemonCardTextRecognitionError: LocalizedError, Equatable, Sendable {
    case invalidImage
    case requestFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidImage:
            "The card image could not be prepared for text recognition."
        case .requestFailed(let message):
            "The card text could not be recognized. \(message)"
        }
    }
}

public protocol PokemonCardTextRecognizing: Sendable {
    func recognizeText(
        in image: UIImage,
        configuration: PokemonCardTextRecognizerConfiguration
    ) -> Result<[PokemonCardRawTextObservation], PokemonCardTextRecognitionError>
}

public struct VisionPokemonCardTextRecognizer: PokemonCardTextRecognizing {
    public init() {}

    public func recognizeText(
        in image: UIImage,
        configuration: PokemonCardTextRecognizerConfiguration
    ) -> Result<[PokemonCardRawTextObservation], PokemonCardTextRecognitionError> {
        guard let cgImage = image.cgImage else { return .failure(.invalidImage) }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = configuration.recognitionLevel
        request.automaticallyDetectsLanguage = configuration.automaticallyDetectsLanguage
        request.usesLanguageCorrection = true
        request.minimumTextHeight = configuration.minimumTextHeight
        if !configuration.recognitionLanguages.isEmpty {
            request.recognitionLanguages = configuration.recognitionLanguages
        }
        if let regionOfInterest = configuration.regionOfInterest {
            request.regionOfInterest = regionOfInterest
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return .failure(.requestFailed(error.localizedDescription))
        }

        let observations = request.results ?? []
        let rawObservations = observations.compactMap { observation -> PokemonCardRawTextObservation? in
            let candidates = observation.topCandidates(10).map { candidate in
                PokemonCardRecognizedTextCandidate(text: candidate.string, confidence: candidate.confidence)
            }
            guard let topCandidate = candidates.first else { return nil }

            return PokemonCardRawTextObservation(
                text: topCandidate.text,
                topCandidates: candidates,
                confidence: topCandidate.confidence,
                boundingBox: observation.boundingBox
            )
        }

        return .success(rawObservations)
    }
}
