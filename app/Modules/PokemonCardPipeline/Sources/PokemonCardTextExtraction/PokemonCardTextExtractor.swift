//
//  PokemonCardTextExtractor.swift
//  PokemonCardPipeline
//
//  Created by Kamaal M Farah on 5/25/26.
//

import KamaalLogger
import PokemonCardTextRecognition
import UIKit
import Vision

private let logger = KamaalLogger(from: PokemonCardTextExtractor.self, failOnError: false)

public struct PokemonCardTextExtractor: Sendable {
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

    public func extractText(
        from image: UIImage
    ) async -> Result<PokemonCardTextExtractionResult, PokemonCardTextExtractionError> {
        logger.info("Text extraction started imageSize=\(image.size.width)x\(image.size.height)")

        let supportedLanguageResult = languageProvider.supportedRecognitionLanguages(
            recognitionLevel: Self.recognitionLevel
        )
        let supportedLanguages: [String]
        switch supportedLanguageResult {
        case .success(let languages):
            supportedLanguages = languages
        case .failure(let error):
            logger.error("Language discovery failed error=\(error.localizedDescription)")
            return .failure(error)
        }
        logger.info("Language discovery supportedCount=\(supportedLanguages.count) autoDetect=true")

        let passes = PokemonCardTextPassPlanner.passes(for: image)
        let debugImages = PokemonCardTextPassPlanner.debugImages(for: passes)

        return await extractObservationsAndReports(from: passes, using: supportedLanguages).map {
            observations, reports in
            let deduplicatedObservations = PokemonCardTextObservationPostProcessor.deduplicated(observations)
            let combinedText = PokemonCardTextObservationPostProcessor.combinedText(from: deduplicatedObservations)
            logger.info(
                "Text extraction finished observations=\(deduplicatedObservations.count) passes=\(reports.count)")

            return PokemonCardTextExtractionResult(
                observations: deduplicatedObservations.sorted(
                    by: PokemonCardTextObservationPostProcessor.readingOrder
                ),
                passes: reports,
                debugImages: debugImages,
                combinedText: combinedText
            )
        }
    }

    private func extractObservationsAndReports(
        from passes: [PokemonCardTextRecognitionPass],
        using supportedLanguages: [String]
    ) async -> Result<
        (observations: [PokemonCardTextObservation], reports: [PokemonCardTextRecognitionPassReport]),
        PokemonCardTextExtractionError
    > {
        var reports: [PokemonCardTextRecognitionPassReport] = []
        var observations: [PokemonCardTextObservation] = []
        var firstFailure: PokemonCardTextExtractionError?
        for pass in passes {
            let passResult = await runPass(
                pass,
                recognitionLevel: Self.recognitionLevel,
                supportedLanguages: supportedLanguages
            )
            reports.append(passResult.report)
            observations.append(contentsOf: passResult.observations)
            if let error = passResult.error {
                firstFailure = firstFailure ?? error
            }
        }
        if observations.isEmpty, let firstFailure {
            logger.error("Text extraction failed after all passes error=\(firstFailure.localizedDescription)")
            return .failure(firstFailure)
        }

        return .success((observations, reports))
    }

    private func runPass(
        _ pass: PokemonCardTextRecognitionPass,
        recognitionLevel: VNRequestTextRecognitionLevel,
        supportedLanguages: [String]
    ) async -> (
        observations: [PokemonCardTextObservation],
        report: PokemonCardTextRecognitionPassReport,
        error: PokemonCardTextExtractionError?
    ) {
        logger.info(
            "Pass started label=\(pass.label) roi=\(String(describing: pass.regionOfInterest)) recognitionLevel=\(String(describing: recognitionLevel)) minimumTextHeight=\(pass.minimumTextHeight)"
        )

        let broadConfiguration = PokemonCardTextRecognizerConfiguration(
            recognitionLevel: recognitionLevel,
            automaticallyDetectsLanguage: true,
            recognitionLanguages: supportedLanguages,
            minimumTextHeight: pass.minimumTextHeight,
            regionOfInterest: pass.regionOfInterest
        )
        let broadResult = recognizer.recognizeText(in: pass.image, configuration: broadConfiguration)
        let rawObservations: [PokemonCardRawTextObservation]
        let usedExplicitRecognitionLanguages: Bool
        var errorMessage: String?
        switch broadResult {
        case .success(let values):
            rawObservations = values
            usedExplicitRecognitionLanguages = true
        case .failure(let error):
            logger.warning("Broad pass failed label=\(pass.label) error=\(error.localizedDescription)")
            errorMessage = error.localizedDescription
            let fallbackConfiguration = PokemonCardTextRecognizerConfiguration(
                recognitionLevel: recognitionLevel,
                automaticallyDetectsLanguage: true,
                recognitionLanguages: [],
                minimumTextHeight: pass.minimumTextHeight,
                regionOfInterest: pass.regionOfInterest
            )
            let fallbackResult = recognizer.recognizeText(in: pass.image, configuration: fallbackConfiguration)
            switch fallbackResult {
            case .success(let values):
                logger.info("Fallback pass succeeded label=\(pass.label) candidateCount=\(values.count)")
                rawObservations = values
                usedExplicitRecognitionLanguages = false
            case .failure(let fallbackError):
                logger.error("Fallback pass failed label=\(pass.label) error=\(fallbackError.localizedDescription)")
                return (
                    [],
                    makeReport(
                        pass: pass,
                        recognitionLevel: recognitionLevel,
                        supportedLanguageCount: supportedLanguages.count,
                        usedExplicitRecognitionLanguages: false,
                        rawObservations: [],
                        errorMessage: fallbackError.localizedDescription
                    ),
                    Self.extractionError(from: fallbackError)
                )
            }
        }

        let mappedObservations = mapObservations(rawObservations, pass: pass)
        for observation in mappedObservations {
            logger.info(
                "Accepted text label=\(observation.sourcePassLabel) text=\(observation.text) confidence=\(observation.confidence) box=\(String(describing: observation.normalizedBoundingBox))"
            )
        }
        logger.info("Pass finished label=\(pass.label) candidateCount=\(mappedObservations.count)")

        return (
            mappedObservations,
            makeReport(
                pass: pass,
                recognitionLevel: recognitionLevel,
                supportedLanguageCount: supportedLanguages.count,
                usedExplicitRecognitionLanguages: usedExplicitRecognitionLanguages,
                rawObservations: rawObservations,
                errorMessage: errorMessage
            ),
            nil
        )
    }

    private func mapObservations(
        _ rawObservations: [PokemonCardRawTextObservation],
        pass: PokemonCardTextRecognitionPass
    ) -> [PokemonCardTextObservation] {
        rawObservations.compactMap { rawObservation in
            let normalizedText = PokemonCardTextObservationPostProcessor.normalizedText(rawObservation.text)
            guard !normalizedText.isEmpty else { return nil }

            let projectedBox = PokemonCardTextGeometry.project(
                observationBoundingBox: rawObservation.boundingBox,
                from: pass.regionOfInterest
            )
            let imageRect = PokemonCardTextGeometry.imageRect(for: projectedBox, imageSize: pass.image.size)

            return PokemonCardTextObservation(
                text: rawObservation.text,
                normalizedText: normalizedText,
                topCandidates: rawObservation.topCandidates.map {
                    PokemonCardTextCandidate(text: $0.text, confidence: $0.confidence)
                },
                confidence: rawObservation.confidence,
                normalizedBoundingBox: projectedBox,
                sourcePassLabel: pass.label,
                imageRect: imageRect
            )
        }
    }

    private func makeReport(
        pass: PokemonCardTextRecognitionPass,
        recognitionLevel: VNRequestTextRecognitionLevel,
        supportedLanguageCount: Int,
        usedExplicitRecognitionLanguages: Bool,
        rawObservations: [PokemonCardRawTextObservation],
        errorMessage: String?
    ) -> PokemonCardTextRecognitionPassReport {
        PokemonCardTextRecognitionPassReport(
            label: pass.label,
            regionOfInterest: pass.regionOfInterest,
            recognitionLevel: String(describing: recognitionLevel),
            minimumTextHeight: pass.minimumTextHeight,
            supportedLanguageCount: supportedLanguageCount,
            automaticallyDetectsLanguage: true,
            usedExplicitRecognitionLanguages: usedExplicitRecognitionLanguages,
            candidateCount: rawObservations.count,
            topStrings: rawObservations.prefix(5).map(\.text),
            errorMessage: errorMessage
        )
    }

    private static let recognitionLevel: VNRequestTextRecognitionLevel = .accurate

    private static func extractionError(
        from error: PokemonCardTextRecognitionError
    ) -> PokemonCardTextExtractionError {
        switch error {
        case .invalidImage:
            .invalidImage
        case .requestFailed(let message):
            .requestFailed(message)
        }
    }
}
