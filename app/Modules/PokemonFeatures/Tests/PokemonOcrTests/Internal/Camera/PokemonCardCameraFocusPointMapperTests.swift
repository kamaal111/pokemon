//
//  PokemonCardCameraFocusPointMapperTests.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/18/26.
//

import CoreGraphics
import Testing

@testable import PokemonOcr

@Suite("PokemonCardCameraFocusPointMapper Tests")
struct PokemonCardCameraFocusPointMapperTests {
    @Test
    func `Should convert Vision card center into camera focus point`() {
        let detection = PokemonCardShapeDetection(
            boundingBox: CGRect(x: 0.2, y: 0.3, width: 0.4, height: 0.5),
            confidence: 0.9
        )

        let point = PokemonCardCameraFocusPointMapper.devicePoint(for: detection)

        #expect(point.x == 0.4)
        #expect(abs(point.y - 0.45) < 0.0001)
    }
}
