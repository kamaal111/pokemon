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
        #expect(resolver.resolveTitle(for: try sampleImage("insect-chinese")) == "音箱蟀")
        #expect(resolver.resolveTitle(for: try sampleImage("shiny-charmeleon")) == "リザード")
        #expect(resolver.resolveTitle(for: try sampleImage("trainers-ghost")) == "黑夜魔靈")
        #expect(resolver.resolveTitle(for: try sampleImage("trainers-snorlax")) == "ホップのカビゴン")
        #expect(resolver.resolveTitle(for: try sampleImage("trainers-wold")) == "Nのゾロアークex")
    }

    @Test
    func `Should load bundled sample card images for every picker option`() throws {
        for sampleCard in PokemonOcrSampleCard.allCases {
            let image = sampleCard.image

            #expect(image.size.width > 0)
            #expect(image.size.height > 0)
        }
    }
}
