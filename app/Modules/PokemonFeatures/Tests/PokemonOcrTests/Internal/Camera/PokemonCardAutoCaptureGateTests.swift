//
//  PokemonCardAutoCaptureGateTests.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/17/26.
//

import CoreGraphics
import Testing

@testable import PokemonOcr

@Suite("PokemonCardAutoCaptureGate Tests")
struct PokemonCardAutoCaptureGateTests {
    @Test
    func `Should capture once after required stable detections`() {
        var gate = PokemonCardAutoCaptureGate(requiredStableDetectionCount: 3)
        let detection = cardDetection()

        let firstDetectionCapture = gate.shouldCapture(after: detection)
        let secondDetectionCapture = gate.shouldCapture(after: detection)
        let thirdDetectionCapture = gate.shouldCapture(after: detection)
        let fourthDetectionCapture = gate.shouldCapture(after: detection)

        #expect(!firstDetectionCapture)
        #expect(!secondDetectionCapture)
        #expect(thirdDetectionCapture)
        #expect(!fourthDetectionCapture)
    }

    @Test
    func `Should reset stability when detection disappears`() {
        var gate = PokemonCardAutoCaptureGate(requiredStableDetectionCount: 2)
        let detection = cardDetection()

        let firstDetectionCapture = gate.shouldCapture(after: detection)
        let missingDetectionCapture = gate.shouldCapture(after: nil)
        let secondDetectionCapture = gate.shouldCapture(after: detection)
        let thirdDetectionCapture = gate.shouldCapture(after: detection)

        #expect(!firstDetectionCapture)
        #expect(!missingDetectionCapture)
        #expect(!secondDetectionCapture)
        #expect(thirdDetectionCapture)
    }

    @Test
    func `Should reset after capture for another scan`() {
        var gate = PokemonCardAutoCaptureGate(requiredStableDetectionCount: 1)
        let detection = cardDetection()

        let firstDetectionCapture = gate.shouldCapture(after: detection)
        gate.reset()
        let detectionAfterResetCapture = gate.shouldCapture(after: detection)

        #expect(firstDetectionCapture)
        #expect(detectionAfterResetCapture)
    }

    @Test
    func `Should restart stability when card moves too far`() {
        var gate = PokemonCardAutoCaptureGate(requiredStableDetectionCount: 2)

        let firstDetectionCapture = gate.shouldCapture(after: cardDetection(x: 0.1, y: 0.1))
        let movedDetectionCapture = gate.shouldCapture(after: cardDetection(x: 0.4, y: 0.4))
        let stableMovedDetectionCapture = gate.shouldCapture(after: cardDetection(x: 0.4, y: 0.4))

        #expect(!firstDetectionCapture)
        #expect(!movedDetectionCapture)
        #expect(stableMovedDetectionCapture)
    }
}

private func cardDetection(
    x: CGFloat = 0.1,
    y: CGFloat = 0.1,
    width: CGFloat = 0.5,
    height: CGFloat = 0.7
) -> PokemonCardShapeDetection {
    PokemonCardShapeDetection(
        boundingBox: CGRect(x: x, y: y, width: width, height: height),
        confidence: 0.9
    )
}
