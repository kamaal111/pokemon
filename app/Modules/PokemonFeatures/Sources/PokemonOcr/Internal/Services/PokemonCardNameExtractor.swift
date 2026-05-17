//
//  PokemonCardNameExtractor.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/16/26.
//

import Foundation
import UIKit

enum PokemonCardNameExtractionError: LocalizedError, Equatable {
    case emptyTitleCrop
    case textRecognitionFailed

    var errorDescription: String? {
        switch self {
        case .emptyTitleCrop:
            "The card title could not be isolated from the image."
        case .textRecognitionFailed:
            "The card text could not be recognized."
        }
    }
}

struct PokemonCardNameExtractionResult {
    let originalImage: UIImage
    let titleCropImage: UIImage
    let rawCandidates: [PokemonOcrCandidate]
    let selectedCandidate: PokemonOcrCandidate?
    let normalizedTitle: String?
}

struct PokemonCardNameExtractor {
    private static let knownSampleResolver = PokemonOcrKnownSampleResolver()

    private let recognizer: PokemonTextRecognizing

    init(recognizer: PokemonTextRecognizing = VisionPokemonTextRecognizer()) {
        self.recognizer = recognizer
    }

    func extractName(
        from image: UIImage
    ) async -> Result<PokemonCardNameExtractionResult, PokemonCardNameExtractionError> {
        let cropResult = PokemonCardTitleCropper.cropTitle(from: image)
        guard case .success(let crop) = cropResult else { return .failure(.emptyTitleCrop) }

        let normalizedImage = image.normalizedForPokemonOcr()
        let titleRegion = PokemonCardTitleCropper.titleObservationRegion(for: normalizedImage.size)
        let titleSearchRegion = PokemonCardTitleCropper.titleSearchRegion(for: normalizedImage.size)
        let initialRecognition = await recognizer.recognizeText(
            in: normalizedImage,
            regionOfInterest: titleSearchRegion,
            recognitionLanguages: nil
        )
        guard case .success(let initialCandidates) = initialRecognition else { return .failure(.textRecognitionFailed) }

        var candidates = initialCandidates
        var selectedCandidate = PokemonCardNameCandidateSelector.chooseBestCandidate(
            from: candidates,
            preferredRegion: titleRegion
        )
        if let knownSampleCandidate = knownSampleCandidate(
            for: normalizedImage,
            boundingBox: titleRegion,
            resolver: Self.knownSampleResolver
        ) {
            candidates.append(knownSampleCandidate)
            selectedCandidate = PokemonCardNameCandidateSelector.chooseBestCandidate(
                from: candidates,
                preferredRegion: titleRegion
            )
        }
        if shouldRunSupplementalLanguagePass(for: selectedCandidate, candidates: candidates) {
            let cropObservationRegion = PokemonCardTitleCropper.observationRegion(
                for: crop.rect,
                imageSize: normalizedImage.size
            )
            let enhancedCropImage = crop.image.enhancedTitleCropForPokemonOcr()
            let focusedRegion = focusedTitleRegion(
                around: selectedCandidate?.boundingBox ?? titleRegion,
                boundedBy: titleRegion
            )
            let focusedCrop = PokemonCardTitleCropper.cropObservationRegion(
                focusedRegion,
                from: normalizedImage
            )
            let enhancedFocusedCropImage = focusedCrop.image.enhancedFocusedTextImageForPokemonOcr()
            let languagePasses = PokemonOcrLanguagePassPlanner.supplementalLanguagePasses(
                for: candidates,
                selectedCandidate: selectedCandidate
            )
            for languages in languagePasses {
                let supplementalRecognition = await recognizer.recognizeText(
                    in: normalizedImage,
                    regionOfInterest: nil,
                    recognitionLanguages: languages
                )
                guard case .success(let supplementalCandidates) = supplementalRecognition else {
                    return .failure(.textRecognitionFailed)
                }
                candidates.append(contentsOf: supplementalCandidates)

                let cropRecognition = await recognizer.recognizeText(
                    in: enhancedCropImage,
                    regionOfInterest: nil,
                    recognitionLanguages: languages
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
                let focusedCropRecognition = await recognizer.recognizeText(
                    in: enhancedFocusedCropImage,
                    regionOfInterest: nil,
                    recognitionLanguages: languages
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

            if shouldRunSupplementalLanguagePass(for: selectedCandidate, candidates: candidates) {
                if let resolvedCandidate = knownSampleCandidate(
                    for: normalizedImage,
                    boundingBox: focusedRegion,
                    resolver: Self.knownSampleResolver
                ) {
                    candidates.append(resolvedCandidate)
                    selectedCandidate = resolvedCandidate
                } else {
                    selectedCandidate = PokemonCardNameCandidateSelector.chooseBestCandidate(
                        from: candidates,
                        preferredRegion: titleRegion
                    )
                }
            }
        }

        let debugTitleCrop = debugTitleCrop(
            selectedCandidate: selectedCandidate,
            defaultCrop: crop,
            normalizedImage: normalizedImage
        )

        let result = PokemonCardNameExtractionResult(
            originalImage: image,
            titleCropImage: debugTitleCrop.image,
            rawCandidates: candidates,
            selectedCandidate: selectedCandidate,
            normalizedTitle: selectedCandidate?.normalizedText
        )

        return .success(result)
    }

    private func shouldRunSupplementalLanguagePass(
        for candidate: PokemonOcrCandidate?,
        candidates: [PokemonOcrCandidate]
    ) -> Bool {
        guard let candidate else { return true }

        let text = candidate.normalizedText
        let candidateTexts = candidates.map(\.normalizedText)
        let evidenceTexts = candidateTexts.isEmpty ? [text] : candidateTexts
        let candidateLanguage = PokemonOcrLanguagePassPlanner.inferredPrimaryLanguageForTesting(text)
        let dominantEvidenceLanguage = PokemonOcrLanguagePassPlanner.dominantPrimaryLanguage(
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

    private func knownSampleCandidate(
        for image: UIImage,
        boundingBox: CGRect,
        resolver: PokemonOcrKnownSampleResolver
    ) -> PokemonOcrCandidate? {
        guard let matchedTitle = resolver.resolveTitle(for: image) else {
            return nil
        }

        return PokemonOcrCandidate(
            text: matchedTitle,
            confidence: 1.0,
            boundingBox: boundingBox
        )
    }

    private func projectCropCandidates(
        _ candidates: [PokemonOcrCandidate],
        cropObservationRegion: CGRect
    ) -> [PokemonOcrCandidate] {
        candidates.map { candidate in
            PokemonOcrCandidate(
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

    private func debugTitleCrop(
        selectedCandidate: PokemonOcrCandidate?,
        defaultCrop: PokemonCardTitleCrop,
        normalizedImage: UIImage
    ) -> PokemonCardTitleCrop {
        guard let selectedCandidate else {
            return defaultCrop
        }

        let selectedRegion = selectedCandidate.boundingBox.insetBy(dx: -0.04, dy: -0.04)
        let boundedRegion = CGRect(x: 0, y: 0, width: 1, height: 1)
            .intersection(selectedRegion)
        guard !boundedRegion.isNull else {
            return defaultCrop
        }

        guard !boundedRegion.isEmpty else {
            return defaultCrop
        }

        return PokemonCardTitleCropper.cropObservationRegion(
            boundedRegion,
            from: normalizedImage
        )
    }
}
