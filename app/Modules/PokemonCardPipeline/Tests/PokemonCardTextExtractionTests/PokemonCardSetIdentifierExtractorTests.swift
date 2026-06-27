//
//  PokemonCardSetIdentifierExtractorTests.swift
//  PokemonCardPipeline
//
//  Created by Codex on 6/10/26.
//

import Testing
import UIKit
import Vision

@testable import PokemonCardTextExtraction

@Suite("PokemonCardSetIdentifierExtractor Tests")
struct PokemonCardSetIdentifierExtractorTests {
    @Test
    func `Should load bundled set identifier lexicon`() {
        #expect(PokemonCardSetIdentifierLexicon.contains("sv8a"))
        #expect(PokemonCardSetIdentifierLexicon.contains("sv4a"))
        #expect(PokemonCardSetIdentifierLexicon.contains("m2a"))
        #expect(PokemonCardSetIdentifierLexicon.contains("m4"))
        #expect(PokemonCardSetIdentifierLexicon.contains("sv8"))
        #expect(PokemonCardSetIdentifierLexicon.contains("mew"))
        #expect(PokemonCardSetIdentifierLexicon.contains("ssp"))
    }

    @Test
    func `Should normalize Scarlet Violet set identifiers`() {
        #expect(PokemonCardSetIdentifierExtractor.normalizedSetIdentifier(from: "SV8A") == "sv8a")
        #expect(PokemonCardSetIdentifierExtractor.normalizedSetIdentifier(from: "SV 8a") == "sv8a")
        #expect(PokemonCardSetIdentifierExtractor.normalizedSetIdentifier(from: "• SV-8A / 217") == "sv8a")
    }

    @Test
    func `Should normalize Mega set identifiers`() {
        #expect(PokemonCardSetIdentifierExtractor.normalizedSetIdentifier(from: "M2A") == "m2a")
        #expect(PokemonCardSetIdentifierExtractor.normalizedSetIdentifier(from: "M 2a") == "m2a")
        #expect(PokemonCardSetIdentifierExtractor.normalizedSetIdentifier(from: "M2a 171/193") == "m2a")
        #expect(PokemonCardSetIdentifierExtractor.normalizedSetIdentifier(from: "M4") == "m4")
        #expect(PokemonCardSetIdentifierExtractor.normalizedSetIdentifier(from: "M 4") == "m4")
        #expect(PokemonCardSetIdentifierExtractor.normalizedSetIdentifier(from: "M4 014/083 C") == "m4")
        #expect(PokemonCardSetIdentifierExtractor.normalizedSetIdentifier(from: "M4014/083C") == "m4")
        #expect(PokemonCardSetIdentifierExtractor.normalizedSetIdentifier(from: "JM4") == "m4")
    }

    @Test
    func `Should normalize English set identifiers`() {
        #expect(PokemonCardSetIdentifierExtractor.normalizedSetIdentifier(from: "SV8") == "sv8")
        #expect(PokemonCardSetIdentifierExtractor.normalizedSetIdentifier(from: "SV3PT5") == "sv3pt5")
        #expect(PokemonCardSetIdentifierExtractor.normalizedSetIdentifier(from: "MEW EN 151/165") == "mew")
        #expect(PokemonCardSetIdentifierExtractor.normalizedSetIdentifier(from: "S S P 001/191") == "ssp")
    }

    @Test
    func `Should reject non set identifier text`() {
        #expect(PokemonCardSetIdentifierExtractor.normalizedSetIdentifier(from: "217/187") == nil)
        #expect(PokemonCardSetIdentifierExtractor.normalizedSetIdentifier(from: "Eevee ex") == nil)
        #expect(PokemonCardSetIdentifierExtractor.normalizedSetIdentifier(from: "HP 260") == nil)
        #expect(PokemonCardSetIdentifierExtractor.normalizedSetIdentifier(from: "M3Z") == nil)
        #expect(PokemonCardSetIdentifierExtractor.normalizedSetIdentifier(from: "M4A") == nil)
        #expect(PokemonCardSetIdentifierExtractor.normalizedSetIdentifier(from: "123M4") == nil)
    }

    @Test
    func `Should recognize set identifier from enhanced bottom left crop`() async throws {
        let recognizer = SetIdentifierFakeTextRecognizer(responses: [
            [rawSetIdentifierObservation(text: "SV 8a", confidence: 0.92)]
        ])
        let extractor = PokemonCardSetIdentifierExtractor(
            recognizer: recognizer,
            languageProvider: SetIdentifierStaticLanguageProvider(languages: ["en-US", "ja-JP"])
        )
        let image = Self.image()

        let result = try await extractor.extractSetIdentifier(from: image).get()
        let configuration = try await #require(recognizer.configurations.first)
        let receivedImageSize = try await #require(recognizer.receivedImageSizes.first)

        #expect(result.setIdentifier == "sv8a")
        #expect(configuration.recognitionLevel == .accurate)
        #expect(configuration.automaticallyDetectsLanguage == false)
        #expect(configuration.recognitionLanguages == ["en-US"])
        #expect(configuration.usesLanguageCorrection == false)
        #expect(configuration.customWords.contains("sv8a"))
        #expect(configuration.customWords.contains("sv4a"))
        #expect(configuration.customWords.contains("m2a"))
        #expect(configuration.customWords.contains("m4"))
        #expect(configuration.customWords.contains("mew"))
        #expect(configuration.customWords.contains("ssp"))
        #expect(configuration.minimumTextHeight == 0)
        #expect(receivedImageSize.width > image.size.width)
        #expect(receivedImageSize.height < image.size.height)
    }

    @Test
    func `Should recognize Mega set identifier from enhanced bottom left crop`() async throws {
        let recognizer = SetIdentifierFakeTextRecognizer(responses: [
            [rawSetIdentifierObservation(text: "M2a 171/193", confidence: 0.92)]
        ])
        let extractor = PokemonCardSetIdentifierExtractor(
            recognizer: recognizer,
            languageProvider: SetIdentifierStaticLanguageProvider(languages: ["en-US", "ja-JP"])
        )

        let result = try await extractor.extractSetIdentifier(from: Self.image()).get()

        #expect(result.setIdentifier == "m2a")
    }

    @Test
    func `Should omit explicit language when English recognition is unsupported`() async throws {
        let recognizer = SetIdentifierFakeTextRecognizer(responses: [
            [rawSetIdentifierObservation(text: "SV4A", confidence: 0.90)]
        ])
        let extractor = PokemonCardSetIdentifierExtractor(
            recognizer: recognizer,
            languageProvider: SetIdentifierStaticLanguageProvider(languages: ["ja-JP"])
        )

        _ = try await extractor.extractSetIdentifier(from: Self.image()).get()
        let configuration = try await #require(recognizer.configurations.first)

        #expect(configuration.recognitionLanguages == [])
    }

    @Test
    func `Should recognize fallback set identifier from cropped bottom left region`() async throws {
        let recognizer = SetIdentifierFakeTextRecognizer(responses: [
            [],
            [],
            [],
            [rawSetIdentifierObservation(text: "SV4A", confidence: 0.90)],
        ])
        let extractor = PokemonCardSetIdentifierExtractor(
            recognizer: recognizer,
            languageProvider: SetIdentifierStaticLanguageProvider(languages: ["en-US", "ja-JP"])
        )
        let image = Self.image(size: CGSize(width: 1000, height: 1400))

        let result = try await extractor.extractSetIdentifier(from: image).get()
        let configurations = await recognizer.configurations
        let receivedImageSizes = await recognizer.receivedImageSizes
        let fallbackConfiguration = try #require(configurations.last)
        let fallbackImageSize = try #require(receivedImageSizes.last)

        #expect(result.setIdentifier == "sv4a")
        #expect(configurations.count == 4)
        #expect(fallbackConfiguration.automaticallyDetectsLanguage)
        #expect(fallbackConfiguration.regionOfInterest == nil)
        #expect(fallbackImageSize.width < image.size.width)
        #expect(fallbackImageSize.height < image.size.height)
    }

    private static func image(size: CGSize = CGSize(width: 240, height: 336)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

private actor SetIdentifierFakeTextRecognizer: PokemonCardTextRecognizing {
    private var responses: [[PokemonCardRawTextObservation]]
    private(set) var configurations: [PokemonCardTextRecognizerConfiguration] = []
    private(set) var receivedImageSizes: [CGSize] = []

    init(responses: [[PokemonCardRawTextObservation]]) {
        self.responses = responses
    }

    func recognizeText(
        in image: UIImage,
        configuration: PokemonCardTextRecognizerConfiguration
    ) async -> Result<[PokemonCardRawTextObservation], PokemonCardTextExtractionError> {
        configurations.append(configuration)
        receivedImageSizes.append(image.size)
        guard !responses.isEmpty else {
            return .success([])
        }

        return .success(responses.removeFirst())
    }
}

private struct SetIdentifierStaticLanguageProvider: PokemonCardTextRecognitionLanguageProviding {
    let languages: [String]

    func supportedRecognitionLanguages(
        recognitionLevel: VNRequestTextRecognitionLevel
    ) -> Result<[String], PokemonCardTextExtractionError> {
        .success(languages)
    }
}

private func rawSetIdentifierObservation(
    text: String,
    confidence: Float
) -> PokemonCardRawTextObservation {
    PokemonCardRawTextObservation(
        text: text,
        topCandidates: [PokemonCardTextCandidate(text: text, confidence: confidence)],
        confidence: confidence,
        boundingBox: .zero
    )
}
