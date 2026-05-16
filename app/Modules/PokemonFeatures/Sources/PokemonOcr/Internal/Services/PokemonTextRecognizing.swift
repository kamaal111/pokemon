//
//  PokemonTextRecognizing.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/16/26.
//

import UIKit
import Vision

enum PokemonTextRecognitionError: LocalizedError, Equatable {
    case requestFailed

    var errorDescription: String? {
        switch self {
        case .requestFailed:
            "The card text could not be recognized."
        }
    }
}

protocol PokemonTextRecognizing {
    func recognizeText(
        in image: UIImage,
        regionOfInterest: CGRect?,
        recognitionLanguages: [PokemonRecognitionLanguage]?
    ) async -> Result<[PokemonOcrCandidate], PokemonTextRecognitionError>
}

struct VisionPokemonTextRecognizer: PokemonTextRecognizing {
    private static let defaultRecognitionLanguages: [PokemonRecognitionLanguage] = [
        .koreanKorea,
        .japaneseJapan,
        .chineseSimplified,
        .chineseTraditional,
        .englishUnitedStates,
    ]

    func recognizeText(
        in image: UIImage,
        regionOfInterest: CGRect?,
        recognitionLanguages: [PokemonRecognitionLanguage]?
    ) async -> Result<[PokemonOcrCandidate], PokemonTextRecognitionError> {
        guard let cgImage = image.cgImage else { return .success([]) }

        let effectiveRecognitionLanguages = recognitionLanguages ?? Self.defaultRecognitionLanguages
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = Self.recognitionLevel
        request.usesLanguageCorrection = shouldUseLanguageCorrection(for: effectiveRecognitionLanguages)
        request.recognitionLanguages = effectiveRecognitionLanguages.map(\.rawValue)
        request.customWords = PokemonOcrLexicon.customWords(for: effectiveRecognitionLanguages)
        request.minimumTextHeight = 0.01
        if let regionOfInterest {
            request.regionOfInterest = regionOfInterest
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return .failure(.requestFailed)
        }

        guard let requestResults = request.results else { return .success([]) }

        let candidates = requestResults.flatMap { observation in
            observation.topCandidates(10).map { candidate in
                let projectedBoundingBox = projectedBoundingBox(for: observation.boundingBox, in: regionOfInterest)

                return PokemonOcrCandidate(
                    text: candidate.string,
                    confidence: candidate.confidence,
                    boundingBox: projectedBoundingBox
                )
            }
        }

        return .success(candidates)
    }

    private func projectedBoundingBox(
        for observationBoundingBox: CGRect,
        in regionOfInterest: CGRect?
    ) -> CGRect {
        guard let regionOfInterest else { return observationBoundingBox }

        return CGRect(
            x: regionOfInterest.minX + (observationBoundingBox.minX * regionOfInterest.width),
            y: regionOfInterest.minY + (observationBoundingBox.minY * regionOfInterest.height),
            width: observationBoundingBox.width * regionOfInterest.width,
            height: observationBoundingBox.height * regionOfInterest.height
        )
    }

    private func shouldUseLanguageCorrection(
        for recognitionLanguages: [PokemonRecognitionLanguage]
    ) -> Bool {
        let eastAsianLanguageSets: Set<Set<PokemonRecognitionLanguage>> = [
            [.japaneseJapan],
            [.koreanKorea],
            [.chineseSimplified],
            [.chineseTraditional],
            [.chineseSimplified, .chineseTraditional],
        ]

        return !eastAsianLanguageSets.contains(Set(recognitionLanguages))
    }

    private static var recognitionLevel: VNRequestTextRecognitionLevel {
        #if targetEnvironment(simulator)
            return isRunningUnderXCTest ? .fast : .accurate
        #else
            return .accurate
        #endif
    }

    #if targetEnvironment(simulator)
        private static var isRunningUnderXCTest: Bool {
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        }
    #endif
}
