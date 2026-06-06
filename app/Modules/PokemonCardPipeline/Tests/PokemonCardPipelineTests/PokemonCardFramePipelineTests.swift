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
@testable import PokemonCardOrientationCorrection
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
            cropCard: { _, receivedDetection in
                cropCallCount += 1
                #expect(receivedDetection == detection)
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
    func `Should correct cropped card before focus quality and capture`() throws {
        let detection = Self.detection()
        let blurryCardImage = try PokemonCardTestImageFilters.gaussianBlurred(
            PokemonCardTestImages.compactPipelineCard(lineWidth: 180)
        )
        let correctedCardImage = PokemonCardTestImages.compactPipelineCard(lineWidth: 180)
        var correctionCallCount = 0
        var pipeline = PokemonCardFramePipeline(
            detectCardShape: { _ in
                .success(Self.report(selectedDetection: detection))
            },
            cropCard: { _, _ in
                .success(Self.cropResult(cropImage: blurryCardImage))
            },
            correctOrientation: { cropResult in
                correctionCallCount += 1
                #expect(cropResult.cropImage.size == blurryCardImage.size)
                return .success(Self.cropResult(cropImage: correctedCardImage))
            },
            extractPokemonName: { _ in nil },
            autoCaptureGate: PokemonCardAutoCaptureGate()
        )

        _ = try Self.processReady(&pipeline)
        _ = try Self.processReady(&pipeline)
        let result = try Self.processReady(&pipeline)

        #expect(correctionCallCount == 3)
        #expect(result.focusQuality?.isSharpEnough == true)
        #expect(result.capture?.cropResult.cropImage.size == correctedCardImage.size)
    }

    @Test
    func `Should perspective correct detected quadrilateral before focus quality`() throws {
        let imageSize = CGSize(width: 520, height: 520)
        let cardRect = CGRect(x: 170, y: 110, width: 180, height: 252)
        let rotation = CGFloat.pi / 7
        let frame = Self.titledCardImage(imageSize: imageSize, cardRect: cardRect, rotation: rotation)
        let cropQuadrilateral = Self.cropQuadrilateral(for: cardRect, in: imageSize, rotation: rotation)
        let detection = Self.detection(
            rect: cropQuadrilateral.boundingBox,
            corners: PokemonCardShapeQuadrilateral(
                topLeft: cropQuadrilateral.topLeft,
                topRight: cropQuadrilateral.topRight,
                bottomRight: cropQuadrilateral.bottomRight,
                bottomLeft: cropQuadrilateral.bottomLeft
            )
        )
        var pipeline = PokemonCardFramePipeline(
            detectCardShape: { _ in
                .success(Self.report(selectedDetection: detection))
            },
            cropCard: { image, detection in
                PokemonCardCropper.cropCard(
                    from: image,
                    detectedNormalizedCardQuadrilateral: detection.normalizedCorners.map {
                        PokemonCardCropQuadrilateral(
                            topLeft: $0.topLeft,
                            topRight: $0.topRight,
                            bottomRight: $0.bottomRight,
                            bottomLeft: $0.bottomLeft
                        )
                    },
                    detectedNormalizedCardRect: detection.normalizedBoundingBox
                )
            },
            correctOrientation: { .success($0) },
            extractPokemonName: { _ in nil },
            autoCaptureGate: PokemonCardAutoCaptureGate()
        )

        let result = try Self.processReady(&pipeline, image: frame)
        let cropImage = try #require(result.cropResult?.cropImage)
        let topBandColor = Self.averageColor(
            in: CGRect(x: 0.20, y: 0.06, width: 0.60, height: 0.10),
            image: cropImage
        )
        let bottomBandColor = Self.averageColor(
            in: CGRect(x: 0.20, y: 0.82, width: 0.60, height: 0.10),
            image: cropImage
        )

        #expect(cropImage.size.height > cropImage.size.width)
        #expect(topBandColor.red > topBandColor.blue + 0.25)
        #expect(bottomBandColor.blue > bottomBandColor.red + 0.25)
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
    func `Should complete captured card name from corrected crop`() async throws {
        let detection = Self.detection()
        let correctedCardImage = PokemonCardTestImages.compactPipelineCard(lineWidth: 180)
        var pipeline = PokemonCardFramePipeline(
            detectCardShape: { _ in
                .success(Self.report(selectedDetection: detection))
            },
            cropCard: { _, _ in
                .success(Self.cropResult(cropImage: Self.image(size: CGSize(width: 336, height: 240))))
            },
            correctOrientation: { _ in
                .success(Self.cropResult(cropImage: correctedCardImage))
            },
            extractPokemonName: { image in
                #expect(image.size == correctedCardImage.size)
                return "N의 조로아"
            },
            autoCaptureGate: PokemonCardAutoCaptureGate()
        )

        _ = try Self.processReady(&pipeline)
        _ = try Self.processReady(&pipeline)
        let result = try Self.processReady(&pipeline)
        let capture = try #require(result.capture)
        let namedCapture = await pipeline.completeCaptureName(for: capture)

        #expect(namedCapture.pokemonName == "N의 조로아")
        #expect(namedCapture.cropResult.cropImage.size == correctedCardImage.size)
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

    @Test
    func `Should surface orientation correction failure when crop exists`() {
        var pipeline = PokemonCardFramePipeline(
            detectCardShape: { _ in
                .success(Self.report(selectedDetection: Self.detection()))
            },
            cropCard: { _, _ in
                .success(Self.cropResult())
            },
            correctOrientation: { _ in
                .failure(.invalidImage)
            },
            extractPokemonName: { _ in nil },
            autoCaptureGate: PokemonCardAutoCaptureGate()
        )

        #expect(throws: PokemonCardPipelineError.orientationCorrectionFailed(.invalidImage)) {
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
        rect: CGRect = CGRect(x: 0.20, y: 0.20, width: 0.36, height: 0.50),
        corners: PokemonCardShapeQuadrilateral? = nil
    ) -> PokemonCardShapeDetection {
        PokemonCardShapeDetection(normalizedBoundingBox: rect, confidence: 0.90, normalizedCorners: corners)
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

    private static func titledCardImage(
        imageSize: CGSize,
        cardRect: CGRect,
        rotation: CGFloat
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: imageSize)

        return renderer.image { context in
            UIColor(red: 0.92, green: 0.92, blue: 0.90, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: imageSize))

            context.cgContext.saveGState()
            context.cgContext.translateBy(x: cardRect.midX, y: cardRect.midY)
            context.cgContext.rotate(by: rotation)
            context.cgContext.translateBy(x: -cardRect.midX, y: -cardRect.midY)

            UIColor.black.setFill()
            context.fill(cardRect)
            UIColor.white.setFill()
            context.fill(cardRect.insetBy(dx: 8, dy: 8))
            UIColor.red.setFill()
            context.fill(CGRect(x: cardRect.minX + 18, y: cardRect.minY + 16, width: 112, height: 24))
            UIColor.blue.setFill()
            context.fill(CGRect(x: cardRect.minX + 24, y: cardRect.maxY - 58, width: 132, height: 34))

            context.cgContext.restoreGState()
        }
    }

    private static func cropQuadrilateral(
        for rect: CGRect,
        in imageSize: CGSize,
        rotation: CGFloat
    ) -> PokemonCardCropQuadrilateral {
        let center = CGPoint(x: rect.midX, y: rect.midY)

        return PokemonCardCropQuadrilateral(
            topLeft: visionPoint(rotated(CGPoint(x: rect.minX, y: rect.minY), around: center, by: rotation), imageSize),
            topRight: visionPoint(
                rotated(CGPoint(x: rect.maxX, y: rect.minY), around: center, by: rotation), imageSize),
            bottomRight: visionPoint(
                rotated(CGPoint(x: rect.maxX, y: rect.maxY), around: center, by: rotation),
                imageSize
            ),
            bottomLeft: visionPoint(
                rotated(CGPoint(x: rect.minX, y: rect.maxY), around: center, by: rotation), imageSize)
        )
    }

    private static func rotated(
        _ point: CGPoint,
        around center: CGPoint,
        by radians: CGFloat
    ) -> CGPoint {
        let translatedX = point.x - center.x
        let translatedY = point.y - center.y

        return CGPoint(
            x: center.x + (translatedX * cos(radians)) - (translatedY * sin(radians)),
            y: center.y + (translatedX * sin(radians)) + (translatedY * cos(radians))
        )
    }

    private static func visionPoint(_ point: CGPoint, _ imageSize: CGSize) -> CGPoint {
        CGPoint(x: point.x / imageSize.width, y: 1 - (point.y / imageSize.height))
    }

    private static func averageColor(
        in normalizedRect: CGRect,
        image: UIImage
    ) -> (red: CGFloat, green: CGFloat, blue: CGFloat) {
        guard let cgImage = image.cgImage else { return (0, 0, 0) }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var bytes = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return (0, 0, 0) }
        guard
            let context = CGContext(
                data: &bytes,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            return (0, 0, 0)
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let sampleRect = CGRect(
            x: normalizedRect.minX * CGFloat(width),
            y: normalizedRect.minY * CGFloat(height),
            width: normalizedRect.width * CGFloat(width),
            height: normalizedRect.height * CGFloat(height)
        ).integral
        let minimumX = max(0, Int(sampleRect.minX))
        let minimumY = max(0, Int(sampleRect.minY))
        let maximumX = min(width, Int(sampleRect.maxX))
        let maximumY = min(height, Int(sampleRect.maxY))
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var count: CGFloat = 0

        for y in minimumY..<maximumY {
            for x in minimumX..<maximumX {
                let offset = (y * bytesPerRow) + (x * bytesPerPixel)
                red += CGFloat(bytes[offset]) / 255
                green += CGFloat(bytes[offset + 1]) / 255
                blue += CGFloat(bytes[offset + 2]) / 255
                count += 1
            }
        }

        guard count > 0 else { return (0, 0, 0) }

        return (red / count, green / count, blue / count)
    }

}
