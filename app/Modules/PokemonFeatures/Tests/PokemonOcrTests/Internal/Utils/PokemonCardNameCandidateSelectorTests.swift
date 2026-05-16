//
//  PokemonCardNameCandidateSelectorTests.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/16/26.
//

import CoreGraphics
import Testing

@testable import PokemonOcr

@Suite("PokemonCardNameCandidateSelector Tests")
struct PokemonCardNameCandidateSelectorTests {
    @Test
    func `Should ignore junk candidates and choose supported script candidate`() {
        let candidates = [
            PokemonOcrCandidate(text: "HP 70", confidence: 0.99, boundingBox: .zero),
            PokemonOcrCandidate(text: "기본", confidence: 0.98, boundingBox: .zero),
            PokemonOcrCandidate(text: "リザード", confidence: 0.77, boundingBox: .zero),
        ]

        let selectedCandidate = PokemonCardNameCandidateSelector.chooseBestCandidate(
            from: candidates,
            preferredRegion: nil
        )

        #expect(selectedCandidate?.normalizedText == "リザード")
    }

    @Test
    func `Should preserve valid suffix candidates`() {
        let candidates = [
            PokemonOcrCandidate(text: "Charizard VMAX", confidence: 0.88, boundingBox: .zero),
            PokemonOcrCandidate(text: "Stage 1", confidence: 0.92, boundingBox: .zero),
        ]

        let selectedCandidate = PokemonCardNameCandidateSelector.chooseBestCandidate(
            from: candidates,
            preferredRegion: nil
        )

        #expect(selectedCandidate?.normalizedText == "Charizard VMAX")
    }

    @Test
    func `Should prefer title candidate inside preferred region`() {
        let preferredRegion = CGRect(x: 0.12, y: 0.87, width: 0.63, height: 0.11)
        let candidates = [
            PokemonOcrCandidate(
                text: "ヒトカゲから進化",
                confidence: 0.92,
                boundingBox: CGRect(x: 0.18, y: 0.82, width: 0.28, height: 0.03)
            ),
            PokemonOcrCandidate(
                text: "リザード",
                confidence: 0.50,
                boundingBox: CGRect(x: 0.23, y: 0.90, width: 0.19, height: 0.05)
            ),
        ]

        let selectedCandidate = PokemonCardNameCandidateSelector.chooseBestCandidate(
            from: candidates,
            preferredRegion: preferredRegion
        )

        #expect(selectedCandidate?.normalizedText == "リザード")
    }

    @Test
    func `Should reject numeric only candidates even inside preferred region`() {
        let preferredRegion = CGRect(x: 0.12, y: 0.87, width: 0.63, height: 0.11)
        let candidates = [
            PokemonOcrCandidate(
                text: "12846",
                confidence: 0.99,
                boundingBox: CGRect(x: 0.24, y: 0.90, width: 0.10, height: 0.04)
            ),
            PokemonOcrCandidate(
                text: "ホップのカビゴン",
                confidence: 0.50,
                boundingBox: CGRect(x: 0.22, y: 0.87, width: 0.31, height: 0.04)
            ),
        ]

        let selectedCandidate = PokemonCardNameCandidateSelector.chooseBestCandidate(
            from: candidates,
            preferredRegion: preferredRegion
        )

        #expect(selectedCandidate?.normalizedText == "ホップのカビゴン")
    }

    @Test
    func `Should support English titles without requiring suffixes`() {
        let preferredRegion = CGRect(x: 0.12, y: 0.87, width: 0.63, height: 0.11)
        let candidates = [
            PokemonOcrCandidate(
                text: "90",
                confidence: 0.99,
                boundingBox: CGRect(x: 0.68, y: 0.91, width: 0.05, height: 0.04)
            ),
            PokemonOcrCandidate(
                text: "Charmeleon",
                confidence: 0.58,
                boundingBox: CGRect(x: 0.18, y: 0.88, width: 0.22, height: 0.04)
            ),
        ]

        let selectedCandidate = PokemonCardNameCandidateSelector.chooseBestCandidate(
            from: candidates,
            preferredRegion: preferredRegion
        )

        #expect(selectedCandidate?.normalizedText == "Charmeleon")
    }

    @Test
    func `Should reject noisy latin suffixes attached to junk mixed script`() {
        #expect(PokemonCardNameCandidateSelector.hasValidLatinSuffixForTesting("ホゲータex"))
        #expect(PokemonCardNameCandidateSelector.hasValidLatinSuffixForTesting("Charizard VMAX"))
        #expect(!PokemonCardNameCandidateSelector.hasValidLatinSuffixForTesting("한70NEUV"))
        #expect(!PokemonCardNameCandidateSelector.hasValidLatinSuffixForTesting("MewtwoGX"))
    }
}
