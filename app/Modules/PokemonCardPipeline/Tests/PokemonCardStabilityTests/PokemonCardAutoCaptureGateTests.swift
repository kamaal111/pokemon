//
//  PokemonCardAutoCaptureGateTests.swift
//  PokemonCardPipeline
//
//  Created by Kamaal M Farah on 5/19/26.
//

import CoreGraphics
import Testing

@testable import PokemonCardDetection
@testable import PokemonCardFocusQuality
@testable import PokemonCardStability

@Suite("PokemonCardAutoCaptureGate Tests")
struct PokemonCardAutoCaptureGateTests {
    @Test
    func `Should trigger only after required stable detections`() {
        let gate = PokemonCardAutoCaptureGate()
        let detection = detection(rect: CGRect(x: 0.20, y: 0.15, width: 0.36, height: 0.50))
        let firstShouldCapture = gate.shouldCapture(detection)
        let secondShouldCapture = gate.shouldCapture(detection)
        let thirdShouldCapture = gate.shouldCapture(detection)

        #expect(!firstShouldCapture)
        #expect(!secondShouldCapture)
        #expect(thirdShouldCapture)
    }

    @Test
    func `Should reset stability on missing detection`() {
        let gate = PokemonCardAutoCaptureGate()
        let detection = detection(rect: CGRect(x: 0.20, y: 0.15, width: 0.36, height: 0.50))
        let firstShouldCapture = gate.shouldCapture(detection)
        let missingShouldCapture = gate.shouldCapture(nil)
        let secondShouldCapture = gate.shouldCapture(detection)
        let thirdShouldCapture = gate.shouldCapture(detection)
        let fourthShouldCapture = gate.shouldCapture(detection)

        #expect(!firstShouldCapture)
        #expect(!missingShouldCapture)
        #expect(!secondShouldCapture)
        #expect(!thirdShouldCapture)
        #expect(fourthShouldCapture)
    }

    @Test
    func `Should not repeatedly trigger after one successful capture`() {
        let gate = PokemonCardAutoCaptureGate()
        let detection = detection(rect: CGRect(x: 0.20, y: 0.15, width: 0.36, height: 0.50))
        let firstShouldCapture = gate.shouldCapture(detection)
        let secondShouldCapture = gate.shouldCapture(detection)
        let thirdShouldCapture = gate.shouldCapture(detection)
        let fourthShouldCapture = gate.shouldCapture(detection)
        let fifthShouldCapture = gate.shouldCapture(detection)

        #expect(!firstShouldCapture)
        #expect(!secondShouldCapture)
        #expect(thirdShouldCapture)
        #expect(!fourthShouldCapture)
        #expect(!fifthShouldCapture)
    }

    @Test
    func `Should restart stability when card moves too much`() {
        let gate = PokemonCardAutoCaptureGate()
        let first = detection(rect: CGRect(x: 0.20, y: 0.15, width: 0.36, height: 0.50))
        let moved = detection(rect: CGRect(x: 0.34, y: 0.29, width: 0.36, height: 0.50))
        let firstShouldCapture = gate.shouldCapture(first)
        let secondShouldCapture = gate.shouldCapture(first)
        let thirdShouldCapture = gate.shouldCapture(moved)
        let fourthShouldCapture = gate.shouldCapture(moved)
        let fifthShouldCapture = gate.shouldCapture(moved)

        #expect(!firstShouldCapture)
        #expect(!secondShouldCapture)
        #expect(!thirdShouldCapture)
        #expect(!fourthShouldCapture)
        #expect(fifthShouldCapture)
    }

    @Test
    func `Should tolerate small perspective jitter`() {
        let gate = PokemonCardAutoCaptureGate()
        let first = detection(rect: CGRect(x: 0.20, y: 0.15, width: 0.36, height: 0.50))
        let jittered = detection(rect: CGRect(x: 0.215, y: 0.16, width: 0.37, height: 0.48))
        let third = detection(rect: CGRect(x: 0.205, y: 0.145, width: 0.35, height: 0.51))
        let firstShouldCapture = gate.shouldCapture(first)
        let secondShouldCapture = gate.shouldCapture(jittered)
        let thirdShouldCapture = gate.shouldCapture(third)

        #expect(!firstShouldCapture)
        #expect(!secondShouldCapture)
        #expect(thirdShouldCapture)
    }

    @Test
    func `Should tolerate overlapping source switch shape changes`() {
        let gate = PokemonCardAutoCaptureGate()
        let vision = detection(rect: CGRect(x: 0.20, y: 0.15, width: 0.36, height: 0.50))
        let fallback = detection(rect: CGRect(x: 0.19, y: 0.14, width: 0.39, height: 0.52))
        let firstShouldCapture = gate.shouldCapture(vision)
        let secondShouldCapture = gate.shouldCapture(fallback)
        let thirdShouldCapture = gate.shouldCapture(vision)

        #expect(!firstShouldCapture)
        #expect(!secondShouldCapture)
        #expect(thirdShouldCapture)
    }

    @Test
    func `Should not trigger while stable detections are blurry`() {
        let gate = PokemonCardAutoCaptureGate()
        let card = detection(rect: CGRect(x: 0.20, y: 0.15, width: 0.36, height: 0.50))
        let blurry = PokemonCardFocusQualityReport.rejected(
            reason: .tooBlurry, normalizedRegion: PokemonCardFocusQualityAnalyzer.fullRegion)

        let firstShouldCapture = gate.shouldCapture(card, focusQuality: blurry)
        let secondShouldCapture = gate.shouldCapture(card, focusQuality: blurry)
        let thirdShouldCapture = gate.shouldCapture(card, focusQuality: blurry)
        let fourthShouldCapture = gate.shouldCapture(card, focusQuality: blurry)

        #expect(!firstShouldCapture)
        #expect(!secondShouldCapture)
        #expect(!thirdShouldCapture)
        #expect(!fourthShouldCapture)
    }

    @Test
    func `Should trigger after stable detections include consecutive focused frames`() {
        let gate = PokemonCardAutoCaptureGate()
        let card = detection(rect: CGRect(x: 0.20, y: 0.15, width: 0.36, height: 0.50))
        let blurry = PokemonCardFocusQualityReport.rejected(
            reason: .tooBlurry, normalizedRegion: PokemonCardFocusQualityAnalyzer.fullRegion)
        let focused = PokemonCardFocusQualityReport.focused()

        let firstShouldCapture = gate.shouldCapture(card, focusQuality: blurry)
        let secondShouldCapture = gate.shouldCapture(card, focusQuality: focused)
        let thirdShouldCapture = gate.shouldCapture(card, focusQuality: focused)

        #expect(!firstShouldCapture)
        #expect(!secondShouldCapture)
        #expect(thirdShouldCapture)
    }

    @Test
    func `Should wait while autofocus is adjusting`() {
        let gate = PokemonCardAutoCaptureGate()
        let card = detection(rect: CGRect(x: 0.20, y: 0.15, width: 0.36, height: 0.50))
        let focused = PokemonCardFocusQualityReport.focused()

        let firstShouldCapture = gate.shouldCapture(card, focusQuality: focused)
        let secondShouldCapture = gate.shouldCapture(card, focusQuality: focused, isFocusAdjusting: true)
        let thirdShouldCapture = gate.shouldCapture(card, focusQuality: focused, isFocusAdjusting: true)
        let fourthShouldCapture = gate.shouldCapture(card, focusQuality: focused)
        let fifthShouldCapture = gate.shouldCapture(card, focusQuality: focused)

        #expect(!firstShouldCapture)
        #expect(!secondShouldCapture)
        #expect(!thirdShouldCapture)
        #expect(!fourthShouldCapture)
        #expect(fifthShouldCapture)
    }

    private func detection(rect: CGRect) -> PokemonCardShapeDetection {
        PokemonCardShapeDetection(normalizedBoundingBox: rect, confidence: 0.80)
    }
}

extension PokemonCardAutoCaptureGate {
    fileprivate func shouldCapture(
        _ detection: PokemonCardShapeDetection?,
        focusQuality: PokemonCardFocusQualityReport? = nil,
        isFocusAdjusting: Bool = false,
        isFocusSettling: Bool = false
    ) -> Bool {
        evaluate(
            detection,
            focusQuality: focusQuality,
            isFocusAdjusting: isFocusAdjusting,
            isFocusSettling: isFocusSettling
        ).shouldCapture
    }
}
