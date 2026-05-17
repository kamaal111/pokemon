//
//  PokemonCardTextClusterDetector.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/18/26.
//

import CoreGraphics
import CoreMedia
import Foundation
import Vision

struct PokemonCardTextClusterObservation: Equatable {
    let boundingBox: CGRect
    let confidence: Float
}

enum PokemonCardTextClusterDetector {
    private static let cardAspectRatio: CGFloat = 2.5 / 3.5
    private static let minimumObservationCount = 3
    private static let minimumClusterArea: CGFloat = 0.015
    private static let minimumObservationConfidence: Float = 0.25

    static func bestDetection(
        from observations: [PokemonCardTextClusterObservation]
    ) -> PokemonCardShapeDetection? {
        let usableObservations = observations.filter { observation in
            observation.confidence >= minimumObservationConfidence
                && observation.boundingBox.width > 0
                && observation.boundingBox.height > 0
        }
        guard usableObservations.count >= minimumObservationCount else {
            return nil
        }

        let clusterBox =
            usableObservations
            .map(\.boundingBox)
            .reduce(CGRect.null) { partialResult, rect in
                partialResult.union(rect)
            }
        guard !clusterBox.isNull else {
            return nil
        }

        guard clusterBox.width * clusterBox.height >= minimumClusterArea else {
            return nil
        }

        return PokemonCardShapeDetection(
            boundingBox: cardBoundingBox(for: clusterBox),
            confidence: usableObservations.map(\.confidence).reduce(0, +) / Float(usableObservations.count)
        )
    }

    static func detectCard(in sampleBuffer: CMSampleBuffer) -> PokemonCardShapeDetection? {
        autoreleasepool {
            detectCardInsideAutoreleasePool(in: sampleBuffer)
        }
    }

    static func detectText(in sampleBuffer: CMSampleBuffer) -> [PokemonCardTextClusterObservation] {
        autoreleasepool {
            detectTextInsideAutoreleasePool(in: sampleBuffer)
        }
    }

    private static func detectCardInsideAutoreleasePool(
        in sampleBuffer: CMSampleBuffer
    ) -> PokemonCardShapeDetection? {
        let observations = detectTextInsideAutoreleasePool(in: sampleBuffer)

        return bestDetection(from: observations)
    }

    private static func detectTextInsideAutoreleasePool(
        in sampleBuffer: CMSampleBuffer
    ) -> [PokemonCardTextClusterObservation] {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return []
        }

        let request = textRecognitionRequest()

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }

        guard let results = request.results else {
            return []
        }

        return results.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else {
                return nil
            }

            return PokemonCardTextClusterObservation(
                boundingBox: observation.boundingBox,
                confidence: candidate.confidence
            )
        }
    }

    private static func textRecognitionRequest() -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        request.recognitionLanguages = [
            PokemonRecognitionLanguage.japaneseJapan.rawValue,
            PokemonRecognitionLanguage.englishUnitedStates.rawValue,
        ]
        request.minimumTextHeight = 0.012

        return request
    }

    private static func cardBoundingBox(for textCluster: CGRect) -> CGRect {
        let paddedCluster = textCluster.insetBy(dx: -0.08, dy: -0.08)
        let boundedCluster = paddedCluster.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        let clusterCenter = CGPoint(x: boundedCluster.midX, y: boundedCluster.midY)

        let widthFromHeight = boundedCluster.height * cardAspectRatio
        let heightFromWidth = boundedCluster.width / cardAspectRatio
        let cardWidth = max(boundedCluster.width, widthFromHeight)
        let cardHeight = max(boundedCluster.height, heightFromWidth)
        let cardBox = CGRect(
            x: clusterCenter.x - (cardWidth / 2),
            y: clusterCenter.y - (cardHeight / 2),
            width: cardWidth,
            height: cardHeight
        )

        return CGRect(x: 0, y: 0, width: 1, height: 1).intersection(cardBox)
    }
}
