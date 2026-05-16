//
//  PokemonCardTitleNormalizerTests.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/16/26.
//

import Testing

@testable import PokemonOcr

@Suite("PokemonCardTitleNormalizer Tests")
struct PokemonCardTitleNormalizerTests {
    @Test
    func `Should normalize card title text conservatively`() {
        let cases = [
            ("이브이e", "이브이ex"),
            ("이브이 e", "이브이ex"),
            ("이브이eX", "이브이ex"),
            ("ピカチュウEX", "ピカチュウex"),
            ("ホップ の カビゴン", "ホップのカビゴン"),
            ("ピカチュウｅ", "ピカチュウex"),
            ("リザード", "リザード"),
            ("Charizard VMAX", "Charizard VMAX"),
            ("  Charizard   GX\n", "Charizard GX"),
        ]

        for (input, expectedOutput) in cases {
            #expect(PokemonCardTitleNormalizer.normalize(input) == expectedOutput)
        }
    }
}
