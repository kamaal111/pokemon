//
//  PokemonCardShapeDetectorTests.swift
//  PokemonCardPipeline
//
//  Created by Kamaal M Farah on 5/19/26.
//

import CoreGraphics
import Testing
import UIKit

@testable import PokemonCardCropping
@testable import PokemonCardDetection

@Suite("PokemonCardShapeDetector Tests")
struct PokemonCardShapeDetectorTests {
    @Test
    func `Should accept portrait card-like rectangles near target ratio`() {
        let detection = detection(rect: CGRect(x: 0.22, y: 0.16, width: 0.36, height: 0.50), confidence: 0.72)

        #expect(PokemonCardShapeDetector.isValid(detection))
    }

    @Test
    func `Should accept mild perspective ratio deviation`() {
        let detection = detection(rect: CGRect(x: 0.20, y: 0.15, width: 0.43, height: 0.44), confidence: 0.68)

        #expect(PokemonCardShapeDetector.isValid(detection))
    }

    @Test
    func `Should accept angled perspective outside old ratio limit`() {
        let detection = detection(
            rect: CGRect(x: 0.18, y: 0.16, width: 0.45, height: 0.49),
            confidence: 0.74,
            corners: PokemonCardShapeQuadrilateral(
                topLeft: CGPoint(x: 0.28, y: 0.65),
                topRight: CGPoint(x: 0.56, y: 0.62),
                bottomRight: CGPoint(x: 0.63, y: 0.16),
                bottomLeft: CGPoint(x: 0.18, y: 0.21)
            )
        )

        #expect(PokemonCardShapeDetector.isValid(detection))
    }

    @Test
    func `Should score normalized portrait camera frame aspect in image space`() {
        let detection = detection(rect: CGRect(x: 0.22, y: 0.21, width: 0.48, height: 0.36), confidence: 1.0)
        let evaluation = PokemonCardShapeDetector.scoreCandidate(
            detection,
            imageSize: CGSize(width: 720, height: 1280)
        )

        #expect(evaluation.isAccepted)
        #expect(evaluation.metrics.boundingAspectRatio > 0.70)
        #expect(evaluation.metrics.boundingAspectRatio < 0.80)
    }

    @Test
    func `Should score normalized quadrilateral side ratio in image space`() {
        let detection = detection(
            rect: CGRect(x: 0.22, y: 0.21, width: 0.48, height: 0.36),
            confidence: 1.0,
            corners: PokemonCardShapeQuadrilateral(
                topLeft: CGPoint(x: 0.22, y: 0.57),
                topRight: CGPoint(x: 0.70, y: 0.57),
                bottomRight: CGPoint(x: 0.70, y: 0.21),
                bottomLeft: CGPoint(x: 0.22, y: 0.21)
            )
        )
        let evaluation = PokemonCardShapeDetector.scoreCandidate(
            detection,
            imageSize: CGSize(width: 720, height: 1280)
        )

        #expect(evaluation.isAccepted)
        #expect(evaluation.metrics.sideAspectRatio ?? 0 > 0.70)
        #expect(evaluation.metrics.sideAspectRatio ?? 0 < 0.80)
    }

    @Test
    func `Should reject invalid rectangle candidates`() {
        let invalidDetections = [
            detection(rect: CGRect(x: 0.10, y: 0.20, width: 0.55, height: 0.32), confidence: 0.90),
            detection(rect: CGRect(x: 0.30, y: 0.30, width: 0.08, height: 0.11), confidence: 0.90),
            detection(rect: CGRect(x: 0.20, y: 0.20, width: 0.34, height: 0.48), confidence: 0.40),
            detection(rect: CGRect(x: 0.01, y: 0.01, width: 0.96, height: 0.92), confidence: 0.90),
            detection(rect: CGRect(x: 0.10, y: 0.10, width: 0.70, height: 0.44), confidence: 0.90),
        ]

        for invalidDetection in invalidDetections {
            #expect(!PokemonCardShapeDetector.isValid(invalidDetection))
        }
    }

    @Test
    func `Should pick strongest largest valid candidate`() throws {
        let weakValid = detection(rect: CGRect(x: 0.30, y: 0.24, width: 0.28, height: 0.39), confidence: 0.57)
        let landscape = detection(rect: CGRect(x: 0.10, y: 0.10, width: 0.58, height: 0.32), confidence: 0.99)
        let strongest = detection(rect: CGRect(x: 0.22, y: 0.18, width: 0.38, height: 0.53), confidence: 0.78)

        let best = try #require(PokemonCardShapeDetector.bestDetection(in: [weakValid, landscape, strongest]))

        #expect(best == strongest)
    }

    @Test
    func `Should report score metrics and rejection reasons`() throws {
        let weakDetection = detection(rect: CGRect(x: 0.20, y: 0.20, width: 0.02, height: 0.02), confidence: 0.10)
        let evaluation = PokemonCardShapeDetector.scoreCandidate(weakDetection)

        #expect(evaluation.score < PokemonCardShapeDetector.Configuration.default.minimumAcceptedScore)
        #expect(evaluation.metrics.boundingAspectRatio > 0)
        #expect(evaluation.rejectionReasons.contains(.lowConfidence))
        #expect(evaluation.rejectionReasons.contains(.poorScore))
    }

    @Test
    func `Should expose best rejected candidate in report`() throws {
        let weakDetection = detection(rect: CGRect(x: 0.20, y: 0.20, width: 0.02, height: 0.02), confidence: 0.10)
        let candidate = PokemonCardShapeDetectionCandidate(
            id: 0,
            detection: weakDetection,
            source: .vision,
            evaluation: PokemonCardShapeDetector.scoreCandidate(weakDetection)
        )
        let report = PokemonCardShapeDetectionReport(
            frameSize: CGSize(width: 960, height: 860),
            candidates: [candidate],
            selectedDetection: nil
        )
        let rejectedCandidate = try #require(report.bestRejectedCandidate)

        #expect(report.selectedDetection == nil)
        #expect(!rejectedCandidate.rejectionReasons.isEmpty)
    }

    @Test
    func `Should detect darker colorful card on light tabletop`() throws {
        let cardRect = CGRect(x: 350, y: 270, width: 270, height: 378)
        let image = syntheticLightTabletopCardImage(cardRect: cardRect)
        let detection = try #require(
            PokemonCardShapeDetector.fallbackDetection(in: image, configuration: .default)
        )
        let imageRect = PokemonCardCropper.imageRect(
            fromVisionNormalizedRect: detection.normalizedBoundingBox,
            imageSize: image.size
        )

        #expect(PokemonCardShapeDetector.isValid(detection))
        #expect(imageRect.intersection(cardRect).width > cardRect.width * 0.88)
        #expect(imageRect.intersection(cardRect).height > cardRect.height * 0.88)
        #expect(imageRect.width < image.size.width * 0.45)
        #expect(imageRect.height < image.size.height * 0.58)
    }

    @Test
    func `Should detect Cyndaquil card from light tabletop camera frame`() throws {
        let image = try sampleImage("cyndaquil-light-table")
        let expectedCardRect = CGRect(x: 0.25, y: 0.25, width: 0.50, height: 0.54)
        let detection = try #require(try PokemonCardShapeDetector.detectCardShape(in: image).get())

        #expect(PokemonCardShapeDetector.isValid(detection))
        #expect(normalizedIntersection(detection.normalizedBoundingBox, expectedCardRect) > 0.72)
    }

    @Test
    func `Should report selected candidate details for light tabletop frame`() throws {
        let image = try sampleImage("cyndaquil-light-table")
        let report = try PokemonCardShapeDetector.detectCardShapeReport(in: image).get()
        let selectedDetection = try #require(report.selectedDetection)
        let selectedCandidate = try #require(
            report.candidates.first { $0.detection == selectedDetection }
        )

        #expect(report.frameSize == image.size)
        #expect(report.validCandidateCount >= 1)
        #expect(selectedCandidate.isValid)
    }

    private func detection(
        rect: CGRect,
        confidence: Float,
        corners: PokemonCardShapeQuadrilateral? = nil
    ) -> PokemonCardShapeDetection {
        PokemonCardShapeDetection(
            normalizedBoundingBox: rect,
            confidence: confidence,
            normalizedCorners: corners
        )
    }

    private func normalizedIntersection(_ first: CGRect, _ second: CGRect) -> CGFloat {
        let intersection = first.intersection(second)
        guard !intersection.isNull else { return 0 }

        return (intersection.width * intersection.height) / (second.width * second.height)
    }

    private func syntheticLightTabletopCardImage(cardRect: CGRect) -> UIImage {
        let imageSize = CGSize(width: 960, height: 860)
        let renderer = UIGraphicsImageRenderer(size: imageSize)

        return renderer.image { context in
            UIColor(red: 0.90, green: 0.89, blue: 0.84, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: imageSize))

            UIColor(red: 0.55, green: 0.55, blue: 0.50, alpha: 1).setFill()
            context.fill(cardRect.offsetBy(dx: 8, dy: 10))

            UIColor(red: 0.74, green: 0.20, blue: 0.12, alpha: 1).setFill()
            context.fill(cardRect)

            UIColor(red: 0.93, green: 0.68, blue: 0.48, alpha: 1).setFill()
            context.fill(cardRect.insetBy(dx: 14, dy: 14))

            UIColor(red: 0.36, green: 0.62, blue: 0.78, alpha: 1).setFill()
            context.fill(
                CGRect(
                    x: cardRect.minX + 28,
                    y: cardRect.minY + 62,
                    width: cardRect.width - 56,
                    height: cardRect.height * 0.28
                ))

            UIColor(red: 0.70, green: 0.18, blue: 0.10, alpha: 1).setFill()
            context.fill(
                CGRect(
                    x: cardRect.minX + 30,
                    y: cardRect.minY + cardRect.height * 0.52,
                    width: cardRect.width - 60,
                    height: cardRect.height * 0.35
                ))
        }
    }
}
