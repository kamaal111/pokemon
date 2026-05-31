//
//  PokemonCardCameraControllerTests.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/31/26.
//

import CoreGraphics
import Testing

@testable import PokemonOcr

@Suite("PokemonCardCameraController Tests")
struct PokemonCardCameraControllerTests {
    private let coordinateTolerance = CGFloat(0.000001)

    @Test
    func `Should convert Vision portrait card center to device focus point`() {
        let point = PokemonCardCameraController.deviceFocusPoint(
            for: CGRect(x: 0.20, y: 0.30, width: 0.40, height: 0.20)
        )

        #expect(abs(point.x - 0.60) < coordinateTolerance)
        #expect(abs(point.y - 0.60) < coordinateTolerance)
    }

    @Test
    func `Should not mirror off center Vision card vertically when focusing`() {
        let upperCardPoint = PokemonCardCameraController.deviceFocusPoint(
            for: CGRect(x: 0.35, y: 0.70, width: 0.20, height: 0.20)
        )
        let lowerCardPoint = PokemonCardCameraController.deviceFocusPoint(
            for: CGRect(x: 0.35, y: 0.10, width: 0.20, height: 0.20)
        )

        #expect(abs(upperCardPoint.x - 0.20) < coordinateTolerance)
        #expect(abs(upperCardPoint.y - 0.55) < coordinateTolerance)
        #expect(abs(lowerCardPoint.x - 0.80) < coordinateTolerance)
        #expect(abs(lowerCardPoint.y - 0.55) < coordinateTolerance)
    }

    @Test
    func `Should clamp device focus point to camera coordinate bounds`() {
        let point = PokemonCardCameraController.deviceFocusPoint(
            for: CGRect(x: -0.30, y: 0.90, width: 0.20, height: 0.40)
        )

        #expect(abs(point.x - 0) < coordinateTolerance)
        #expect(abs(point.y - 1) < coordinateTolerance)
    }
}
