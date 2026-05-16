//
//  PokemonOcrLexiconTests.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/16/26.
//

import Testing

@testable import PokemonOcr

@Suite("PokemonOcrLexicon Tests")
struct PokemonOcrLexiconTests {
    @Test
    func `Should provide custom words for supported OCR languages`() {
        let japaneseWords = PokemonOcrLexicon.customWords(for: [.japaneseJapan])
        let koreanWords = PokemonOcrLexicon.customWords(for: [.koreanKorea])
        let englishWords = PokemonOcrLexicon.customWords(for: [.englishUnitedStates])

        #expect(japaneseWords.contains("リザード"))
        #expect(japaneseWords.contains("カビゴン"))
        #expect(koreanWords.contains("이브이"))
        #expect(englishWords.contains("Charmeleon"))
    }
}
