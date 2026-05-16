//
//  PokemonOcrKnownSampleResolverTests.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/16/26.
//

import Testing

@testable import PokemonOcr

@Suite("PokemonOcrKnownSampleResolver Tests")
struct PokemonOcrKnownSampleResolverTests {
    @Test
    func `Should resolve bundled sample images to canonical OCR titles`() throws {
        let resolver = PokemonOcrKnownSampleResolver()

        #expect(resolver.resolveTitle(for: try sampleImage("eevee")) == "이브이ex")
        #expect(resolver.resolveTitle(for: try sampleImage("shiny-charmeleon")) == "リザード")
        #expect(resolver.resolveTitle(for: try sampleImage("trainers-snorlax")) == "ホップのカビゴン")
    }
}
