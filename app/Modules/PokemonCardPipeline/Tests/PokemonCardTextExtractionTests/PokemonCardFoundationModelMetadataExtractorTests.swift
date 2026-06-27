//
//  PokemonCardFoundationModelMetadataExtractorTests.swift
//  PokemonCardPipeline
//
//  Created by Codex on 6/27/26.
//

import Testing

@testable import PokemonCardTextExtraction

@Suite("PokemonCardFoundationModelMetadataExtractor Tests")
struct PokemonCardFoundationModelMetadataExtractorTests {
    @Test
    func `Should normalize Pokemon card set identifiers`() {
        #expect(PokemonCardFoundationModelMetadataNormalizer.normalizedSetID("sv8a") == "sv8a")
        #expect(PokemonCardFoundationModelMetadataNormalizer.normalizedSetID(" SV8A ") == "sv8a")
        #expect(PokemonCardFoundationModelMetadataNormalizer.normalizedSetID("m2a") == "m2a")
        #expect(PokemonCardFoundationModelMetadataNormalizer.normalizedSetID(" M2A ") == "m2a")
    }

    @Test
    func `Should reject non set identifier text`() {
        #expect(PokemonCardFoundationModelMetadataNormalizer.normalizedSetID("126/187") == nil)
        #expect(PokemonCardFoundationModelMetadataNormalizer.normalizedSetID("RR") == nil)
        #expect(PokemonCardFoundationModelMetadataNormalizer.normalizedSetID("HP100") == nil)
        #expect(PokemonCardFoundationModelMetadataNormalizer.normalizedSetID("No0583") == nil)
        #expect(PokemonCardFoundationModelMetadataNormalizer.normalizedSetID("") == nil)
        #expect(PokemonCardFoundationModelMetadataNormalizer.normalizedSetID("   ") == nil)
        #expect(PokemonCardFoundationModelMetadataNormalizer.normalizedSetID("sv 8a") == nil)
    }

    @Test
    func `Should extract set identifier from OCR evidence`() {
        let evidence =
            """
            Top title/name area: Nのバニリッチ, HP 100.
            Bottom-left set-code area: black rounded rectangle reads m2a.
            Nearby collector number: 038/193.
            """

        #expect(PokemonCardFoundationModelMetadataNormalizer.normalizedSetID(fromEvidence: evidence) == "m2a")
    }

    @Test
    func `Should ignore collector number when extracting set identifier from evidence`() {
        let evidence =
            """
            Bottom-left area: 038/193.
            Rarity and copyright are visible.
            """

        #expect(PokemonCardFoundationModelMetadataNormalizer.normalizedSetID(fromEvidence: evidence) == nil)
    }

    @Test
    func `Should preserve non Latin Pokemon names`() {
        #expect(PokemonCardFoundationModelMetadataNormalizer.normalizedPokemonName(" 이브이ex ") == "이브이ex")
        #expect(PokemonCardFoundationModelMetadataNormalizer.normalizedPokemonName("リザード") == "リザード")
        #expect(PokemonCardFoundationModelMetadataNormalizer.normalizedPokemonName("黑夜魔靈") == "黑夜魔靈")
    }

    @Test
    func `Should return normalized result when either metadata field is present`() {
        let fullResult = PokemonCardFoundationModelMetadataNormalizer.normalizedResult(
            pokemonName: " 이브이ex ",
            setID: "SV8A"
        )
        let nameOnlyResult = PokemonCardFoundationModelMetadataNormalizer.normalizedResult(
            pokemonName: "리자몽",
            setID: "126/187"
        )

        #expect(fullResult == PokemonCardMetadataExtractionResult(pokemonName: "이브이ex", setID: "sv8a"))
        #expect(nameOnlyResult == PokemonCardMetadataExtractionResult(pokemonName: "리자몽", setID: nil))
        #expect(PokemonCardFoundationModelMetadataNormalizer.normalizedResult(pokemonName: nil, setID: nil) == nil)
    }

    @Test
    func `Should resolve set identifier with deterministic OCR precedence`() {
        let ocrResult = PokemonCardSetIDExtractionResult(
            setID: "m2a",
            rawCandidates: ["038/193", "m2a"],
            selectedCropLabel: "set-id-primary-bottom-left",
            debugImages: []
        )
        let evidence = "Bottom-left set-code area: black rounded rectangle reads sv8a."

        let setID = PokemonCardFoundationModelMetadataNormalizer.resolvedSetID(
            setIDOCRResult: ocrResult,
            structuredSetID: "038/193",
            evidence: evidence
        )

        #expect(setID == "m2a")
    }

    @Test
    func `Should resolve set identifier from Foundation Models when OCR finds nothing`() {
        let ocrResult = PokemonCardSetIDExtractionResult(
            setID: nil,
            rawCandidates: ["038/193"],
            selectedCropLabel: nil,
            debugImages: []
        )

        let setID = PokemonCardFoundationModelMetadataNormalizer.resolvedSetID(
            setIDOCRResult: ocrResult,
            structuredSetID: "SV8A",
            evidence: "Bottom-left area includes 038/193."
        )

        #expect(setID == "sv8a")
    }

    @Test
    func `Should resolve set identifier from evidence when structured metadata is invalid`() {
        let setID = PokemonCardFoundationModelMetadataNormalizer.resolvedSetID(
            setIDOCRResult: nil,
            structuredSetID: "038/193",
            evidence: "Bottom-left set-code area: black rounded rectangle reads m2a."
        )

        #expect(setID == "m2a")
    }

    @Test
    func `Should select simulator safe metadata strategy`() {
        #if os(iOS) && !targetEnvironment(simulator)
            #expect(PokemonCardFoundationModelMetadataStrategy.current == .ocrTool)
        #else
            #expect(PokemonCardFoundationModelMetadataStrategy.current == .directImagePrompt)
        #endif
    }
}
