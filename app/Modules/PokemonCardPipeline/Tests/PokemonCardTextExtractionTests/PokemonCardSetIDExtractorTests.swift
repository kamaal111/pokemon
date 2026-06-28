//
//  PokemonCardSetIDExtractorTests.swift
//  PokemonCardPipeline
//
//  Created by Codex on 6/27/26.
//

import CoreGraphics
import Testing
import UIKit
import Vision

@testable import PokemonCardTextExtraction

@Suite("PokemonCardSetIDExtractor Tests")
struct PokemonCardSetIDExtractorTests {
    @Test
    func `Should crop primary and fallback set ID regions`() throws {
        let crops = try PokemonCardSetIDCropper.crops(from: Self.image()).get()

        #expect(crops.map(\.label) == ["set-id-primary-bottom-left", "set-id-fallback-lower-left"])
        #expect(crops.allSatisfy { $0.image.size.width > 0 })
        #expect(crops.allSatisfy { $0.image.size.height > 0 })
        #expect(abs(crops[0].normalizedRect.minX - 0.03) < 0.001)
        #expect(abs(crops[0].normalizedRect.minY - 0.82) < 0.001)
        #expect(crops[0].normalizedRect.maxY <= 0.98)
        #expect(crops[1].normalizedRect.minX == 0)
        #expect(abs(crops[1].normalizedRect.minY - 0.76) < 0.001)
    }

    @Test
    func `Should clamp set ID crops for small images`() throws {
        let crops = try PokemonCardSetIDCropper.crops(from: Self.image(size: CGSize(width: 12, height: 17))).get()

        #expect(crops.allSatisfy { $0.rect.minX >= 0 })
        #expect(crops.allSatisfy { $0.rect.minY >= 0 })
        #expect(crops.allSatisfy { $0.rect.maxX <= 12 })
        #expect(crops.allSatisfy { $0.rect.maxY <= 17 })
        #expect(crops.allSatisfy { $0.image.size.width > 0 })
        #expect(crops.allSatisfy { $0.image.size.height > 0 })
    }

    @Test
    func `Should keep set ID crops away from title area`() throws {
        let crops = try PokemonCardSetIDCropper.crops(from: Self.image()).get()
        let titleArea = CGRect(x: 0, y: 0, width: 1, height: 0.20)

        #expect(crops.allSatisfy { !$0.normalizedRect.intersects(titleArea) })
    }

    @Test
    func `Should extract m2a from bottom left candidates`() async throws {
        let recognizer = FakeSetIDTextRecognizer(responses: [
            [
                Self.rawObservation(
                    text: "038/193",
                    confidence: 0.99,
                    box: CGRect(x: 0.32, y: 0.15, width: 0.30, height: 0.12),
                    topCandidates: [
                        PokemonCardTextCandidate(text: "038/193", confidence: 0.99),
                        PokemonCardTextCandidate(text: "m2a", confidence: 0.64),
                    ]
                )
            ],
            [],
        ])
        let extractor = PokemonCardSetIDExtractor(recognizer: recognizer)

        let result = try await extractor.extractSetID(from: Self.image()).get()

        #expect(result.setID == "m2a")
        #expect(result.selectedCropLabel == "set-id-primary-bottom-left")
        #expect(result.rawCandidates == ["038/193", "m2a"])
        #expect(result.debugImages.map(\.label).contains("set-id-primary-bottom-left-enhanced"))
    }

    @Test
    func `Should normalize uppercase sv8a from OCR candidates`() async throws {
        let recognizer = FakeSetIDTextRecognizer(responses: [
            [
                Self.rawObservation(
                    text: "SV8A",
                    confidence: 0.71,
                    box: CGRect(x: 0.04, y: 0.08, width: 0.20, height: 0.14)
                )
            ],
            [],
        ])
        let extractor = PokemonCardSetIDExtractor(recognizer: recognizer)

        let result = try await extractor.extractSetID(from: Self.image()).get()

        #expect(result.setID == "sv8a")
    }

    @Test
    func `Should reject non set ID OCR candidates`() async throws {
        let recognizer = FakeSetIDTextRecognizer(responses: [
            [
                Self.rawObservation(text: "038/193", confidence: 0.99),
                Self.rawObservation(text: "126/187", confidence: 0.99),
                Self.rawObservation(text: "RR", confidence: 0.98),
                Self.rawObservation(text: "HP100", confidence: 0.97),
                Self.rawObservation(text: "No0583", confidence: 0.96),
                Self.rawObservation(text: "2025 Pokemon/Nintendo", confidence: 0.95),
                Self.rawObservation(text: "   ", confidence: 0.94),
            ],
            [],
        ])
        let extractor = PokemonCardSetIDExtractor(recognizer: recognizer)

        let result = try await extractor.extractSetID(from: Self.image()).get()

        #expect(result.setID == nil)
        #expect(result.rawCandidates.count == 7)
    }

    @Test
    func `Should prefer valid set ID over higher confidence collector number`() async throws {
        let recognizer = FakeSetIDTextRecognizer(responses: [
            [
                Self.rawObservation(text: "038/193", confidence: 0.99),
                Self.rawObservation(text: "m2a", confidence: 0.45),
            ],
            [],
        ])
        let extractor = PokemonCardSetIDExtractor(recognizer: recognizer)

        let result = try await extractor.extractSetID(from: Self.image()).get()

        #expect(result.setID == "m2a")
    }

    @Test
    func `Should try fallback crop when primary crop has no set ID`() async throws {
        let recognizer = FakeSetIDTextRecognizer(responses: [
            [Self.rawObservation(text: "038/193", confidence: 0.99)],
            [
                Self.rawObservation(
                    text: "m2a",
                    confidence: 0.78,
                    box: CGRect(x: 0.03, y: 0.08, width: 0.18, height: 0.12)
                )
            ],
        ])
        let extractor = PokemonCardSetIDExtractor(recognizer: recognizer)

        let result = try await extractor.extractSetID(from: Self.image()).get()

        #expect(result.setID == "m2a")
        #expect(result.selectedCropLabel == "set-id-fallback-lower-left")
    }

    @Test
    func `Should use OCR configuration suitable for tiny set ID text`() async throws {
        let recognizer = FakeSetIDTextRecognizer(responses: [[], []])
        let extractor = PokemonCardSetIDExtractor(recognizer: recognizer)

        _ = try await extractor.extractSetID(from: Self.image()).get()

        let configurations = await recognizer.configurations
        #expect(configurations.count == 2)
        #expect(configurations.allSatisfy { $0.recognitionLevel == .accurate })
        #expect(configurations.allSatisfy { $0.automaticallyDetectsLanguage })
        #expect(configurations.allSatisfy { $0.recognitionLanguages.isEmpty })
        #expect(configurations.allSatisfy { $0.minimumTextHeight == 0.004 })
    }

    private static func image(size: CGSize = CGSize(width: 240, height: 336)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private static func rawObservation(
        text: String,
        confidence: Float,
        box: CGRect = CGRect(x: 0.05, y: 0.05, width: 0.18, height: 0.10),
        topCandidates: [PokemonCardTextCandidate]? = nil
    ) -> PokemonCardRawTextObservation {
        PokemonCardRawTextObservation(
            text: text,
            topCandidates: topCandidates ?? [PokemonCardTextCandidate(text: text, confidence: confidence)],
            confidence: confidence,
            boundingBox: box
        )
    }
}

private actor FakeSetIDTextRecognizer: PokemonCardTextRecognizing {
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
