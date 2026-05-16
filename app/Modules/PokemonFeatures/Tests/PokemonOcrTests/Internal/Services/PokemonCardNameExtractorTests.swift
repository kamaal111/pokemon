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
