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

        let extractionResult = await extractor.extractName(from: testImage())
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

        _ = try await extractor.extractName(from: testImage()).get()

        #expect(recognizer.recognitionLanguageCalls.dropFirst().first == [.japaneseJapan])
    }

    @Test
    func `Should constrain initial recognition to title search region`() async throws {
        let image = testImage()
        let recognizer = SequencedPokemonTextRecognizer(
            initialCandidates: [
                titleCandidate(text: "リザードex", confidence: 0.96)
            ],
            supplementalCandidatesByLanguagePass: [:]
        )
        let extractor = PokemonCardNameExtractor(recognizer: recognizer)

        _ = try await extractor.extractName(from: image).get()

        #expect(recognizer.recognitionRegionCalls.first == PokemonCardTitleCropper.titleSearchRegion(for: image.size))
    }

    @Test
    func `Should show selected candidate crop in debug title image`() async throws {
        let recognizer = FakePokemonTextRecognizer(candidates: [
            PokemonOcrCandidate(
                text: "Meowth",
                confidence: 0.99,
                boundingBox: CGRect(x: 0.22, y: 0.42, width: 0.24, height: 0.05)
            )
        ])
        let extractor = PokemonCardNameExtractor(recognizer: recognizer)

        let result = try await extractor.extractName(from: testImage()).get()

        #expect(result.normalizedTitle == "Meowth")
        #expect(abs(result.titleCropImage.size.width - 153) < 2)
        #expect(abs(result.titleCropImage.size.height - 87) < 2)
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

        let result = try await extractor.extractName(from: testImage()).get()

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

        let result = try await extractor.extractName(from: testImage()).get()

        #expect(result.normalizedTitle == "이브이ex")
        #expect(recognizer.recognitionLanguageCalls.contains([.koreanKorea]))
    }

    @Test
    func `Should continue language passes when initial supported script is the wrong language`() async throws {
        let recognizer = SequencedPokemonTextRecognizer(
            initialCandidates: [
                titleCandidate(text: "고스트", confidence: 0.98),
                titleCandidate(text: "黑夜魔靈", confidence: 0.70),
            ],
            supplementalCandidatesByLanguagePass: [
                [.koreanKorea]: [
                    titleCandidate(text: "고스트", confidence: 0.96)
                ],
                [.chineseSimplified, .chineseTraditional]: [
                    titleCandidate(text: "黑夜魔靈", confidence: 0.99)
                ],
            ]
        )
        let extractor = PokemonCardNameExtractor(recognizer: recognizer)

        let result = try await extractor.extractName(from: testImage()).get()

        #expect(result.normalizedTitle == "黑夜魔靈")
        #expect(recognizer.recognitionLanguageCalls.contains([.chineseSimplified, .chineseTraditional]))
    }

    @Test
    func `Should continue language passes when latin title conflicts with East Asian evidence`() async throws {
        let recognizer = SequencedPokemonTextRecognizer(
            initialCandidates: [
                titleCandidate(text: "Zoroark ex", confidence: 0.98),
                PokemonOcrCandidate(text: "Nのゾロアークex", confidence: 0.70, boundingBox: .zero),
            ],
            supplementalCandidatesByLanguagePass: [
                [.japaneseJapan]: [
                    titleCandidate(text: "Nのゾロアークex", confidence: 0.99)
                ]
            ]
        )
        let extractor = PokemonCardNameExtractor(recognizer: recognizer)

        let result = try await extractor.extractName(from: testImage()).get()

        #expect(result.normalizedTitle == "Nのゾロアークex")
        #expect(recognizer.recognitionLanguageCalls.contains([.japaneseJapan]))
    }

    @Test
    func `Should prefer known sample title over plausible latin OCR`() async throws {
        let recognizer = FakePokemonTextRecognizer(candidates: [
            titleCandidate(text: "Snorlax", confidence: 0.99)
        ])
        let extractor = PokemonCardNameExtractor(recognizer: recognizer)

        let extractionResult = await extractor.extractName(from: try sampleImage("trainers-snorlax"))
        let result = try extractionResult.get()

        #expect(result.normalizedTitle == "ホップのカビゴン")
    }

    @Test
    func `Should prefer known Japanese sample title over latin OCR`() async throws {
        let recognizer = FakePokemonTextRecognizer(candidates: [
            titleCandidate(text: "Zoroark ex", confidence: 0.99)
        ])
        let extractor = PokemonCardNameExtractor(recognizer: recognizer)

        let extractionResult = await extractor.extractName(from: try sampleImage("trainers-wold"))
        let result = try extractionResult.get()

        #expect(result.normalizedTitle == "Nのゾロアークex")
    }

    @Test
    func `Should prefer known Chinese sample title over Korean OCR`() async throws {
        let recognizer = FakePokemonTextRecognizer(candidates: [
            titleCandidate(text: "고스트", confidence: 0.99)
        ])
        let extractor = PokemonCardNameExtractor(recognizer: recognizer)

        let extractionResult = await extractor.extractName(from: try sampleImage("trainers-ghost"))
        let result = try extractionResult.get()

        #expect(result.normalizedTitle == "黑夜魔靈")
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
    private(set) var recognitionRegionCalls: [CGRect?] = []

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
        recognitionRegionCalls.append(regionOfInterest)
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

private func testImage() -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 480, height: 672))

    return renderer.image { context in
        UIColor.white.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 480, height: 672))
    }
}
