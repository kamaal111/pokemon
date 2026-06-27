//
//  PokemonCardFramePipelineTests.swift
//  PokemonCardPipeline
//
//  Created by Kamaal M Farah on 5/25/26.
//

import CoreGraphics
import PokemonCardPipelineTestSupport
import Testing
import UIKit

@testable import PokemonCardCropping
@testable import PokemonCardDetection
@testable import PokemonCardFocusQuality
@testable import PokemonCardPipeline
@testable import PokemonCardStability
@testable import PokemonCardTextExtraction

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
            extractPokemonName: { _ in nil },
            autoCaptureGate: PokemonCardAutoCaptureGate()
        )

        let result = try Self.processReady(&pipeline)

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
            extractPokemonName: { _ in nil },
            autoCaptureGate: PokemonCardAutoCaptureGate()
        )

        let result = try Self.processReady(&pipeline)

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
            extractPokemonName: { _ in nil },
            autoCaptureGate: PokemonCardAutoCaptureGate()
        )

        let first = try Self.processReady(&pipeline)
        let second = try Self.processReady(&pipeline)
        let third = try Self.processReady(&pipeline)

        #expect(first.capture == nil)
        #expect(second.capture == nil)
        #expect(third.capture?.detection == detection)
        #expect(third.capture?.cropResult.cropImage.size == CGSize(width: 240, height: 336))
        #expect(third.capture?.focusQuality?.isSharpEnough == true)
        #expect(cropCallCount == 3)
    }

    @Test
    func `Should complete captured card with pokemon name`() async throws {
        let detection = Self.detection()
        var pipeline = PokemonCardFramePipeline(
            detectCardShape: { _ in
                .success(Self.report(selectedDetection: detection))
            },
            cropCard: { _, _ in
                .success(Self.cropResult())
            },
            extractPokemonName: { image in
                #expect(image.size == CGSize(width: 240, height: 336))
                return "Charizard VMAX"
            },
            autoCaptureGate: PokemonCardAutoCaptureGate()
        )

        _ = try Self.processReady(&pipeline)
        _ = try Self.processReady(&pipeline)
        let result = try Self.processReady(&pipeline)
        let capture = try #require(result.capture)
        let namedCapture = await pipeline.completeCaptureName(for: capture)

        #expect(capture.pokemonName == nil)
        #expect(namedCapture.pokemonName == "Charizard VMAX")
        #expect(namedCapture.cropResult.cropImage.size == CGSize(width: 240, height: 336))
    }

    @Test
    func `Should keep captured card when pokemon name extraction fails`() async throws {
        let detection = Self.detection()
        var pipeline = PokemonCardFramePipeline(
            detectCardShape: { _ in
                .success(Self.report(selectedDetection: detection))
            },
            cropCard: { _, _ in
                .success(Self.cropResult())
            },
            extractPokemonName: { _ in nil },
            autoCaptureGate: PokemonCardAutoCaptureGate()
        )

        _ = try Self.processReady(&pipeline)
        _ = try Self.processReady(&pipeline)
        let result = try Self.processReady(&pipeline)
        let capture = try #require(result.capture)
        let namedCapture = await pipeline.completeCaptureName(for: capture)

        #expect(namedCapture.pokemonName == nil)
        #expect(namedCapture.detection == detection)
        #expect(namedCapture.cropResult.cropImage.size == CGSize(width: 240, height: 336))
    }

    @Test
    func `Should complete captured card with Foundation Models metadata by default`() async throws {
        let detection = Self.detection()
        let didCallFoundationModels = TestFlag()
        let didCallVisionName = TestFlag()
        var pipeline = PokemonCardFramePipeline(
            detectCardShape: { _ in
                .success(Self.report(selectedDetection: detection))
            },
            cropCard: { _, _ in
                .success(Self.cropResult())
            },
            extractPokemonName: { _ in
                didCallVisionName.value = true
                return "Vision Name"
            },
            extractFoundationModelMetadata: { image in
                didCallFoundationModels.value = true
                #expect(image.size == CGSize(width: 240, height: 336))
                return .success(PokemonCardMetadataExtractionResult(pokemonName: "이브이ex", setID: "sv8a"))
            },
            autoCaptureGate: PokemonCardAutoCaptureGate()
        )

        _ = try Self.processReady(&pipeline)
        _ = try Self.processReady(&pipeline)
        let result = try Self.processReady(&pipeline)
        let capture = try #require(result.capture)
        let metadataCapture = await pipeline.completeCaptureMetadata(for: capture)

        #expect(didCallFoundationModels.value)
        #expect(!didCallVisionName.value)
        #expect(metadataCapture.pokemonName == "이브이ex")
        #expect(metadataCapture.setID == "sv8a")
        #expect(metadataCapture.metadataErrorMessage == nil)
    }

    @Test
    func `Should use Vision name stage when Foundation Models metadata is disabled`() async throws {
        let detection = Self.detection()
        let didCallFoundationModels = TestFlag()
        var pipeline = PokemonCardFramePipeline(
            detectCardShape: { _ in
                .success(Self.report(selectedDetection: detection))
            },
            cropCard: { _, _ in
                .success(Self.cropResult())
            },
            extractPokemonName: { image in
                #expect(image.size == CGSize(width: 240, height: 336))
                return "Charizard VMAX"
            },
            extractFoundationModelMetadata: { _ in
                didCallFoundationModels.value = true
                return .success(PokemonCardMetadataExtractionResult(pokemonName: "이브이ex", setID: "sv8a"))
            },
            useFoundationModelsForCardTextExtraction: false,
            autoCaptureGate: PokemonCardAutoCaptureGate()
        )

        _ = try Self.processReady(&pipeline)
        _ = try Self.processReady(&pipeline)
        let result = try Self.processReady(&pipeline)
        let capture = try #require(result.capture)
        let metadataCapture = await pipeline.completeCaptureMetadata(for: capture)

        #expect(!didCallFoundationModels.value)
        #expect(metadataCapture.pokemonName == "Charizard VMAX")
        #expect(metadataCapture.setID == nil)
        #expect(metadataCapture.metadataErrorMessage == nil)
    }

    @Test
    func `Should preserve capture and fall back to Vision name when Foundation Models metadata fails`() async throws {
        let detection = Self.detection()
        var pipeline = PokemonCardFramePipeline(
            detectCardShape: { _ in
                .success(Self.report(selectedDetection: detection))
            },
            cropCard: { _, _ in
                .success(Self.cropResult())
            },
            extractPokemonName: { _ in "Fallback Name" },
            extractFoundationModelMetadata: { _ in .failure(.emptyResult) },
            autoCaptureGate: PokemonCardAutoCaptureGate()
        )

        _ = try Self.processReady(&pipeline)
        _ = try Self.processReady(&pipeline)
        let result = try Self.processReady(&pipeline)
        let capture = try #require(result.capture)
        let metadataCapture = await pipeline.completeCaptureMetadata(for: capture)

        #expect(metadataCapture.detection == detection)
        #expect(metadataCapture.cropResult.cropImage.size == CGSize(width: 240, height: 336))
        #expect(metadataCapture.pokemonName == "Fallback Name")
        #expect(metadataCapture.setID == nil)
        #expect(
            metadataCapture.metadataErrorMessage == PokemonCardMetadataExtractionError.emptyResult.localizedDescription)
    }

    @Test
    func `Should not capture stable card while text region is blurry`() throws {
        let detection = Self.detection()
        let blurryCardImage = try PokemonCardTestImageFilters.gaussianBlurred(
            PokemonCardTestImages.compactPipelineCard(lineWidth: 180)
        )
        var pipeline = PokemonCardFramePipeline(
            detectCardShape: { _ in
                .success(Self.report(selectedDetection: detection))
            },
            cropCard: { _, _ in
                .success(Self.cropResult(cropImage: blurryCardImage))
            },
            extractPokemonName: { _ in nil },
            autoCaptureGate: PokemonCardAutoCaptureGate()
        )

        _ = try Self.processReady(&pipeline)
        _ = try Self.processReady(&pipeline)
        let result = try Self.processReady(&pipeline)

        #expect(result.capture == nil)
        #expect(result.focusQuality?.isSharpEnough == false)
        #expect(result.focusQuality?.reason == .tooBlurry)
    }

    @Test
    func `Should capture best focused frame from the stable window`() throws {
        let detection = Self.detection()
        var cropResults = [
            Self.cropResult(cropImage: PokemonCardTestImages.compactPipelineCard(lineWidth: 120), cropRectWidth: 120),
            Self.cropResult(cropImage: PokemonCardTestImages.compactPipelineCard(lineWidth: 190), cropRectWidth: 190),
            Self.cropResult(cropImage: PokemonCardTestImages.compactPipelineCard(lineWidth: 150), cropRectWidth: 150),
        ]
        var pipeline = PokemonCardFramePipeline(
            detectCardShape: { _ in
                .success(Self.report(selectedDetection: detection))
            },
            cropCard: { _, _ in
                .success(cropResults.removeFirst())
            },
            extractPokemonName: { _ in nil },
            autoCaptureGate: PokemonCardAutoCaptureGate()
        )

        _ = try Self.processReady(&pipeline)
        _ = try Self.processReady(&pipeline)
        let result = try Self.processReady(&pipeline)

        #expect(result.capture?.cropResult.cropRect.width == 190)
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
            extractPokemonName: { _ in nil },
            autoCaptureGate: PokemonCardAutoCaptureGate()
        )

        _ = try Self.processReady(&pipeline)
        _ = try Self.processReady(&pipeline)
        let firstStable = try Self.processReady(&pipeline)
        let repeated = try Self.processReady(&pipeline)

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
            extractPokemonName: { _ in nil },
            autoCaptureGate: PokemonCardAutoCaptureGate()
        )

        #expect(throws: PokemonCardPipelineError.cropFailed(.emptyCrop)) {
            try Self.processReady(&pipeline)
        }
    }

    private static func processReady(
        _ pipeline: inout PokemonCardFramePipeline,
        image: UIImage = Self.image()
    ) throws -> PokemonCardPipelineFrameResult {
        try pipeline.process(
            image,
            isFocusAdjusting: false,
            isFocusSettling: false
        ).get()
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

    private static func cropResult(
        cropImage: UIImage = PokemonCardTestImages.compactPipelineCard(lineWidth: 180),
        cropRectWidth: CGFloat? = nil
    ) -> PokemonCardCropResult {
        let original = Self.image(size: CGSize(width: 200, height: 300))

        return PokemonCardCropResult(
            originalImage: original,
            cropImage: cropImage,
            cropRect: CGRect(
                x: 20,
                y: 20,
                width: cropRectWidth ?? cropImage.size.width,
                height: cropImage.size.height
            ),
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

private final class TestFlag: @unchecked Sendable {
    var value = false
}
