//
//  PokemonCardTitleCropperTests.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/16/26.
//

import Testing
import UIKit

@testable import PokemonOcr

@Suite("PokemonCardTitleCropper Tests")
struct PokemonCardTitleCropperTests {
    @Test
    func `Should calculate title rect from configured ratios`() {
        let rect = PokemonCardTitleCropper.titleRect(for: CGSize(width: 1_000, height: 1_400))

        #expect(rect.origin.x == 120)
        #expect(rect.origin.y == 28)
        #expect(rect.width == 630)
        #expect(rect.height == 154)
    }

    @Test
    func `Should keep title rect inside image bounds`() {
        let rect = PokemonCardTitleCropper.titleRect(
            for: CGSize(width: 500, height: 700),
            configuration: .init(xMin: -0.2, xMax: 1.2, yMin: -0.1, yMax: 0.2)
        )

        #expect(rect.minX == 0)
        #expect(rect.minY == 0)
        #expect(rect.maxX == 500)
        #expect(abs(rect.maxY - 140) < 0.001)
    }

    @Test
    func `Should crop non-empty image from sample card`() throws {
        let cropResult = PokemonCardTitleCropper.cropTitle(from: try sampleImage("eevee"))
        let crop = try cropResult.get()

        #expect(crop.image.size.width > 0)
        #expect(crop.image.size.height > 0)
        #expect(crop.rect.width > 0)
        #expect(crop.rect.height > 0)
    }

    @Test
    func `Should convert title rect into Vision observation region`() {
        let region = PokemonCardTitleCropper.titleObservationRegion(
            for: CGSize(width: 1_000, height: 1_400)
        )

        #expect(abs(region.minX - 0.12) < 0.001)
        #expect(abs(region.minY - 0.87) < 0.001)
        #expect(abs(region.width - 0.63) < 0.001)
        #expect(abs(region.height - 0.11) < 0.001)
    }

    @Test
    func `Should expand title region into OCR search band`() {
        let region = PokemonCardTitleCropper.titleSearchRegion(for: CGSize(width: 1_000, height: 1_400))

        #expect(abs(region.minX - 0.06) < 0.001)
        #expect(abs(region.minY - 0.80) < 0.001)
        #expect(abs(region.maxX - 0.81) < 0.001)
        #expect(abs(region.maxY - 1.00) < 0.001)
    }
}
