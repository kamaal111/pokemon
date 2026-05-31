//
//  PokemonCardAutoCaptureGate.swift
//  PokemonCardPipeline
//
//  Created by Kamaal M Farah on 5/19/26.
//

import CoreGraphics
import PokemonCardDetection
import PokemonCardFocusQuality

public struct PokemonCardAutoCaptureDecision: Equatable, Sendable {
    public let shouldCapture: Bool
    public let isGeometryStable: Bool
    public let isFocusEligible: Bool
    public let didResetStability: Bool
}

public class PokemonCardAutoCaptureGate {
    struct Configuration: Sendable {
        let requiredStableDetections: Int
        let requiredFocusedDetections: Int
        let maximumCenterDrift: CGFloat
        let minimumIntersectionOverUnion: CGFloat
        let maximumAreaDrift: CGFloat

        static let `default` = Configuration(
            requiredStableDetections: 3,
            requiredFocusedDetections: 2,
            maximumCenterDrift: 0.06,
            minimumIntersectionOverUnion: 0.65,
            maximumAreaDrift: 0.25
        )
    }

    private let configuration: Configuration

    private var previousDetection: PokemonCardShapeDetection?
    private var stableDetectionCount = 0
    private var focusedDetectionCount = 0
    private var hasCaptured = false

    public init() {
        configuration = .default
    }

    public func evaluate(
        _ detection: PokemonCardShapeDetection?,
        focusQuality: PokemonCardFocusQualityReport?,
        isFocusAdjusting: Bool = false,
        isFocusSettling: Bool = false
    ) -> PokemonCardAutoCaptureDecision {
        guard !hasCaptured else {
            return PokemonCardAutoCaptureDecision(
                shouldCapture: false,
                isGeometryStable: false,
                isFocusEligible: false,
                didResetStability: false
            )
        }
        guard let detection else {
            previousDetection = nil
            stableDetectionCount = 0
            focusedDetectionCount = 0
            return PokemonCardAutoCaptureDecision(
                shouldCapture: false,
                isGeometryStable: false,
                isFocusEligible: false,
                didResetStability: true
            )
        }

        let didResetStability: Bool
        let isGeometryStable: Bool
        if let previousDetection, isStable(detection, after: previousDetection) {
            stableDetectionCount += 1
            didResetStability = false
            isGeometryStable = stableDetectionCount >= configuration.requiredStableDetections
        } else {
            stableDetectionCount = 1
            focusedDetectionCount = 0
            didResetStability = previousDetection != nil
            isGeometryStable = false
        }

        previousDetection = detection

        let isFocusEligible =
            (focusQuality?.isSharpEnough ?? true) && !isFocusAdjusting && !isFocusSettling
        if isFocusEligible {
            focusedDetectionCount += 1
        } else {
            focusedDetectionCount = 0
        }

        guard isGeometryStable else {
            return PokemonCardAutoCaptureDecision(
                shouldCapture: false,
                isGeometryStable: false,
                isFocusEligible: isFocusEligible,
                didResetStability: didResetStability
            )
        }

        guard focusedDetectionCount >= configuration.requiredFocusedDetections else {
            return PokemonCardAutoCaptureDecision(
                shouldCapture: false,
                isGeometryStable: true,
                isFocusEligible: isFocusEligible,
                didResetStability: didResetStability
            )
        }

        hasCaptured = true

        return PokemonCardAutoCaptureDecision(
            shouldCapture: true,
            isGeometryStable: true,
            isFocusEligible: isFocusEligible,
            didResetStability: didResetStability
        )
    }

    func reset() {
        previousDetection = nil
        stableDetectionCount = 0
        focusedDetectionCount = 0
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
