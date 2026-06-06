//
//  PokemonCardTextExtractionTests.swift
//  PokemonCardPipeline
//
//  Created by Kamaal M Farah on 5/25/26.
//

import CoreGraphics
import PokemonCardTextRecognition
import Testing
import UIKit
import Vision

@testable import PokemonCardTextExtraction

@Suite("PokemonCardTextExtraction Tests")
struct PokemonCardTextExtractionTests {
    @Test
    func `Should surface language discovery failures`() async throws {
        let extractor = PokemonCardTextExtractor(
            recognizer: FailingTextRecognizer(),
            languageProvider: FailingLanguageProvider()
        )

        let result = await extractor.extractText(from: Self.image())

        #expect(throws: PokemonCardTextExtractionError.requestFailed("language unavailable")) {
            try result.get()
        }
    }

    @Test
    func `Should plan full-card and band passes`() {
        let passes = PokemonCardTextPassPlanner.passes(for: Self.image())

        #expect(
            passes.map(\.label) == [
                "normalized-full-card",
                "enhanced-full-card",
                "enhanced-top-band",
                "enhanced-middle-band",
                "enhanced-bottom-band",
            ])
        #expect(passes.filter { $0.regionOfInterest == nil }.count == 2)
        #expect(passes.filter { $0.regionOfInterest != nil }.count == 3)
    }

    @Test
    func `Should cover supported Pokemon name languages in card name passes`() {
        let recognitionLanguages = Set(
            PokemonCardNameLanguagePassPlanner.defaultLanguagePasses
                .flatMap { languagePass in languagePass.map(\.rawValue) }
        )
        let lexiconLanguages = Set(
            PokemonCardNameLanguagePassPlanner.defaultLanguagePasses
                .flatMap { languagePass in languagePass.flatMap(\.speciesLexiconLanguages) }
        )

        #expect(
            recognitionLanguages == [
                "de-DE",
                "en-US",
                "es-ES",
                "fr-FR",
                "it-IT",
                "ja-JP",
                "ko-KR",
                "zh-Hans",
                "zh-Hant",
            ])
        #expect(
            lexiconLanguages == [
                "de",
                "en",
                "es",
                "fr",
                "it",
                "ja",
                "ja-hrkt",
                "ja-roma",
                "ko",
                "zh-hans",
                "zh-hant",
            ])
    }

    @Test
    func `Should project ROI bounding boxes back into full-card coordinates`() {
        let projected = PokemonCardTextGeometry.project(
            observationBoundingBox: CGRect(x: 0.10, y: 0.20, width: 0.30, height: 0.40),
            from: CGRect(x: 0, y: 0.50, width: 1, height: 0.50)
        )

        #expect(projected == CGRect(x: 0.10, y: 0.60, width: 0.30, height: 0.20))
    }

    @Test
    func `Should merge duplicate observations by text and overlapping boxes`() {
        let observations = PokemonCardTextObservationPostProcessor.deduplicated([
            Self.observation(text: "Pikachu", confidence: 0.60, box: CGRect(x: 0.1, y: 0.7, width: 0.4, height: 0.1)),
            Self.observation(
                text: " pikachu ", confidence: 0.90, box: CGRect(x: 0.12, y: 0.71, width: 0.38, height: 0.09)),
            Self.observation(text: "Pikachu", confidence: 0.70, box: CGRect(x: 0.1, y: 0.2, width: 0.4, height: 0.1)),
        ])

        #expect(observations.count == 2)
        #expect(observations[0].confidence == 0.90)
    }

    @Test
    func `Should combine text top-to-bottom then left-to-right`() {
        let text = PokemonCardTextObservationPostProcessor.combinedText(from: [
            Self.observation(text: "bottom", box: CGRect(x: 0.10, y: 0.10, width: 0.20, height: 0.05)),
            Self.observation(text: "right", box: CGRect(x: 0.50, y: 0.80, width: 0.20, height: 0.05)),
            Self.observation(text: "left", box: CGRect(x: 0.10, y: 0.80, width: 0.20, height: 0.05)),
        ])

        #expect(text == "left\nright\nbottom")
    }

    @Test
    func `Should surface request failures when all passes fail`() async throws {
        let extractor = PokemonCardTextExtractor(
            recognizer: FailingTextRecognizer(),
            languageProvider: StaticLanguageProvider(languages: ["en-US"])
        )

        let result = await extractor.extractText(from: Self.image())

        #expect(throws: PokemonCardTextExtractionError.requestFailed("forced failure")) {
            try result.get()
        }
    }

    private static func observation(
        text: String,
        confidence: Float = 0.80,
        box: CGRect
    ) -> PokemonCardTextObservation {
        PokemonCardTextObservation(
            text: text,
            normalizedText: PokemonCardTextObservationPostProcessor.normalizedText(text),
            topCandidates: [PokemonCardTextCandidate(text: text, confidence: confidence)],
            confidence: confidence,
            normalizedBoundingBox: box,
            sourcePassLabel: "test",
            imageRect: .zero
        )
    }

    private static func image(size: CGSize = CGSize(width: 160, height: 220)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

private struct FailingTextRecognizer: PokemonCardTextRecognizing {
    func recognizeText(
        in image: UIImage,
        configuration: PokemonCardTextRecognizerConfiguration
    ) -> Result<[PokemonCardRawTextObservation], PokemonCardTextRecognitionError> {
        .failure(.requestFailed("forced failure"))
    }
}

private struct StaticLanguageProvider: PokemonCardTextRecognitionLanguageProviding {
    let languages: [String]

    func supportedRecognitionLanguages(
        recognitionLevel: VNRequestTextRecognitionLevel
    ) -> Result<[String], PokemonCardTextExtractionError> {
        .success(languages)
    }
}

private struct FailingLanguageProvider: PokemonCardTextRecognitionLanguageProviding {
    func supportedRecognitionLanguages(
        recognitionLevel: VNRequestTextRecognitionLevel
    ) -> Result<[String], PokemonCardTextExtractionError> {
        .failure(.requestFailed("language unavailable"))
    }
}
