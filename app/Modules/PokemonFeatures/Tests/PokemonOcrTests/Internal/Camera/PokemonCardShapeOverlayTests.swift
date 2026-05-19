//
//  PokemonCardShapeOverlayTests.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/24/26.
//

import CoreGraphics
import Testing

@testable import PokemonOcr

@Suite("PokemonCardShapeOverlay Tests")
struct PokemonCardShapeOverlayTests {
    @Test
    func `Should project portrait normalized rect into aspect fill preview`() {
        let rect = PokemonCardShapeOverlayGeometry.overlayRect(
            for: CGRect(x: 0.25, y: 0.25, width: 0.50, height: 0.50),
            frameSize: CGSize(width: 100, height: 200),
            viewSize: CGSize(width: 100, height: 100)
        )

        #expect(rect.minX == 25)
        #expect(rect.minY == 0)
        #expect(rect.width == 50)
        #expect(rect.height == 100)
    }

    @Test
    func `Should project landscape normalized rect into aspect fill preview`() {
        let rect = PokemonCardShapeOverlayGeometry.overlayRect(
            for: CGRect(x: 0.25, y: 0.25, width: 0.50, height: 0.50),
            frameSize: CGSize(width: 200, height: 100),
            viewSize: CGSize(width: 100, height: 100)
        )

        #expect(rect.minX == 0)
        #expect(rect.minY == 25)
        #expect(rect.width == 100)
        #expect(rect.height == 50)
    }

    @Test
    func `Should return zero rect for invalid frame size`() {
        let rect = PokemonCardShapeOverlayGeometry.overlayRect(
            for: CGRect(x: 0.25, y: 0.25, width: 0.50, height: 0.50),
            frameSize: .zero,
            viewSize: CGSize(width: 100, height: 100)
        )

        #expect(rect == .zero)
    }
}
