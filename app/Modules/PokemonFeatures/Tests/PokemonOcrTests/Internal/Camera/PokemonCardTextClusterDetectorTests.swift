//
//  PokemonCardTextClusterDetectorTests.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/18/26.
//

import CoreGraphics
import Testing

@testable import PokemonOcr

@Suite("PokemonCardTextClusterDetector Tests")
struct PokemonCardTextClusterDetectorTests {
    @Test
    func `Should infer card detection from clear text cluster`() {
        let detection = PokemonCardTextClusterDetector.bestDetection(from: [
            observation(x: 0.24, y: 0.54, width: 0.18, height: 0.035),
            observation(x: 0.28, y: 0.39, width: 0.24, height: 0.04),
            observation(x: 0.24, y: 0.32, width: 0.28, height: 0.03),
            observation(x: 0.25, y: 0.18, width: 0.24, height: 0.025),
        ])

        #expect(detection != nil)
        #expect((detection?.boundingBox.width ?? 0) > 0.35)
        #expect((detection?.boundingBox.height ?? 0) > 0.45)
    }

    @Test
    func `Should ignore single text observation`() {
        let detection = PokemonCardTextClusterDetector.bestDetection(from: [
            observation(x: 0.24, y: 0.54, width: 0.18, height: 0.035)
        ])

        #expect(detection == nil)
    }

    @Test
    func `Should ignore tiny text clusters`() {
        let detection = PokemonCardTextClusterDetector.bestDetection(from: [
            observation(x: 0.24, y: 0.54, width: 0.02, height: 0.01),
            observation(x: 0.27, y: 0.54, width: 0.02, height: 0.01),
            observation(x: 0.30, y: 0.54, width: 0.02, height: 0.01),
        ])

        #expect(detection == nil)
    }
}

private func observation(
    x: CGFloat,
    y: CGFloat,
    width: CGFloat,
    height: CGFloat,
    confidence: Float = 0.8
) -> PokemonCardTextClusterObservation {
    PokemonCardTextClusterObservation(
        boundingBox: CGRect(x: x, y: y, width: width, height: height),
        confidence: confidence
    )
}
