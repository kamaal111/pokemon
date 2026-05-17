//
//  PokemonCardShapeDetectorTests.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/17/26.
//

import CoreGraphics
import Testing

@testable import PokemonOcr

@Suite("PokemonCardShapeDetector Tests")
struct PokemonCardShapeDetectorTests {
    @Test
    func `Should accept portrait rectangle with Pokemon card aspect ratio`() {
        let detection = PokemonCardShapeDetector.bestDetection(from: [
            observation(x: 0.15, y: 0.1, width: 0.315, height: 0.44)
        ])

        #expect(detection?.boundingBox == CGRect(x: 0.15, y: 0.1, width: 0.315, height: 0.44))
    }

    @Test
    func `Should accept perspective skew near Pokemon card aspect ratio`() {
        let detection = PokemonCardShapeDetector.bestDetection(from: [
            observation(width: 0.28, height: 0.5)
        ])

        #expect(detection?.boundingBox == CGRect(x: 0, y: 0, width: 0.28, height: 0.5))
    }

    @Test
    func `Should return candidate rectangles for the debug overlay`() {
        let candidates = PokemonCardShapeDetector.candidates(from: [
            observation(x: 0.15, y: 0.1, width: 0.315, height: 0.44),
            observation(width: 0.7, height: 0.5),
        ])

        #expect(
            candidates == [
                PokemonCardShapeDetection(
                    boundingBox: CGRect(x: 0.15, y: 0.1, width: 0.315, height: 0.44),
                    confidence: 0.9
                )
            ])
    }

    @Test
    func `Should choose card candidate that contains readable text`() {
        let couchCandidate = cardDetection(x: 0.1, y: 0.05, width: 0.5, height: 0.7)
        let cardCandidate = cardDetection(x: 0.25, y: 0.25, width: 0.35, height: 0.49)

        let detection = PokemonCardShapeDetector.bestDetection(
            from: [couchCandidate, cardCandidate],
            overlapping: [
                CGRect(x: 0.32, y: 0.56, width: 0.16, height: 0.04),
                CGRect(x: 0.33, y: 0.45, width: 0.18, height: 0.05),
            ]
        )

        #expect(detection == cardCandidate)
    }

    @Test
    func `Should reject shape candidates without readable text overlap`() {
        let detection = PokemonCardShapeDetector.bestDetection(
            from: [cardDetection(x: 0.1, y: 0.05, width: 0.5, height: 0.7)],
            overlapping: [
                CGRect(x: 0.72, y: 0.78, width: 0.12, height: 0.04),
                CGRect(x: 0.73, y: 0.7, width: 0.12, height: 0.04),
            ]
        )

        #expect(detection == nil)
    }

    @Test
    func `Should reject landscape rectangles`() {
        let detection = PokemonCardShapeDetector.bestDetection(from: [
            observation(width: 0.7, height: 0.5)
        ])

        #expect(detection == nil)
    }

    @Test
    func `Should reject rectangles outside aspect ratio tolerance`() {
        let detection = PokemonCardShapeDetector.bestDetection(from: [
            observation(width: 0.2, height: 0.9)
        ])

        #expect(detection == nil)
    }

    @Test
    func `Should reject rectangles below minimum area`() {
        let detection = PokemonCardShapeDetector.bestDetection(from: [
            observation(width: 0.05, height: 0.07)
        ])

        #expect(detection == nil)
    }

    @Test
    func `Should accept smaller readable card rectangles`() {
        let detection = PokemonCardShapeDetector.bestDetection(from: [
            observation(x: 0.35, y: 0.25, width: 0.2, height: 0.28)
        ])

        #expect(detection?.boundingBox == CGRect(x: 0.35, y: 0.25, width: 0.2, height: 0.28))
    }

    @Test
    func `Should choose largest valid rectangle`() {
        let detection = PokemonCardShapeDetector.bestDetection(from: [
            observation(x: 0.2, y: 0.2, width: 0.32, height: 0.45),
            observation(x: 0.1, y: 0.1, width: 0.5, height: 0.7),
        ])

        #expect(detection?.boundingBox == CGRect(x: 0.1, y: 0.1, width: 0.5, height: 0.7))
    }
}

private func observation(
    x: CGFloat = 0,
    y: CGFloat = 0,
    width: CGFloat,
    height: CGFloat,
    confidence: Float = 0.9
) -> PokemonCardShapeObservation {
    PokemonCardShapeObservation(
        boundingBox: CGRect(x: x, y: y, width: width, height: height),
        confidence: confidence
    )
}

private func cardDetection(
    x: CGFloat,
    y: CGFloat,
    width: CGFloat,
    height: CGFloat
) -> PokemonCardShapeDetection {
    PokemonCardShapeDetection(
        boundingBox: CGRect(x: x, y: y, width: width, height: height),
        confidence: 0.9
    )
}
