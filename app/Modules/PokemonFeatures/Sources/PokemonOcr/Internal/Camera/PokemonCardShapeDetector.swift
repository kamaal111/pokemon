//
//  PokemonCardShapeDetector.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/17/26.
//

import CoreGraphics
import CoreMedia
import Foundation
import Vision

struct PokemonCardShapeObservation: Equatable {
    let boundingBox: CGRect
    let confidence: Float
}

struct PokemonCardShapeDetection: Equatable {
    let boundingBox: CGRect
    let confidence: Float
}

struct PokemonCardShapeDetectionResult: Equatable {
    let candidates: [PokemonCardShapeDetection]
    let bestDetection: PokemonCardShapeDetection?
}

enum PokemonCardShapeDetector {
    private static let cardAspectRatio: CGFloat = 63 / 88
    private static let aspectRatioTolerance: CGFloat = 0.35
    private static let minimumArea: CGFloat = 0.006
    private static let minimumConfidence: Float = 0.15
    private static let minimumTextOverlapCount = 2
    private static let minimumTextOverlapAreaRatio: CGFloat = 0.45
    private static let minimumVisionAspectRatio = max(0, cardAspectRatio - aspectRatioTolerance)
    private static let maximumVisionAspectRatio = min(1, cardAspectRatio + aspectRatioTolerance)

    static func bestDetection(
        from observations: [PokemonCardShapeObservation]
    ) -> PokemonCardShapeDetection? {
        candidates(from: observations)
            .max { lhs, rhs in
                lhs.boundingBox.width * lhs.boundingBox.height < rhs.boundingBox.width * rhs.boundingBox.height
            }
    }

    static func candidates(
        from observations: [PokemonCardShapeObservation]
    ) -> [PokemonCardShapeDetection] {
        observations
            .filter(isValidCardShape)
            .map { observation in
                PokemonCardShapeDetection(
                    boundingBox: observation.boundingBox,
                    confidence: observation.confidence
                )
            }
    }

    static func bestDetection(
        from candidates: [PokemonCardShapeDetection],
        overlapping textBoxes: [CGRect]
    ) -> PokemonCardShapeDetection? {
        candidates
            .filter { candidate in
                hasEnoughTextOverlap(candidate: candidate, textBoxes: textBoxes)
            }
            .max { lhs, rhs in
                textDensityScore(for: lhs, textBoxes: textBoxes)
                    < textDensityScore(for: rhs, textBoxes: textBoxes)
            }
    }

    static func detectCard(in sampleBuffer: CMSampleBuffer) -> PokemonCardShapeDetection? {
        detectCards(in: sampleBuffer).bestDetection
    }

    static func detectCards(in sampleBuffer: CMSampleBuffer) -> PokemonCardShapeDetectionResult {
        autoreleasepool {
            detectCardsInsideAutoreleasePool(in: sampleBuffer)
        }
    }

    private static func detectCardsInsideAutoreleasePool(
        in sampleBuffer: CMSampleBuffer
    ) -> PokemonCardShapeDetectionResult {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return PokemonCardShapeDetectionResult(candidates: [], bestDetection: nil)
        }

        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 20
        request.minimumConfidence = minimumConfidence
        request.minimumAspectRatio = Float(minimumVisionAspectRatio)
        request.maximumAspectRatio = Float(maximumVisionAspectRatio)
        request.minimumSize = 0.08
        request.quadratureTolerance = 35

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return PokemonCardShapeDetectionResult(candidates: [], bestDetection: nil)
        }

        guard let results = request.results else {
            return PokemonCardShapeDetectionResult(candidates: [], bestDetection: nil)
        }

        let observations = results.map { observation in
            PokemonCardShapeObservation(
                boundingBox: observation.boundingBox,
                confidence: observation.confidence
            )
        }
        let candidates = candidates(from: observations)

        return PokemonCardShapeDetectionResult(
            candidates: candidates,
            bestDetection: bestDetection(from: observations)
        )
    }

    private static func isValidCardShape(_ observation: PokemonCardShapeObservation) -> Bool {
        guard observation.confidence >= minimumConfidence else {
            return false
        }

        guard observation.boundingBox.width > 0 else {
            return false
        }

        guard observation.boundingBox.height > 0 else {
            return false
        }

        guard observation.boundingBox.height > observation.boundingBox.width else {
            return false
        }

        let area = observation.boundingBox.width * observation.boundingBox.height
        guard area >= minimumArea else {
            return false
        }

        let aspectRatio = observation.boundingBox.width / observation.boundingBox.height

        return abs(aspectRatio - cardAspectRatio) <= aspectRatioTolerance
    }

    private static func hasEnoughTextOverlap(
        candidate: PokemonCardShapeDetection,
        textBoxes: [CGRect]
    ) -> Bool {
        overlappingTextBoxes(candidate: candidate, textBoxes: textBoxes).count >= minimumTextOverlapCount
    }

    private static func textDensityScore(
        for candidate: PokemonCardShapeDetection,
        textBoxes: [CGRect]
    ) -> CGFloat {
        let candidateArea = candidate.boundingBox.width * candidate.boundingBox.height
        guard candidateArea > 0 else {
            return 0
        }

        let textArea = overlappingTextBoxes(candidate: candidate, textBoxes: textBoxes)
            .map { textBox in
                textBox.width * textBox.height
            }
            .reduce(0, +)

        return textArea / candidateArea
    }

    private static func overlappingTextBoxes(
        candidate: PokemonCardShapeDetection,
        textBoxes: [CGRect]
    ) -> [CGRect] {
        let overlappingTextBoxes = textBoxes.filter { textBox in
            guard textBox.width > 0 else {
                return false
            }

            guard textBox.height > 0 else {
                return false
            }

            let intersection = candidate.boundingBox.intersection(textBox)
            guard !intersection.isNull else {
                return false
            }

            let textArea = textBox.width * textBox.height
            let intersectionArea = intersection.width * intersection.height

            return intersectionArea / textArea >= minimumTextOverlapAreaRatio
        }

        return overlappingTextBoxes
    }
}
