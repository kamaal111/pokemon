//
//  PokemonCardNameVisionEvaluationTests.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/16/26.
//

import Testing

@testable import PokemonOcr

@MainActor
@Suite("PokemonCardName Vision Evaluation Tests")
struct PokemonCardNameVisionEvaluationTests {
    @Test
    func `Should extract expected titles from sample card images`() async throws {
        let cases = [
            ("eevee", "이브이ex"),
            ("insect-chinese", "音箱蟀"),
            ("shiny-charmeleon", "リザード"),
            ("trainers-ghost", "黑夜魔靈"),
            ("trainers-snorlax", "ホップのカビゴン"),
            ("trainers-wold", "Nのゾロアークex"),
        ]
        let extractor = PokemonCardNameExtractor()

        for (sampleName, expectedTitle) in cases {
            let extractionResult = await extractor.extractName(from: try sampleImage(sampleName))
            let result = try extractionResult.get()
            #expect(result.normalizedTitle == expectedTitle)
        }
    }
}
