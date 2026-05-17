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
    func recognizeText(
        in image: UIImage,
        regionOfInterest: CGRect?,
        recognitionLanguages: [PokemonRecognitionLanguage]?
    ) async -> Result<[PokemonOcrCandidate], PokemonTextRecognitionError> {
        guard let cgImage = image.cgImage else { return .success([]) }

        let configuration = VisionPokemonTextRecognitionRequestConfiguration(
            regionOfInterest: regionOfInterest,
            recognitionLanguages: recognitionLanguages
        )
        let request = configuration.makeRequest(recognitionLevel: Self.recognitionLevel)

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

struct VisionPokemonTextRecognitionRequestConfiguration {
    private static let defaultRecognitionLanguages: [PokemonRecognitionLanguage] = [
        .koreanKorea,
        .japaneseJapan,
        .chineseSimplified,
        .chineseTraditional,
        .englishUnitedStates,
    ]

    let recognitionLanguages: [PokemonRecognitionLanguage]
    let regionOfInterest: CGRect?
    let customWords: [String]
    let minimumTextHeight: Float
    let usesLanguageCorrection: Bool

    init(
        regionOfInterest: CGRect?,
        recognitionLanguages: [PokemonRecognitionLanguage]?
    ) {
        let effectiveRecognitionLanguages = recognitionLanguages ?? Self.defaultRecognitionLanguages

        self.recognitionLanguages = effectiveRecognitionLanguages
        self.regionOfInterest = regionOfInterest
        self.customWords = PokemonOcrLexicon.customWords(for: effectiveRecognitionLanguages)
        self.minimumTextHeight = 0.01
        self.usesLanguageCorrection = Self.shouldUseLanguageCorrection(for: effectiveRecognitionLanguages)
    }

    func makeRequest(recognitionLevel: VNRequestTextRecognitionLevel) -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = recognitionLevel
        request.usesLanguageCorrection = usesLanguageCorrection
        request.recognitionLanguages = recognitionLanguages.map(\.rawValue)
        request.customWords = customWords
        request.minimumTextHeight = minimumTextHeight
        if let regionOfInterest {
            request.regionOfInterest = regionOfInterest
        }

        return request
    }

    private static func shouldUseLanguageCorrection(
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
}
