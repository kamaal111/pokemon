//
//  PokemonCardFramePipelineTests.swift
//  PokemonCardPipeline
//
//  Created by Kamaal M Farah on 5/25/26.
//

import CoreGraphics
import Testing
import UIKit

@testable import PokemonCardCropping
@testable import PokemonCardDetection
@testable import PokemonCardPipeline
@testable import PokemonCardStability

@Suite("PokemonCardFramePipeline Tests")
struct PokemonCardFramePipelineTests {
    @Test
    func `Should return report without crop or capture when no card is detected`() throws {
        var cropCallCount = 0
        var pipeline = PokemonCardFramePipeline(
            detectCardShape: { _ in
                .success(Self.report(selectedDetection: nil))
            },
            cropCard: { _, _ in
                cropCallCount += 1
                return .success(Self.cropResult())
            },
            autoCaptureGate: PokemonCardAutoCaptureGate()
        )

        let result = try pipeline.process(Self.image()).get()

        #expect(result.detectionReport.selectedDetection == nil)
        #expect(result.cropResult == nil)
        #expect(result.capture == nil)
        #expect(cropCallCount == 0)
    }

    @Test
    func `Should crop detected card before capture is stable`() throws {
        var cropCallCount = 0
        let detection = Self.detection()
        var pipeline = PokemonCardFramePipeline(
            detectCardShape: { _ in
                .success(Self.report(selectedDetection: detection))
            },
            cropCard: { _, rect in
                cropCallCount += 1
                #expect(rect == detection.normalizedBoundingBox)
                return .success(Self.cropResult())
            },
            autoCaptureGate: PokemonCardAutoCaptureGate()
        )

        let result = try pipeline.process(Self.image()).get()

        #expect(result.cropResult != nil)
        #expect(result.capture == nil)
        #expect(cropCallCount == 1)
    }

    @Test
    func `Should capture only after required stable cropped detections`() throws {
        let detection = Self.detection()
        var cropCallCount = 0
        var pipeline = PokemonCardFramePipeline(
            detectCardShape: { _ in
                .success(Self.report(selectedDetection: detection))
            },
            cropCard: { _, _ in
                cropCallCount += 1
                return .success(Self.cropResult())
            },
            autoCaptureGate: PokemonCardAutoCaptureGate()
        )

        let first = try pipeline.process(Self.image()).get()
        let second = try pipeline.process(Self.image()).get()
        let third = try pipeline.process(Self.image()).get()

        #expect(first.capture == nil)
        #expect(second.capture == nil)
        #expect(third.capture?.detection == detection)
        #expect(third.capture?.cropResult.cropImage.size == CGSize(width: 80, height: 120))
        #expect(cropCallCount == 3)
    }

    @Test
    func `Should not emit repeated captures after first stable capture`() throws {
        let detection = Self.detection()
        var pipeline = PokemonCardFramePipeline(
            detectCardShape: { _ in
                .success(Self.report(selectedDetection: detection))
            },
            cropCard: { _, _ in
                .success(Self.cropResult())
            },
            autoCaptureGate: PokemonCardAutoCaptureGate()
        )

        _ = try pipeline.process(Self.image()).get()
        _ = try pipeline.process(Self.image()).get()
        let firstStable = try pipeline.process(Self.image()).get()
        let repeated = try pipeline.process(Self.image()).get()

        #expect(firstStable.capture != nil)
        #expect(repeated.capture == nil)
    }

    @Test
    func `Should surface crop failure when detection exists`() {
        var pipeline = PokemonCardFramePipeline(
            detectCardShape: { _ in
                .success(Self.report(selectedDetection: Self.detection()))
            },
            cropCard: { _, _ in
                .failure(.emptyCrop)
            },
            autoCaptureGate: PokemonCardAutoCaptureGate()
        )

        #expect(throws: PokemonCardPipelineError.cropFailed(.emptyCrop)) {
            try pipeline.process(Self.image()).get()
        }
    }

    private static func report(selectedDetection: PokemonCardShapeDetection?) -> PokemonCardShapeDetectionReport {
        PokemonCardShapeDetectionReport(
            frameSize: CGSize(width: 200, height: 300),
            candidates: [],
            selectedDetection: selectedDetection
        )
    }

    private static func detection(
        rect: CGRect = CGRect(x: 0.20, y: 0.20, width: 0.36, height: 0.50)
    ) -> PokemonCardShapeDetection {
        PokemonCardShapeDetection(normalizedBoundingBox: rect, confidence: 0.90)
    }

    private static func cropResult() -> PokemonCardCropResult {
        let original = Self.image(size: CGSize(width: 200, height: 300))
        let crop = Self.image(size: CGSize(width: 80, height: 120))

        return PokemonCardCropResult(
            originalImage: original,
            cropImage: crop,
            cropRect: CGRect(x: 20, y: 20, width: 80, height: 120),
            normalizedCropRect: CGRect(x: 0.10, y: 0.10, width: 0.40, height: 0.40),
            isClippedToImageBounds: false
        )
    }

    private static func image(size: CGSize = CGSize(width: 200, height: 300)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
