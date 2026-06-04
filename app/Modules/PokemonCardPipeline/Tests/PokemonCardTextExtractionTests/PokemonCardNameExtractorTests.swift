//
//  PokemonCardNameExtractorTests.swift
//  PokemonCardPipeline
//
//  Created by Codex on 6/4/26.
//

import CoreGraphics
import Foundation
import Testing
import UIKit
import Vision

@testable import PokemonCardTextExtraction

@Suite("PokemonCardNameExtractor Tests")
struct PokemonCardNameExtractorTests {
    @Test
    func `Should return selected candidate and pokemon name from fake recognizer`() async throws {
        let recognizer = FakePokemonCardTextRecognizer(responses: [
            [
                rawObservation(text: "HP 70", confidence: 0.99, box: .zero),
                rawObservation(text: "이브이 e", confidence: 0.80, box: .zero),
            ]
        ])
        let extractor = PokemonCardNameExtractor(recognizer: recognizer)

        let extractionResult = await extractor.extractName(from: Self.image())
        let result = try extractionResult.get()

        #expect(result.selectedCandidate?.text == "이브이 e")
        #expect(result.pokemonName == "이브이ex")
        #expect(result.titleCropImage.size.width > 0)
        #expect(result.titleCropImage.size.height > 0)
    }

    @Test
    func `Should constrain initial recognition to title search region`() async throws {
        let image = Self.image()
        let recognizer = FakePokemonCardTextRecognizer(responses: [
            [rawObservation(text: "Charizard VMAX", confidence: 0.96, box: .zero)]
        ])
        let extractor = PokemonCardNameExtractor(recognizer: recognizer)

        _ = try await extractor.extractName(from: image).get()

        #expect(
            await recognizer.configurations.first?.regionOfInterest
                == PokemonCardTitleCropper.titleSearchRegion(for: image.size))
    }

    @Test
    func `Should keep title search region wider than preferred name region`() {
        let imageSize = CGSize(width: 1_000, height: 1_400)
        let titleRegion = PokemonCardTitleCropper.titleObservationRegion(for: imageSize)
        let searchRegion = PokemonCardTitleCropper.titleSearchRegion(for: imageSize)

        #expect(searchRegion.minX < titleRegion.minX)
        #expect(titleRegion.minX == 0.20)
        #expect(searchRegion.contains(titleRegion))
    }

    @Test
    func `Should run Japanese as first supplemental pass for noisy Japanese candidate`() async throws {
        let recognizer = FakePokemonCardTextRecognizer(responses: [
            [rawObservation(text: "リザードx", confidence: 0.92, box: .zero)],
            [rawObservation(text: "リザードex", confidence: 0.96, box: .zero)],
            [],
            [],
        ])
        let extractor = PokemonCardNameExtractor(recognizer: recognizer)

        let result = try await extractor.extractName(from: Self.image()).get()

        #expect(result.pokemonName == "リザードex")
        #expect(await recognizer.configurations.dropFirst().first?.recognitionLanguages == ["ja-JP"])
    }

    @Test
    func `Should return nil pokemon name when no candidate looks like a name`() async throws {
        let recognizer = FakePokemonCardTextRecognizer(responses: [
            [
                rawObservation(text: "HP 70", confidence: 0.99, box: .zero),
                rawObservation(text: "120", confidence: 0.90, box: .zero),
            ],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
            [],
        ])
        let extractor = PokemonCardNameExtractor(recognizer: recognizer)

        let result = try await extractor.extractName(from: Self.image()).get()

        #expect(result.pokemonName == nil)
    }

    @Test
    func `Should isolate non-empty title crops for bundled samples`() throws {
        for sample in SampleCard.allCases {
            let result = try PokemonCardTitleCropper.cropTitle(from: sample.image).get()

            #expect(result.image.size.width > 0, "Expected title crop width for \(sample.rawValue)")
            #expect(result.image.size.height > 0, "Expected title crop height for \(sample.rawValue)")
        }
    }

    @Test
    func `Should normalize card title text conservatively`() {
        let cases = [
            ("이브이e", "이브이ex"),
            ("이브이 e", "이브이ex"),
            ("이브이eX", "이브이ex"),
            ("ピカチュウEX", "ピカチュウex"),
            ("ピカチュウ EX", "ピカチュウex"),
            ("ホップ の カビゴン", "ホップのカビゴン"),
            ("ピカチュウｅ", "ピカチュウex"),
            ("リザード", "リザード"),
            ("N의 조로아", "N의 조로아"),
            ("Nのゾロアーク EX", "Nのゾロアークex"),
            ("索 罗 亚", "索罗亚"),
            ("Charizard VMAX", "Charizard VMAX"),
            ("  Charizard   GX\n", "Charizard GX"),
        ]

        for (input, expectedOutput) in cases {
            #expect(PokemonCardTitleNormalizer.normalize(input) == expectedOutput)
        }
    }

    @Test
    func `Should prefer candidate inside title region over higher confidence outside text`() {
        let selectedCandidate = PokemonCardNameCandidateSelector.chooseBestCandidate(
            from: [
                PokemonCardNameCandidate(
                    text: "HP 70",
                    confidence: 0.99,
                    boundingBox: CGRect(x: 0.78, y: 0.86, width: 0.12, height: 0.05)
                ),
                PokemonCardNameCandidate(
                    text: "ホップのカビゴン",
                    confidence: 0.78,
                    boundingBox: CGRect(x: 0.18, y: 0.86, width: 0.38, height: 0.05)
                ),
            ],
            preferredRegion: CGRect(x: 0.12, y: 0.85, width: 0.63, height: 0.11)
        )

        #expect(selectedCandidate?.normalizedText == "ホップのカビゴン")
    }

    @Test
    func `Should prefer Korean name to the right of top-left stage marker`() {
        let selectedCandidate = PokemonCardNameCandidateSelector.chooseBestCandidate(
            from: [
                PokemonCardNameCandidate(
                    text: "기봉",
                    confidence: 0.99,
                    boundingBox: CGRect(x: 0.12, y: 0.88, width: 0.08, height: 0.04)
                ),
                PokemonCardNameCandidate(
                    text: "N의 조로아",
                    confidence: 0.87,
                    boundingBox: CGRect(x: 0.23, y: 0.88, width: 0.25, height: 0.04)
                ),
            ],
            preferredRegion: CGRect(x: 0.20, y: 0.85, width: 0.55, height: 0.11)
        )

        #expect(selectedCandidate?.normalizedText == "N의 조로아")
    }

    @Test
    func `Should extract Korean name instead of stage marker from fake recognizer`() async throws {
        let recognizer = FakePokemonCardTextRecognizer(responses: [
            [
                rawObservation(
                    text: "기봉",
                    confidence: 0.99,
                    box: CGRect(x: 0.02, y: 0.36, width: 0.08, height: 0.28)
                ),
                rawObservation(
                    text: "N의 조로아",
                    confidence: 0.87,
                    box: CGRect(x: 0.13, y: 0.36, width: 0.25, height: 0.28)
                ),
            ]
        ])
        let extractor = PokemonCardNameExtractor(recognizer: recognizer)

        let result = try await extractor.extractName(from: Self.image()).get()

        #expect(result.pokemonName == "N의 조로아")
    }

    private static func image(size: CGSize = CGSize(width: 240, height: 336)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

private actor FakePokemonCardTextRecognizer: PokemonCardTextRecognizing {
    private var responses: [[PokemonCardRawTextObservation]]
    private(set) var configurations: [PokemonCardTextRecognizerConfiguration] = []

    init(responses: [[PokemonCardRawTextObservation]]) {
        self.responses = responses
    }

    func recognizeText(
        in image: UIImage,
        configuration: PokemonCardTextRecognizerConfiguration
    ) async -> Result<[PokemonCardRawTextObservation], PokemonCardTextExtractionError> {
        configurations.append(configuration)
        guard !responses.isEmpty else {
            return .success([])
        }

        return .success(responses.removeFirst())
    }
}

private func rawObservation(
    text: String,
    confidence: Float,
    box: CGRect
) -> PokemonCardRawTextObservation {
    PokemonCardRawTextObservation(
        text: text,
        topCandidates: [PokemonCardTextCandidate(text: text, confidence: confidence)],
        confidence: confidence,
        boundingBox: box
    )
}

private enum SampleCard: String, CaseIterable {
    case cameraMeowth = "camera-meowth"
    case eevee
    case insectChinese = "insect-chinese"
    case shinyCharmeleon = "shiny-charmeleon"
    case trainersGhost = "trainers-ghost"
    case trainersSnorlax = "trainers-snorlax"
    case trainersWold = "trainers-wold"

    var image: UIImage {
        let url =
            Bundle.module.url(forResource: rawValue, withExtension: "jpg")
            ?? Bundle.module.url(forResource: rawValue, withExtension: "jpg", subdirectory: "SampleCards")
        guard let url else { preconditionFailure("Missing sample image resource: \(rawValue).jpg") }

        let data = try? Data(contentsOf: url)
        guard let data else { preconditionFailure("Sample image could not be loaded: \(rawValue).jpg") }

        let image = UIImage(data: data)
        guard let image else { preconditionFailure("Sample image could not be decoded: \(rawValue).jpg") }

        return image
    }
}
