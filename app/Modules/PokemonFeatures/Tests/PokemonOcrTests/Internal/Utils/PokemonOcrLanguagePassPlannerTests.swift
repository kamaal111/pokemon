//
//  PokemonOcrLanguagePassPlannerTests.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/17/26.
//

import CoreGraphics
import Testing

@testable import PokemonOcr

@Suite("PokemonOcrLanguagePassPlanner Tests")
struct PokemonOcrLanguagePassPlannerTests {
    @Test
    func `Should rank Japanese first for katakana title with latin suffix`() {
        let passes = supplementalLanguagePasses(for: "リザードex")

        #expect(passes.first == [.japaneseJapan])
        #expect(passes.first != [.englishUnitedStates])
    }

    @Test
    func `Should rank Japanese first for title with Japanese joiner`() {
        let passes = supplementalLanguagePasses(for: "ホップのカビゴン")

        #expect(passes.first == [.japaneseJapan])
    }

    @Test
    func `Should rank Japanese first despite leading short latin fragment`() {
        let passes = supplementalLanguagePasses(for: "Nのゾロアーク")

        #expect(passes.first == [.japaneseJapan])
    }

    @Test
    func `Should rank Korean first for hangul title with latin suffix`() {
        let passes = supplementalLanguagePasses(for: "이브이ex")

        #expect(passes.first == [.koreanKorea])
    }

    @Test
    func `Should rank Chinese first for CJK only title with latin suffix`() {
        let passes = supplementalLanguagePasses(for: "音箱蟀ex")

        #expect(passes.first == [.chineseSimplified, .chineseTraditional])
    }

    @Test
    func `Should rank English first for latin title without East Asian evidence`() {
        let passes = supplementalLanguagePasses(for: "Charizard VMAX")

        #expect(passes.first == [.englishUnitedStates])
    }

    @Test
    func `Should preserve safe default order for empty candidates`() {
        let passes = PokemonOcrLanguagePassPlanner.supplementalLanguagePasses(
            for: [],
            selectedCandidate: nil
        )

        #expect(
            passes == [
                [.japaneseJapan],
                [.koreanKorea],
                [.chineseSimplified, .chineseTraditional],
                [.englishUnitedStates],
            ]
        )
    }

    private func supplementalLanguagePasses(for text: String) -> [[PokemonRecognitionLanguage]] {
        let candidate = PokemonOcrCandidate(
            text: text,
            confidence: 0.9,
            boundingBox: CGRect(x: 0.2, y: 0.88, width: 0.25, height: 0.05)
        )

        return PokemonOcrLanguagePassPlanner.supplementalLanguagePasses(
            for: [candidate],
            selectedCandidate: candidate
        )
    }
}
