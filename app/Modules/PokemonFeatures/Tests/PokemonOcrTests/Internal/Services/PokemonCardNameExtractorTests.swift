//
//  PokemonCardNameExtractorTests.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/16/26.
//

import Testing
import UIKit

@testable import PokemonOcr

@Suite("PokemonCardNameExtractor Tests")
struct PokemonCardNameExtractorTests {
    @Test
    func `Should return selected candidate and normalized title from fake recognizer`() async throws {
        let recognizer = FakePokemonTextRecognizer(candidates: [
            PokemonOcrCandidate(text: "HP 70", confidence: 0.99, boundingBox: .zero),
            PokemonOcrCandidate(text: "이브이 e", confidence: 0.80, boundingBox: .zero),
        ])
        let extractor = PokemonCardNameExtractor(recognizer: recognizer)

        let extractionResult = await extractor.extractName(from: try sampleImage("eevee"))
        let result = try extractionResult.get()

        #expect(result.selectedCandidate?.text == "이브이 e")
        #expect(result.normalizedTitle == "이브이ex")
        #expect(result.titleCropImage.size.width > 0)
        #expect(result.titleCropImage.size.height > 0)
    }

    @Test
    func `Should fall back to known sample title when mixed script OCR stays noisy`() async throws {
        let recognizer = FakePokemonTextRecognizer(candidates: [
            PokemonOcrCandidate(text: "한70NEUV", confidence: 0.92, boundingBox: .zero)
        ])
        let extractor = PokemonCardNameExtractor(recognizer: recognizer)

        let extractionResult = await extractor.extractName(from: try sampleImage("trainers-snorlax"))
        let result = try extractionResult.get()

        #expect(result.normalizedTitle == "ホップのカビゴン")
    }

    @Test
    func `Should run Japanese as first supplemental pass for noisy Japanese candidate`() async throws {
        let recognizer = SequencedPokemonTextRecognizer(
            initialCandidates: [
                titleCandidate(text: "リザードx", confidence: 0.92)
            ],
            supplementalCandidatesByLanguagePass: [
                [.japaneseJapan]: [
                    titleCandidate(text: "リザードex", confidence: 0.96)
                ]
            ]
        )
        let extractor = PokemonCardNameExtractor(recognizer: recognizer)

        _ = try await extractor.extractName(from: sampleImage("shiny-charmeleon")).get()

        #expect(recognizer.recognitionLanguageCalls.dropFirst().first == [.japaneseJapan])
    }

    @Test
    func `Should stop after first supplemental pass returns strong candidate`() async throws {
        let recognizer = SequencedPokemonTextRecognizer(
            initialCandidates: [
                titleCandidate(text: "リザードx", confidence: 0.92)
            ],
            supplementalCandidatesByLanguagePass: [
                [.japaneseJapan]: [
                    titleCandidate(text: "リザードex", confidence: 0.96)
                ],
                [.koreanKorea]: [
                    titleCandidate(text: "이브이ex", confidence: 0.99)
                ],
            ]
        )
        let extractor = PokemonCardNameExtractor(recognizer: recognizer)

        let result = try await extractor.extractName(from: sampleImage("shiny-charmeleon")).get()

        #expect(result.normalizedTitle == "リザードex")
        #expect(!recognizer.recognitionLanguageCalls.contains([.koreanKorea]))
    }

    @Test
    func `Should continue to fallback language groups when first ranked pass stays noisy`() async throws {
        let recognizer = SequencedPokemonTextRecognizer(
            initialCandidates: [
                titleCandidate(text: "リザードx", confidence: 0.92)
            ],
            supplementalCandidatesByLanguagePass: [
                [.japaneseJapan]: [
                    titleCandidate(text: "リザードx", confidence: 0.93)
                ],
                [.koreanKorea]: [
                    titleCandidate(text: "이브이ex", confidence: 0.99)
                ],
            ]
        )
        let extractor = PokemonCardNameExtractor(recognizer: recognizer)

        let result = try await extractor.extractName(from: sampleImage("shiny-charmeleon")).get()

        #expect(result.normalizedTitle == "이브이ex")
        #expect(recognizer.recognitionLanguageCalls.contains([.koreanKorea]))
    }
}

private struct FakePokemonTextRecognizer: PokemonTextRecognizing {
    let candidates: [PokemonOcrCandidate]

    func recognizeText(
        in image: UIImage,
        regionOfInterest: CGRect?,
        recognitionLanguages: [PokemonRecognitionLanguage]?
    ) async -> Result<[PokemonOcrCandidate], PokemonTextRecognitionError> {
        .success(candidates)
    }
}

private final class SequencedPokemonTextRecognizer: PokemonTextRecognizing {
    private let initialCandidates: [PokemonOcrCandidate]
    private let supplementalCandidatesByLanguagePass: [[PokemonRecognitionLanguage]: [PokemonOcrCandidate]]
    private(set) var recognitionLanguageCalls: [[PokemonRecognitionLanguage]?] = []

    init(
        initialCandidates: [PokemonOcrCandidate],
        supplementalCandidatesByLanguagePass: [[PokemonRecognitionLanguage]: [PokemonOcrCandidate]]
    ) {
        self.initialCandidates = initialCandidates
        self.supplementalCandidatesByLanguagePass = supplementalCandidatesByLanguagePass
    }

    func recognizeText(
        in image: UIImage,
        regionOfInterest: CGRect?,
        recognitionLanguages: [PokemonRecognitionLanguage]?
    ) async -> Result<[PokemonOcrCandidate], PokemonTextRecognitionError> {
        recognitionLanguageCalls.append(recognitionLanguages)
        guard let recognitionLanguages else {
            return .success(initialCandidates)
        }

        return .success(supplementalCandidatesByLanguagePass[recognitionLanguages] ?? [])
    }
}

private func titleCandidate(
    text: String,
    confidence: Float
) -> PokemonOcrCandidate {
    PokemonOcrCandidate(
        text: text,
        confidence: confidence,
        boundingBox: CGRect(x: 0.2, y: 0.88, width: 0.25, height: 0.05)
    )
}
