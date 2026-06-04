//
//  PokemonCardNameExtractor.swift
//  PokemonCardPipeline
//
//  Created by Codex on 6/4/26.
//

import Foundation
import PokemonCardImageProcessing
import UIKit
import Vision

public struct PokemonCardNameExtractor: Sendable {
    private let recognizer: PokemonCardTextRecognizing

    public init() {
        self.init(recognizer: VisionPokemonCardTextRecognizer())
    }

    init(recognizer: PokemonCardTextRecognizing) {
        self.recognizer = recognizer
    }

    public func extractName(
        from image: UIImage
    ) async -> Result<PokemonCardNameExtractionResult, PokemonCardNameExtractionError> {
        let cropResult = PokemonCardTitleCropper.cropTitle(from: image)
        guard case .success(let crop) = cropResult else { return .failure(.emptyTitleCrop) }

        let normalizedImage = PokemonCardImageNormalizer.normalizedForPokemonOcr(image)
        let titleRegion = PokemonCardTitleCropper.titleObservationRegion(for: normalizedImage.size)
        let titleSearchRegion = PokemonCardTitleCropper.titleSearchRegion(for: normalizedImage.size)
        let initialRecognition = await recognizeCandidates(
            in: normalizedImage,
            regionOfInterest: titleSearchRegion,
            recognitionLanguages: Self.defaultRecognitionLanguages
        )
        guard case .success(let initialCandidates) = initialRecognition else {
            return .failure(.textRecognitionFailed)
        }

        var candidates = initialCandidates
        var selectedCandidate = PokemonCardNameCandidateSelector.chooseBestCandidate(
            from: candidates,
            preferredRegion: titleRegion
        )
        if shouldRunSupplementalLanguagePass(for: selectedCandidate, candidates: candidates) {
            let cropObservationRegion = PokemonCardTitleCropper.observationRegion(
                for: crop.rect,
                imageSize: normalizedImage.size
            )
            let enhancedCropImage = crop.image.enhancedTitleCropForPokemonCardNameExtraction()
            let focusedRegion = focusedTitleRegion(
                around: selectedCandidate?.boundingBox ?? titleRegion,
                boundedBy: titleRegion
            )
            let focusedCrop = PokemonCardTitleCropper.cropObservationRegion(
                focusedRegion,
                from: normalizedImage
            )
            let enhancedFocusedCropImage = focusedCrop.image.enhancedFocusedTextImageForPokemonCardNameExtraction()
            let languagePasses = PokemonCardNameLanguagePassPlanner.supplementalLanguagePasses(
                for: candidates,
                selectedCandidate: selectedCandidate
            )
            for languages in languagePasses {
                let recognitionLanguages = languages.map(\.rawValue)
                let supplementalRecognition = await recognizeCandidates(
                    in: normalizedImage,
                    regionOfInterest: nil,
                    recognitionLanguages: recognitionLanguages
                )
                guard case .success(let supplementalCandidates) = supplementalRecognition else {
                    return .failure(.textRecognitionFailed)
                }
                candidates.append(contentsOf: supplementalCandidates)

                let cropRecognition = await recognizeCandidates(
                    in: enhancedCropImage,
                    regionOfInterest: nil,
                    recognitionLanguages: recognitionLanguages
                )
                guard case .success(let cropCandidates) = cropRecognition else {
                    return .failure(.textRecognitionFailed)
                }
                candidates.append(
                    contentsOf: projectCropCandidates(
                        cropCandidates,
                        cropObservationRegion: cropObservationRegion
                    )
                )

                let focusedCropRecognition = await recognizeCandidates(
                    in: enhancedFocusedCropImage,
                    regionOfInterest: nil,
                    recognitionLanguages: recognitionLanguages
                )
                guard case .success(let focusedCropCandidates) = focusedCropRecognition else {
                    return .failure(.textRecognitionFailed)
                }
                candidates.append(
                    contentsOf: projectCropCandidates(
                        focusedCropCandidates,
                        cropObservationRegion: focusedRegion
                    )
                )

                selectedCandidate = PokemonCardNameCandidateSelector.chooseBestCandidate(
                    from: candidates,
                    preferredRegion: titleRegion
                )
                if !shouldRunSupplementalLanguagePass(for: selectedCandidate, candidates: candidates) {
                    break
                }
            }
        }

        let result = PokemonCardNameExtractionResult(
            originalImage: image,
            titleCropImage: crop.image,
            rawCandidates: candidates,
            selectedCandidate: selectedCandidate,
            pokemonName: selectedCandidate?.normalizedText
        )

        return .success(result)
    }

    private func recognizeCandidates(
        in image: UIImage,
        regionOfInterest: CGRect?,
        recognitionLanguages: [String]
    ) async -> Result<[PokemonCardNameCandidate], PokemonCardNameExtractionError> {
        let configuration = PokemonCardTextRecognizerConfiguration(
            recognitionLevel: Self.recognitionLevel,
            automaticallyDetectsLanguage: true,
            recognitionLanguages: recognitionLanguages,
            minimumTextHeight: 0.01,
            regionOfInterest: regionOfInterest
        )
        let result = await recognizer.recognizeText(in: image, configuration: configuration)

        return result.mapError { _ in PokemonCardNameExtractionError.textRecognitionFailed }
            .map { rawObservations in
                rawObservations.flatMap { rawObservation in
                    rawObservation.topCandidates.map { candidate in
                        let projectedBoundingBox = PokemonCardTextGeometry.project(
                            observationBoundingBox: rawObservation.boundingBox,
                            from: regionOfInterest
                        )

                        return PokemonCardNameCandidate(
                            text: candidate.text,
                            confidence: candidate.confidence,
                            boundingBox: projectedBoundingBox
                        )
                    }
                }
            }
    }

    private func shouldRunSupplementalLanguagePass(
        for candidate: PokemonCardNameCandidate?,
        candidates: [PokemonCardNameCandidate]
    ) -> Bool {
        guard let candidate else { return true }

        let text = candidate.normalizedText
        let candidateTexts = candidates.map(\.normalizedText)
        let evidenceTexts = candidateTexts.isEmpty ? [text] : candidateTexts
        let candidateLanguage = PokemonCardNameLanguagePassPlanner.inferredPrimaryLanguageForTesting(text)
        let dominantEvidenceLanguage = PokemonCardNameLanguagePassPlanner.dominantPrimaryLanguage(
            for: evidenceTexts
        )
        let evidenceDisagrees = candidateLanguage != dominantEvidenceLanguage

        if PokemonCardTitleNormalizer.containsSupportedNameScript(text) {
            if evidenceDisagrees {
                return true
            }

            return !PokemonCardNameCandidateSelector.hasValidLatinSuffixForTesting(text)
        }

        if evidenceDisagrees {
            return true
        }

        return !isPlausibleLatinTitle(text)
    }

    private func isPlausibleLatinTitle(_ text: String) -> Bool {
        guard (4...20).contains(text.count) else { return false }

        let allowedPunctuation = CharacterSet(charactersIn: " -'")
        let hasOnlyAllowedCharacters = text.unicodeScalars.allSatisfy { scalar in
            CharacterSet.letters.contains(scalar) || allowedPunctuation.contains(scalar)
        }
        let vowelSet = CharacterSet(charactersIn: "AEIOUaeiou")
        let vowelCount = text.unicodeScalars.filter { scalar in
            vowelSet.contains(scalar)
        }.count
        let uppercaseCount = text.unicodeScalars.filter { scalar in
            CharacterSet.uppercaseLetters.contains(scalar)
        }.count
        let lowercaseCount = text.unicodeScalars.filter { scalar in
            CharacterSet.lowercaseLetters.contains(scalar)
        }.count
        let looksLikeNoisyAcronym = uppercaseCount > lowercaseCount && lowercaseCount <= 1

        return hasOnlyAllowedCharacters && vowelCount >= 1 && !looksLikeNoisyAcronym
    }

    private func projectCropCandidates(
        _ candidates: [PokemonCardNameCandidate],
        cropObservationRegion: CGRect
    ) -> [PokemonCardNameCandidate] {
        candidates.map { candidate in
            PokemonCardNameCandidate(
                text: candidate.text,
                confidence: candidate.confidence,
                boundingBox: CGRect(
                    x: cropObservationRegion.minX
                        + (candidate.boundingBox.minX * cropObservationRegion.width),
                    y: cropObservationRegion.minY
                        + (candidate.boundingBox.minY * cropObservationRegion.height),
                    width: candidate.boundingBox.width * cropObservationRegion.width,
                    height: candidate.boundingBox.height * cropObservationRegion.height
                ),
                normalizedText: candidate.normalizedText
            )
        }
    }

    private func focusedTitleRegion(
        around boundingBox: CGRect,
        boundedBy titleRegion: CGRect
    ) -> CGRect {
        let expandedRegion = boundingBox.insetBy(dx: -0.03, dy: -0.025)
        let allowedRegion = CGRect(x: 0, y: 0, width: 1, height: 1)
            .intersection(titleRegion.insetBy(dx: -0.06, dy: -0.04))
        let clampedRegion = allowedRegion.intersection(expandedRegion)

        return clampedRegion.isNull || clampedRegion.isEmpty ? expandedRegion : clampedRegion
    }

    private static let defaultRecognitionLanguages = PokemonCardNameLanguagePassPlanner.defaultLanguagePasses
        .flatMap { $0 }
        .map(\.rawValue)
    private static let recognitionLevel: VNRequestTextRecognitionLevel = .accurate
}
