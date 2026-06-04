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
        let frenchWords = PokemonOcrLexicon.customWords(for: [.frenchFrance])
        let germanWords = PokemonOcrLexicon.customWords(for: [.germanGermany])
        let italianWords = PokemonOcrLexicon.customWords(for: [.italianItaly])
        let spanishWords = PokemonOcrLexicon.customWords(for: [.spanishSpain])

        #expect(japaneseWords.contains("リザード"))
        #expect(japaneseWords.contains("カビゴン"))
        #expect(koreanWords.contains("이브이"))
        #expect(englishWords.contains("Charmeleon"))
        #expect(englishWords.contains("Lizardon"))
        #expect(frenchWords.contains("Dracaufeu"))
        #expect(germanWords.contains("Glurak"))
        #expect(italianWords.contains("Charizard"))
        #expect(spanishWords.contains("Charizard"))
    }
}
