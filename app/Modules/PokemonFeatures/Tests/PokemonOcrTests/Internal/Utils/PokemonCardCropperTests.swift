//
//  PokemonCardCropperTests.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/19/26.
//

import Testing
import UIKit

@testable import PokemonOcr

@Suite("PokemonCardCropper Tests")
struct PokemonCardCropperTests {
    @Test
    func `Should expand candidate box to Pokemon card dimensions`() {
        let projection = PokemonCardCropper.cropProjection(
            forCandidate: CGRect(x: 100, y: 120, width: 320, height: 320),
            imageSize: CGSize(width: 800, height: 1_000),
            bufferFraction: 0
        )

        #expect(abs((projection.rect.width / projection.rect.height) - PokemonCardCropper.targetAspectRatio) < 0.001)
        #expect(abs(projection.rect.midX - 260) < 0.001)
        #expect(abs(projection.rect.midY - 280) < 0.001)
    }

    @Test
    func `Should apply crop buffer on both axes`() {
        let unbuffered = PokemonCardCropper.cropProjection(
            forCandidate: CGRect(x: 200, y: 200, width: 315, height: 440),
            imageSize: CGSize(width: 1_000, height: 1_000),
            bufferFraction: 0
        )
        let buffered = PokemonCardCropper.cropProjection(
            forCandidate: CGRect(x: 200, y: 200, width: 315, height: 440),
            imageSize: CGSize(width: 1_000, height: 1_000),
            bufferFraction: 0.08
        )

        #expect(abs(buffered.rect.width - (unbuffered.rect.width * 1.16)) < 0.001)
        #expect(abs(buffered.rect.height - (unbuffered.rect.height * 1.16)) < 0.001)
    }

    @Test
    func `Should clamp crop to image bounds and report clipping`() {
        let projection = PokemonCardCropper.cropProjection(
            forCandidate: CGRect(x: 5, y: 820, width: 260, height: 360),
            imageSize: CGSize(width: 600, height: 1_000),
            bufferFraction: 0.08
        )

        #expect(projection.rect.minX == 0)
        #expect(projection.rect.maxY == 1_000)
        #expect(projection.isClippedToImageBounds)
    }

    @Test
    func `Should never return zero-sized crop for edge candidate`() {
        let projection = PokemonCardCropper.cropProjection(
            forCandidate: CGRect(x: 0, y: 0, width: 1, height: 1),
            imageSize: CGSize(width: 20, height: 20),
            bufferFraction: 0.08
        )

        #expect(projection.rect.width > 0)
        #expect(projection.rect.height > 0)
    }

    @Test
    func `Should convert Vision normalized rectangle to image coordinates`() {
        let rect = PokemonCardCropper.imageRect(
            fromVisionNormalizedRect: CGRect(x: 0.20, y: 0.30, width: 0.40, height: 0.50),
            imageSize: CGSize(width: 1_000, height: 800)
        )

        #expect(abs(rect.minX - 200) < 0.001)
        #expect(abs(rect.minY - 160) < 0.001)
        #expect(abs(rect.width - 400) < 0.001)
        #expect(abs(rect.height - 400) < 0.001)
    }

    @Test
    func `Should crop detected normalized card rect with aspect expansion and buffer`() throws {
        let image = solidImage(size: CGSize(width: 1_000, height: 800))
        let result = try PokemonCardCropper.cropCard(
            from: image,
            detectedNormalizedCardRect: CGRect(x: 0.32, y: 0.20, width: 0.28, height: 0.50),
            configuration: .init(bufferFraction: 0.08, maxAnalysisDimension: 240)
        ).get()

        #expect(abs((result.cropRect.width / result.cropRect.height) - PokemonCardCropper.targetAspectRatio) < 0.001)
        #expect(result.cropRect.width > 280)
        #expect(result.cropRect.height > 400)
        #expect(!result.isClippedToImageBounds)
    }

    @Test
    func `Should clamp detected normalized card rect near edges and report clipping`() throws {
        let image = solidImage(size: CGSize(width: 600, height: 800))
        let result = try PokemonCardCropper.cropCard(
            from: image,
            detectedNormalizedCardRect: CGRect(x: 0.01, y: 0.02, width: 0.34, height: 0.50)
        ).get()

        #expect(result.cropRect.minX == 0)
        #expect(result.cropRect.maxY == image.size.height)
        #expect(result.isClippedToImageBounds)
    }

    @Test
    func `Should never return zero-sized crop for detected normalized rect`() throws {
        let image = solidImage(size: CGSize(width: 20, height: 20))
        let result = try PokemonCardCropper.cropCard(
            from: image,
            detectedNormalizedCardRect: CGRect(x: 0, y: 0, width: 0.01, height: 0.01)
        ).get()

        #expect(result.cropRect.width > 0)
        #expect(result.cropRect.height > 0)
        #expect(result.cropImage.size.width > 0)
        #expect(result.cropImage.size.height > 0)
    }

    @Test
    func `Should crop centered synthetic card`() throws {
        let cardRect = CGRect(x: 190, y: 100, width: 220, height: 308)
        let image = syntheticCardImage(cardRect: cardRect)
        let result = try PokemonCardCropper.cropCard(from: image).get()

        assert(result.cropRect, contains: cardRect)
        #expect(abs((result.cropRect.width / result.cropRect.height) - PokemonCardCropper.targetAspectRatio) < 0.04)
        #expect(!result.isClippedToImageBounds)
    }

    @Test
    func `Should crop off-center synthetic card`() throws {
        let cardRect = CGRect(x: 52, y: 132, width: 190, height: 266)
        let image = syntheticCardImage(cardRect: cardRect)
        let result = try PokemonCardCropper.cropCard(from: image).get()

        assert(result.cropRect, contains: cardRect)
        #expect(result.cropRect.midX < image.size.width / 2)
        #expect(!result.isClippedToImageBounds)
    }

    @Test
    func `Should crop card near image edge`() throws {
        let cardRect = CGRect(x: 430, y: 210, width: 190, height: 266)
        let image = syntheticCardImage(cardRect: cardRect)
        let result = try PokemonCardCropper.cropCard(from: image).get()

        #expect(result.cropRect.intersection(cardRect).width > cardRect.width * 0.85)
        #expect(result.cropRect.intersection(cardRect).height > cardRect.height * 0.95)
        #expect(result.cropRect.maxX <= image.size.width)
        #expect(result.isClippedToImageBounds)
    }

    @Test
    func `Should crop skew-looking card content without exact border lines`() throws {
        let cardRect = CGRect(x: 178, y: 92, width: 230, height: 322)
        let image = syntheticCardImage(cardRect: cardRect, rotation: 0.08, drawsBorder: false)
        let result = try PokemonCardCropper.cropCard(from: image).get()

        #expect(result.cropRect.intersection(cardRect).width > cardRect.width * 0.9)
        #expect(result.cropRect.intersection(cardRect).height > cardRect.height * 0.9)
    }

    @Test
    func `Should prefer card over background rectangles`() throws {
        let cardRect = CGRect(x: 300, y: 116, width: 188, height: 263)
        let distractor = CGRect(x: 30, y: 36, width: 220, height: 120)
        let image = syntheticCardImage(cardRect: cardRect, backgroundRectangles: [distractor])
        let result = try PokemonCardCropper.cropCard(from: image).get()

        assert(result.cropRect, contains: cardRect)
        #expect(!result.cropRect.contains(distractor))
    }

    @Test
    func `Should crop darker colorful card on light tabletop`() throws {
        let cardRect = CGRect(x: 330, y: 245, width: 260, height: 364)
        let image = syntheticCardImage(
            imageSize: CGSize(width: 900, height: 820),
            cardRect: cardRect,
            backgroundColor: UIColor(red: 0.90, green: 0.89, blue: 0.84, alpha: 1)
        )
        let result = try PokemonCardCropper.cropCard(from: image).get()

        #expect(result.cropRect.intersection(cardRect).width > cardRect.width * 0.92)
        #expect(result.cropRect.intersection(cardRect).height > cardRect.height * 0.92)
        #expect(result.normalizedCropRect.width < 0.46)
        #expect(result.normalizedCropRect.height < 0.62)
    }

    @Test
    func `Should crop real Meowth camera sample`() throws {
        let image = try sampleImage("camera-meowth")
        let result = try PokemonCardCropper.cropCard(from: image).get()
        let expectedVisibleCardRect = CGRect(x: 0.29, y: 0.50, width: 0.32, height: 0.43)

        #expect(result.cropRect.width < result.originalImage.size.width * 0.55)
        #expect(result.cropRect.height < result.originalImage.size.height * 0.65)
        #expect(result.cropRect.width > result.originalImage.size.width * 0.25)
        #expect(result.cropRect.height > result.originalImage.size.height * 0.35)
        #expect(abs((result.cropRect.width / result.cropRect.height) - PokemonCardCropper.targetAspectRatio) < 0.1)
        #expect(normalizedIntersection(result.normalizedCropRect, expectedVisibleCardRect) > 0.78)
        #expect(result.normalizedCropRect.height < 0.62)
        #expect(result.cropImage.size.width > 0)
        #expect(result.cropImage.size.height > 0)
    }

    private func syntheticCardImage(
        imageSize: CGSize = CGSize(width: 600, height: 520),
        cardRect: CGRect,
        rotation: CGFloat = 0,
        drawsBorder: Bool = true,
        backgroundColor: UIColor = UIColor(red: 0.08, green: 0.09, blue: 0.10, alpha: 1),
        backgroundRectangles: [CGRect] = []
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: imageSize)

        return renderer.image { context in
            backgroundColor.setFill()
            context.fill(CGRect(origin: .zero, size: imageSize))

            for rectangle in backgroundRectangles {
                UIColor(red: 0.35, green: 0.37, blue: 0.39, alpha: 1).setFill()
                context.fill(rectangle)
            }

            context.cgContext.saveGState()
            context.cgContext.translateBy(x: cardRect.midX, y: cardRect.midY)
            context.cgContext.rotate(by: rotation)
            context.cgContext.translateBy(x: -cardRect.midX, y: -cardRect.midY)

            if drawsBorder {
                UIColor(red: 0.76, green: 0.76, blue: 0.70, alpha: 1).setFill()
                context.fill(cardRect)
            }

            UIColor(red: 0.92, green: 0.91, blue: 0.82, alpha: 1).setFill()
            context.fill(cardRect.insetBy(dx: 12, dy: 12))

            UIColor(red: 0.32, green: 0.18, blue: 0.60, alpha: 1).setFill()
            context.fill(
                CGRect(
                    x: cardRect.minX + 28,
                    y: cardRect.minY + 70,
                    width: cardRect.width - 56,
                    height: cardRect.height * 0.34
                ))

            UIColor(red: 0.18, green: 0.46, blue: 0.76, alpha: 1).setFill()
            context.fill(
                CGRect(
                    x: cardRect.minX + 34,
                    y: cardRect.minY + 96,
                    width: cardRect.width - 68,
                    height: cardRect.height * 0.18
                ))

            context.cgContext.restoreGState()
        }
    }

    private func solidImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func assert(_ rect: CGRect, contains expected: CGRect) {
        #expect(rect.minX <= expected.minX + 8)
        #expect(rect.minY <= expected.minY + 8)
        #expect(rect.maxX >= expected.maxX - 8)
        #expect(rect.maxY >= expected.maxY - 8)
    }

    private func normalizedIntersection(_ first: CGRect, _ second: CGRect) -> CGFloat {
        let intersection = first.intersection(second)
        guard !intersection.isNull else { return 0 }

        return (intersection.width * intersection.height) / (second.width * second.height)
    }
}
