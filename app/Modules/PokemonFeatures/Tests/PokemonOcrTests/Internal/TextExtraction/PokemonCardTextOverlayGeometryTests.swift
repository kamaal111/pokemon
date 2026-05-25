//
//  PokemonCardTextOverlayGeometryTests.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/25/26.
//

import CoreGraphics
import Testing

@testable import PokemonOcr

@Suite("PokemonCardTextOverlayGeometry Tests")
struct PokemonCardTextOverlayGeometryTests {
    @Test
    func `Should map Vision normalized boxes onto aspect-fit crop dimensions`() {
        let rect = PokemonCardTextOverlayGeometry.displayRect(
            for: CGRect(x: 0.25, y: 0.50, width: 0.50, height: 0.25),
            imageSize: CGSize(width: 100, height: 200),
            containerSize: CGSize(width: 200, height: 200)
        )

        #expect(rect == CGRect(x: 75, y: 50, width: 50, height: 50))
    }
}
