//
//  PokemonCardAutoCaptureGate.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/17/26.
//

import CoreGraphics

struct PokemonCardAutoCaptureGate {
    private let requiredStableDetectionCount: Int
    private let maximumCenterDrift: CGFloat
    private let maximumSizeDrift: CGFloat

    private var previousDetection: PokemonCardShapeDetection?
    private var stableDetectionCount = 0
    private var hasTriggeredCapture = false

    init(
        requiredStableDetectionCount: Int = 3,
        maximumCenterDrift: CGFloat = 0.07,
        maximumSizeDrift: CGFloat = 0.12
    ) {
        self.requiredStableDetectionCount = requiredStableDetectionCount
        self.maximumCenterDrift = maximumCenterDrift
        self.maximumSizeDrift = maximumSizeDrift
    }

    mutating func shouldCapture(after detection: PokemonCardShapeDetection?) -> Bool {
        guard !hasTriggeredCapture else {
            return false
        }

        guard let detection else {
            previousDetection = nil
            stableDetectionCount = 0
            return false
        }

        if let previousDetection {
            if isStable(detection, comparedTo: previousDetection) {
                stableDetectionCount += 1
            } else {
                stableDetectionCount = 1
            }
        } else {
            stableDetectionCount = 1
        }

        previousDetection = detection
        guard stableDetectionCount >= requiredStableDetectionCount else {
            return false
        }

        hasTriggeredCapture = true
        return true
    }

    mutating func reset() {
        previousDetection = nil
        stableDetectionCount = 0
        hasTriggeredCapture = false
    }

    private func isStable(
        _ detection: PokemonCardShapeDetection,
        comparedTo previousDetection: PokemonCardShapeDetection
    ) -> Bool {
        let centerDrift = hypot(
            detection.boundingBox.midX - previousDetection.boundingBox.midX,
            detection.boundingBox.midY - previousDetection.boundingBox.midY
        )
        guard centerDrift <= maximumCenterDrift else {
            return false
        }

        let widthDrift = abs(detection.boundingBox.width - previousDetection.boundingBox.width)
        let heightDrift = abs(detection.boundingBox.height - previousDetection.boundingBox.height)

        return widthDrift <= maximumSizeDrift && heightDrift <= maximumSizeDrift
    }
}
