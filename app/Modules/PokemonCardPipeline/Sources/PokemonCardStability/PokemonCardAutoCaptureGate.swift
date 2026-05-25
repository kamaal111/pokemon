//
//  PokemonCardAutoCaptureGate.swift
//  PokemonCardPipeline
//
//  Created by Kamaal M Farah on 5/19/26.
//

import CoreGraphics
import PokemonCardDetection

public struct PokemonCardAutoCaptureGate {
    struct Configuration: Sendable {
        let requiredStableDetections: Int
        let maximumCenterDrift: CGFloat
        let minimumIntersectionOverUnion: CGFloat
        let maximumAreaDrift: CGFloat

        static let `default` = Configuration(
            requiredStableDetections: 3,
            maximumCenterDrift: 0.06,
            minimumIntersectionOverUnion: 0.65,
            maximumAreaDrift: 0.25
        )
    }

    private let configuration: Configuration

    private var previousDetection: PokemonCardShapeDetection?
    private var stableDetectionCount = 0
    private var hasCaptured = false

    public init() {
        configuration = .default
    }

    public mutating func shouldCapture(_ detection: PokemonCardShapeDetection?) -> Bool {
        guard !hasCaptured else {
            return false
        }
        guard let detection else {
            previousDetection = nil
            stableDetectionCount = 0
            return false
        }

        if let previousDetection, isStable(detection, after: previousDetection) {
            stableDetectionCount += 1
        } else {
            stableDetectionCount = 1
        }

        previousDetection = detection
        guard stableDetectionCount >= configuration.requiredStableDetections else {
            return false
        }

        hasCaptured = true
        return true
    }

    mutating func reset() {
        previousDetection = nil
        stableDetectionCount = 0
        hasCaptured = false
    }

    private func isStable(
        _ detection: PokemonCardShapeDetection,
        after previousDetection: PokemonCardShapeDetection
    ) -> Bool {
        let rect = detection.normalizedBoundingBox.standardized
        let previousRect = previousDetection.normalizedBoundingBox.standardized
        let centerDrift = hypot(rect.midX - previousRect.midX, rect.midY - previousRect.midY)
        let intersectionOverUnion = intersectionOverUnion(rect, previousRect)
        let area = rect.width * rect.height
        let previousArea = previousRect.width * previousRect.height
        let largerArea = max(area, previousArea)
        let areaDrift = largerArea > 0 ? abs(area - previousArea) / largerArea : 1

        return centerDrift <= configuration.maximumCenterDrift
            && intersectionOverUnion >= configuration.minimumIntersectionOverUnion
            && areaDrift <= configuration.maximumAreaDrift
    }

    private func intersectionOverUnion(_ first: CGRect, _ second: CGRect) -> CGFloat {
        let intersection = first.intersection(second)
        guard !intersection.isNull else { return 0 }

        let intersectionArea = intersection.width * intersection.height
        let firstArea = first.width * first.height
        let secondArea = second.width * second.height
        let unionArea = firstArea + secondArea - intersectionArea
        guard unionArea > 0 else { return 0 }

        return intersectionArea / unionArea
    }
}
