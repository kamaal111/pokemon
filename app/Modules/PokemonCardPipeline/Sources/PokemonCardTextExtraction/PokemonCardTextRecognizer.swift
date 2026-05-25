//
//  PokemonCardTextRecognizer.swift
//  PokemonCardPipeline
//
//  Created by Kamaal M Farah on 5/25/26.
//

import UIKit
import Vision

struct PokemonCardTextRecognizerConfiguration: Equatable {
    let recognitionLevel: VNRequestTextRecognitionLevel
    let automaticallyDetectsLanguage: Bool
    let recognitionLanguages: [String]
    let minimumTextHeight: Float
    let regionOfInterest: CGRect?
}

struct PokemonCardRawTextObservation: Equatable {
    let text: String
    let topCandidates: [PokemonCardTextCandidate]
    let confidence: Float
    let boundingBox: CGRect
}

protocol PokemonCardTextRecognizing: Sendable {
    func recognizeText(
        in image: UIImage,
        configuration: PokemonCardTextRecognizerConfiguration
    ) async -> Result<[PokemonCardRawTextObservation], PokemonCardTextExtractionError>
}

struct VisionPokemonCardTextRecognizer: PokemonCardTextRecognizing {
    func recognizeText(
        in image: UIImage,
        configuration: PokemonCardTextRecognizerConfiguration
    ) async -> Result<[PokemonCardRawTextObservation], PokemonCardTextExtractionError> {
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
                PokemonCardTextCandidate(text: candidate.string, confidence: candidate.confidence)
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
