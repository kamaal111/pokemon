//
//  PokemonCardSetIdentifierExtractor.swift
//  PokemonCardPipeline
//
//  Created by Codex on 6/10/26.
//

import Foundation
import UIKit
import Vision

public struct PokemonCardSetIdentifierExtractionResult {
    public let setIdentifier: String?
    public let candidates: [PokemonCardSetIdentifierCandidate]
    public let debugImages: [PokemonCardTextDebugImage]
}

public struct PokemonCardSetIdentifierCandidate: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let text: String
    public let normalizedSetIdentifier: String
    public let confidence: Float
    public let sourcePassLabel: String

    init(
        text: String,
        normalizedSetIdentifier: String,
        confidence: Float,
        sourcePassLabel: String
    ) {
        self.id = UUID()
        self.text = text
        self.normalizedSetIdentifier = normalizedSetIdentifier
        self.confidence = confidence
        self.sourcePassLabel = sourcePassLabel
    }
}

public struct PokemonCardSetIdentifierExtractor: Sendable {
    private let recognizer: PokemonCardTextRecognizing
    private let languageProvider: PokemonCardTextRecognitionLanguageProviding

    public init() {
        self.init(
            recognizer: VisionPokemonCardTextRecognizer(),
            languageProvider: PokemonCardTextRecognitionLanguageProvider()
        )
    }

    init(
        recognizer: PokemonCardTextRecognizing,
        languageProvider: PokemonCardTextRecognitionLanguageProviding
    ) {
        self.recognizer = recognizer
        self.languageProvider = languageProvider
    }

    public func extractSetIdentifier(
        from image: UIImage
    ) async -> Result<PokemonCardSetIdentifierExtractionResult, PokemonCardTextExtractionError> {
        let supportedLanguagesResult = languageProvider.supportedRecognitionLanguages(recognitionLevel: .accurate)
        let supportedLanguages: [String]
        switch supportedLanguagesResult {
        case .success(let languages):
            supportedLanguages = languages
        case .failure(let error):
            return .failure(error)
        }

        let processedImages = PokemonCardTextImageProcessing.setIdentifierImages(for: image)
        let recognitionLanguages =
            supportedLanguages.contains(Self.englishRecognitionLanguage)
            ? [Self.englishRecognitionLanguage]
            : []
        let configuration = PokemonCardTextRecognizerConfiguration(
            recognitionLevel: .accurate,
            automaticallyDetectsLanguage: false,
            recognitionLanguages: recognitionLanguages,
            usesLanguageCorrection: false,
            customWords: Self.customWords,
            minimumTextHeight: 0,
            regionOfInterest: nil,
            revision: VNRecognizeTextRequestRevision3
        )

        var candidates: [PokemonCardSetIdentifierCandidate] = []
        var debugImages: [PokemonCardTextDebugImage] = []
        var firstFailure: PokemonCardTextExtractionError?
        for processedImage in processedImages {
            debugImages.append(
                PokemonCardTextDebugImage(
                    label: processedImage.label,
                    image: processedImage.image
                ))
            let result = await recognizer.recognizeText(in: processedImage.image, configuration: configuration)
            switch result {
            case .success(let observations):
                candidates.append(
                    contentsOf: Self.candidates(from: observations, sourcePassLabel: processedImage.label)
                )
                if let selectedCandidate = Self.selectedCandidate(from: candidates) {
                    return .success(
                        PokemonCardSetIdentifierExtractionResult(
                            setIdentifier: selectedCandidate.normalizedSetIdentifier,
                            candidates: Self.deduplicated(candidates),
                            debugImages: debugImages
                        ))
                }
            case .failure(let error):
                firstFailure = firstFailure ?? error
            }
        }

        let fallbackResult = await runFullCardFallback(
            image,
            supportedLanguages: supportedLanguages,
            candidates: candidates,
            debugImages: debugImages
        )
        switch fallbackResult {
        case .success(let result):
            return .success(result)
        case .failure(let error):
            firstFailure = firstFailure ?? error
        }

        if candidates.isEmpty, let firstFailure {
            return .failure(firstFailure)
        }

        return .success(
            PokemonCardSetIdentifierExtractionResult(
                setIdentifier: Self.selectedCandidate(from: candidates)?.normalizedSetIdentifier,
                candidates: Self.deduplicated(candidates),
                debugImages: debugImages
            ))
    }

    private func runFullCardFallback(
        _ image: UIImage,
        supportedLanguages: [String],
        candidates: [PokemonCardSetIdentifierCandidate],
        debugImages: [PokemonCardTextDebugImage]
    ) async -> Result<PokemonCardSetIdentifierExtractionResult, PokemonCardTextExtractionError> {
        let configuration = PokemonCardTextRecognizerConfiguration(
            recognitionLevel: .accurate,
            automaticallyDetectsLanguage: true,
            recognitionLanguages: supportedLanguages,
            usesLanguageCorrection: true,
            customWords: Self.customWords,
            minimumTextHeight: 0.006,
            regionOfInterest: nil,
            revision: VNRecognizeTextRequestRevision3
        )
        let fallbackCrop =
            PokemonCardTextImageProcessing.croppedImage(
                from: image,
                regionOfInterest: Self.fullCardFallbackRegion
            ) ?? image
        let fallbackImages = [
            PokemonCardProcessedTextImage(
                label: "normalized-set-id-full-card-fallback",
                image: PokemonCardTextImageProcessing.normalized(fallbackCrop)
            ),
            PokemonCardProcessedTextImage(
                label: "enhanced-set-id-full-card-fallback",
                image: PokemonCardTextImageProcessing.enhanced(fallbackCrop)
            ),
        ]

        var allCandidates = candidates
        var allDebugImages = debugImages
        var firstFailure: PokemonCardTextExtractionError?
        for fallbackImage in fallbackImages {
            allDebugImages.append(
                PokemonCardTextDebugImage(
                    label: fallbackImage.label,
                    image: fallbackImage.image
                ))
            let recognitionResult = await recognizer.recognizeText(
                in: fallbackImage.image,
                configuration: configuration
            )
            switch recognitionResult {
            case .success(let observations):
                allCandidates += Self.candidates(from: observations, sourcePassLabel: fallbackImage.label)
                if let selectedCandidate = Self.selectedCandidate(from: allCandidates) {
                    return .success(
                        PokemonCardSetIdentifierExtractionResult(
                            setIdentifier: selectedCandidate.normalizedSetIdentifier,
                            candidates: Self.deduplicated(allCandidates),
                            debugImages: allDebugImages
                        ))
                }
            case .failure(let error):
                firstFailure = firstFailure ?? error
            }
        }

        if allCandidates.isEmpty, let firstFailure {
            return .failure(firstFailure)
        }

        return .success(
            PokemonCardSetIdentifierExtractionResult(
                setIdentifier: Self.selectedCandidate(from: allCandidates)?.normalizedSetIdentifier,
                candidates: Self.deduplicated(allCandidates),
                debugImages: allDebugImages
            ))
    }

    static func normalizedSetIdentifier(from text: String) -> String? {
        let tokens = normalizedTokens(from: text)
        guard !tokens.isEmpty else { return nil }

        for startIndex in tokens.indices {
            let maximumEndIndex = min(tokens.count, startIndex + 3)
            for endIndex in stride(from: maximumEndIndex, through: startIndex + 1, by: -1) {
                let candidate = tokens[startIndex..<endIndex].joined()
                if let normalizedIdentifier = normalizedSetIdentifierToken(candidate) {
                    return normalizedIdentifier
                }
            }
        }

        return nil
    }

    private static func candidates(
        from observations: [PokemonCardRawTextObservation],
        sourcePassLabel: String
    ) -> [PokemonCardSetIdentifierCandidate] {
        observations.flatMap { observation in
            observation.topCandidates.map { candidate in
                PokemonCardSetIdentifierCandidate(
                    text: candidate.text,
                    normalizedSetIdentifier: normalizedSetIdentifier(from: candidate.text) ?? "",
                    confidence: candidate.confidence,
                    sourcePassLabel: sourcePassLabel
                )
            }
        }
        .filter { !$0.normalizedSetIdentifier.isEmpty }
    }

    private static func selectedCandidate(
        from candidates: [PokemonCardSetIdentifierCandidate]
    ) -> PokemonCardSetIdentifierCandidate? {
        deduplicated(candidates).max { lhs, rhs in
            lhs.confidence < rhs.confidence
        }
    }

    private static func deduplicated(
        _ candidates: [PokemonCardSetIdentifierCandidate]
    ) -> [PokemonCardSetIdentifierCandidate] {
        var selectedCandidates: [String: PokemonCardSetIdentifierCandidate] = [:]
        for candidate in candidates {
            if let existingCandidate = selectedCandidates[candidate.normalizedSetIdentifier] {
                if candidate.confidence > existingCandidate.confidence {
                    selectedCandidates[candidate.normalizedSetIdentifier] = candidate
                }
            } else {
                selectedCandidates[candidate.normalizedSetIdentifier] = candidate
            }
        }

        return selectedCandidates.values.sorted { lhs, rhs in
            lhs.normalizedSetIdentifier < rhs.normalizedSetIdentifier
        }
    }

    private static func normalizedTokens(from text: String) -> [String] {
        var tokens: [String] = []
        var currentToken = ""
        for scalar in text.lowercased().unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                currentToken.unicodeScalars.append(scalar)
            } else if !currentToken.isEmpty {
                tokens.append(currentToken)
                currentToken = ""
            }
        }
        if !currentToken.isEmpty {
            tokens.append(currentToken)
        }

        return tokens
    }

    private static func normalizedSetIdentifierToken(_ token: String) -> String? {
        let token = correctedCommonOcrSubstitutions(in: token)
        if PokemonCardSetIdentifierLexicon.contains(token) {
            return token
        }

        if let setIdentifier = setIdentifierSuffix(in: token) {
            return setIdentifier
        }

        guard let setIdentifier = setIdentifierPrefix(in: token) else { return nil }

        return setIdentifier
    }

    private static func setIdentifierSuffix(in token: String) -> String? {
        for code in PokemonCardSetIdentifierLexicon.codesByDescendingLength {
            guard token.hasSuffix(code) else { continue }

            let prefix = token.dropLast(code.count)
            guard looksLikeLeadingLabel(prefix) else { continue }

            return code
        }

        return nil
    }

    private static func setIdentifierPrefix(in token: String) -> String? {
        for code in PokemonCardSetIdentifierLexicon.codesByDescendingLength {
            guard token.hasPrefix(code) else { continue }

            let suffix = token.dropFirst(code.count)
            guard looksLikeMergedCardNumberSuffix(suffix) else { continue }

            return code
        }

        return nil
    }

    private static func looksLikeMergedCardNumberSuffix(_ suffix: Substring) -> Bool {
        guard let firstScalar = suffix.unicodeScalars.first else { return false }
        let correctedFirstScalar = correctedCardNumberDigit(firstScalar)
        guard CharacterSet.decimalDigits.contains(correctedFirstScalar) else { return false }

        return suffix.unicodeScalars.count >= 2
    }

    private static func looksLikeLeadingLabel(_ prefix: Substring) -> Bool {
        guard !prefix.isEmpty else { return false }
        guard prefix.unicodeScalars.count <= 2 else { return false }

        for scalar in prefix.unicodeScalars {
            guard CharacterSet.letters.contains(scalar) else { return false }
        }

        return true
    }

    private static func correctedCommonOcrSubstitutions(in token: String) -> String {
        if token.hasPrefix("5v") {
            return "s" + token.dropFirst()
        }
        if token.hasPrefix("su") {
            return "sv" + token.dropFirst(2)
        }

        return token
    }

    private static func correctedCardNumberDigit(_ scalar: Unicode.Scalar) -> Unicode.Scalar {
        switch scalar {
        case "o":
            "0"
        case "i", "l":
            "1"
        default:
            scalar
        }
    }

    private static let englishRecognitionLanguage = "en-US"
    private static let fullCardFallbackRegion = CGRect(x: 0, y: 0, width: 0.45, height: 0.18)
    private static let customWords = PokemonCardSetIdentifierLexicon.codes
}
