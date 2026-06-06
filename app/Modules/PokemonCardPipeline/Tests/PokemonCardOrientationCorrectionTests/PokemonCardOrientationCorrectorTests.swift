//
//  PokemonCardOrientationCorrectorTests.swift
//  PokemonCardPipeline
//
//  Created by Codex on 6/6/26.
//

import CoreGraphics
import Foundation
import PokemonCardTextRecognition
import Testing
import UIKit

@testable import PokemonCardCropping
@testable import PokemonCardDetection
@testable import PokemonCardOrientationCorrection
@testable import PokemonCardTextExtraction

@Suite("PokemonCardOrientationCorrector Tests")
struct PokemonCardOrientationCorrectorTests {
    @Test
    func `Should rotate synthetic card candidates upright`() throws {
        let cases: [(inputRotation: PokemonCardOrientationRotation, correction: PokemonCardOrientationRotation)] = [
            (.none, .none),
            (.clockwise90, .counterclockwise90),
            (.clockwise180, .clockwise180),
            (.counterclockwise90, .clockwise90),
        ]

        for testCase in cases {
            let image = Self.rotated(Self.syntheticCardImage(), by: testCase.inputRotation)
            let recognizer = FakePokemonCardTextRecognizer(
                responses: Self.responses(selecting: testCase.correction, for: image)
            )
            let corrector = PokemonCardOrientationCorrector(recognizer: recognizer)

            let result = try corrector.correctOrientation(of: image).get()

            #expect(result.selectedRotation == testCase.correction)
            #expect(result.correctedImage.size.height >= result.correctedImage.size.width)
            #expect(recognizer.requestedImageSizes.count == 2)
        }
    }

    @Test
    func `Should prefer top title text over attack text`() throws {
        let recognizer = FakePokemonCardTextRecognizer(responses: [
            [
                rawObservation(text: "120", confidence: 0.99, box: CGRect(x: 0.36, y: 0.42, width: 0.18, height: 0.08))
            ],
            [
                rawObservation(
                    text: "N의 조로아",
                    confidence: 0.62,
                    box: CGRect(x: 0.22, y: 0.86, width: 0.34, height: 0.05))
            ],
        ])
        let corrector = PokemonCardOrientationCorrector(recognizer: recognizer)

        let result = try corrector.correctOrientation(of: Self.syntheticCardImage()).get()

        #expect(result.selectedRotation == .clockwise180)
    }

    @Test
    func `Should reject footer mechanics as title evidence`() throws {
        let recognizer = FakePokemonCardTextRecognizer(responses: [
            [
                rawObservation(
                    text: "저항력",
                    confidence: 0.99,
                    box: CGRect(x: 0.22, y: 0.86, width: 0.20, height: 0.05))
            ],
            [
                rawObservation(
                    text: "N의 조로아",
                    confidence: 0.68,
                    box: CGRect(x: 0.22, y: 0.86, width: 0.34, height: 0.05))
            ],
        ])
        let corrector = PokemonCardOrientationCorrector(recognizer: recognizer)

        let result = try corrector.correctOrientation(of: Self.syntheticCardImage()).get()

        #expect(result.selectedRotation == .clockwise180)
    }

    @Test
    func `Should not flip upright portrait card for centered attack text`() throws {
        let recognizer = FakePokemonCardTextRecognizer(responses: [
            [
                rawObservation(
                    text: "N의 조로아",
                    confidence: 0.70,
                    box: CGRect(x: 0.16, y: 0.86, width: 0.34, height: 0.05))
            ],
            [
                rawObservation(
                    text: "할퀴기",
                    confidence: 0.95,
                    box: CGRect(x: 0.36, y: 0.86, width: 0.24, height: 0.05))
            ],
        ])
        let corrector = PokemonCardOrientationCorrector(recognizer: recognizer)

        let result = try corrector.correctOrientation(of: Self.syntheticCardImage()).get()

        #expect(result.selectedRotation == .none)
    }

    @Test
    func `Should not rotate portrait crop sideways from OCR noise`() throws {
        let recognizer = FakePokemonCardTextRecognizer(responses: [
            [
                rawObservation(
                    text: "N의 조로아",
                    confidence: 0.62,
                    box: CGRect(x: 0.18, y: 0.86, width: 0.34, height: 0.05))
            ],
            [],
        ])
        let corrector = PokemonCardOrientationCorrector(recognizer: recognizer)

        let result = try corrector.correctOrientation(of: Self.syntheticCardImage()).get()

        #expect(result.selectedRotation == .none)
        #expect(result.correctedImage.size.height >= result.correctedImage.size.width)
        #expect(recognizer.requestedImageSizes.count == 2)
        #expect(recognizer.requestedImageSizes.allSatisfy { $0.height >= $0.width })
    }

    @Test
    func `Should keep low confidence portrait card unchanged`() throws {
        let recognizer = FakePokemonCardTextRecognizer(responses: [[], [], [], []])
        let corrector = PokemonCardOrientationCorrector(recognizer: recognizer)

        let result = try corrector.correctOrientation(of: Self.syntheticCardImage()).get()

        #expect(result.selectedRotation == .none)
        #expect(result.correctedImage.size == Self.syntheticCardImage().size)
    }

    @Test
    func `Should crop and orient sideways Zorua sample as portrait`() throws {
        let image = Self.resizedToFit(
            try Self.sampleImage("N의 조로아-sideways"),
            maxLongSide: 1_200
        )
        let detection = try #require(
            try PokemonCardShapeDetector.detectCardShapeReport(in: image).get().selectedDetection)
        let cropResult = try PokemonCardCropper.cropCard(
            from: image,
            detectedNormalizedCardRect: detection.normalizedBoundingBox
        ).get()

        #expect(cropResult.cropImage.size.width > cropResult.cropImage.size.height)

        let recognizer = FakePokemonCardTextRecognizer(responses: [
            [
                rawObservation(
                    text: "N의 조로아",
                    confidence: 0.92,
                    box: CGRect(x: 0.18, y: 0.86, width: 0.34, height: 0.05))
            ],
            [],
        ])
        let correctionResult = try PokemonCardOrientationCorrector(recognizer: recognizer)
            .correctOrientation(of: cropResult.cropImage)
            .get()

        #expect(correctionResult.correctedImage.size.height > correctionResult.correctedImage.size.width)
        #expect(correctionResult.selectedRotation == .clockwise90)
        #expect(recognizer.requestedImageSizes.count == 2)
        #expect(recognizer.requestedImageSizes.allSatisfy { $0.height > $0.width })
        #expect(
            correctionResult.evidence.contains { evidence in
                evidence.rotation == correctionResult.selectedRotation && evidence.observationCount > 0
            })
    }

    @Test
    func `Should extract Zorua name after correcting sideways sample`() async throws {
        let image = Self.resizedToFit(
            try Self.sampleImage("N의 조로아-sideways"),
            maxLongSide: 1_200
        )
        let detection = try #require(
            try PokemonCardShapeDetector.detectCardShapeReport(in: image).get().selectedDetection)
        let cropResult = try PokemonCardCropper.cropCard(
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
        ).get()
        let correctionResult = try PokemonCardOrientationCorrector()
            .correctOrientation(of: cropResult.cropImage)
            .get()
        let extractionResult = try await PokemonCardNameExtractor()
            .extractName(from: correctionResult.correctedImage)
            .get()

        #expect(correctionResult.correctedImage.size.height > correctionResult.correctedImage.size.width)
        #expect(
            extractionResult.pokemonName == "N의 조로아",
            """
            rotation=\(correctionResult.selectedRotation.rawValue)
            evidence=\(correctionResult.evidence.map { "\($0.rotation.rawValue):\($0.score):\($0.topText)" })
            selected=\(String(describing: extractionResult.selectedCandidate))
            candidates=\(extractionResult.rawCandidates.prefix(12).map { "\($0.normalizedText)@\($0.boundingBox)" })
            """
        )
    }

    private static func responses(
        selecting selectedRotation: PokemonCardOrientationRotation,
        for image: UIImage
    ) -> [[PokemonCardRawTextObservation]] {
        let rotations: [PokemonCardOrientationRotation] =
            image.size.height >= image.size.width
            ? [.none, .clockwise180]
            : [.clockwise90, .counterclockwise90]

        return rotations.map { rotation in
            guard rotation == selectedRotation else { return [] }

            return [
                rawObservation(
                    text: "N의 조로아",
                    confidence: 0.92,
                    box: CGRect(x: 0.22, y: 0.86, width: 0.34, height: 0.05)
                )
            ]
        }
    }

    private static func sampleImage(_ name: String) throws -> UIImage {
        let url =
            Bundle.module.url(forResource: name, withExtension: "jpg")
            ?? Bundle.module.url(forResource: name, withExtension: "jpg", subdirectory: "SampleCards")
            ?? Bundle.module.urls(forResourcesWithExtension: "jpg", subdirectory: nil)?
            .first { $0.lastPathComponent == "\(name).jpg" }
            ?? Bundle.module.urls(forResourcesWithExtension: "jpg", subdirectory: "SampleCards")?
            .first { $0.lastPathComponent == "\(name).jpg" }

        guard let url else {
            throw PokemonCardOrientationCorrectionTestError.missingSample(name)
        }

        guard let image = UIImage(contentsOfFile: url.path) else {
            throw PokemonCardOrientationCorrectionTestError.missingSample(name)
        }

        return image
    }

    private static func resizedToFit(
        _ image: UIImage,
        maxLongSide: CGFloat
    ) -> UIImage {
        let longestSide = max(image.size.width, image.size.height)
        guard longestSide > maxLongSide else { return image }

        let scale = maxLongSide / longestSide
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private static func syntheticCardImage(size: CGSize = CGSize(width: 240, height: 336)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            UIColor.black.setFill()
            context.fill(CGRect(x: 52, y: 24, width: 118, height: 8))
            context.fill(CGRect(x: 52, y: 38, width: 86, height: 5))

            UIColor.systemYellow.setFill()
            context.fill(CGRect(x: 20, y: 92, width: 200, height: 150))

            UIColor.black.setFill()
            context.fill(CGRect(x: 36, y: 274, width: 126, height: 6))
            context.fill(CGRect(x: 36, y: 290, width: 86, height: 6))
        }
    }

    private static func rotated(
        _ image: UIImage,
        by rotation: PokemonCardOrientationRotation
    ) -> UIImage {
        switch rotation {
        case .none:
            image
        case .clockwise90:
            rotate(image, radians: .pi / 2, outputSize: CGSize(width: image.size.height, height: image.size.width))
        case .clockwise180:
            rotate(image, radians: .pi, outputSize: image.size)
        case .counterclockwise90:
            rotate(image, radians: -.pi / 2, outputSize: CGSize(width: image.size.height, height: image.size.width))
        }
    }

    private static func rotate(
        _ image: UIImage,
        radians: CGFloat,
        outputSize: CGSize
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: outputSize)

        return renderer.image { context in
            context.cgContext.translateBy(x: outputSize.width / 2, y: outputSize.height / 2)
            context.cgContext.rotate(by: radians)
            image.draw(
                in: CGRect(
                    x: -image.size.width / 2,
                    y: -image.size.height / 2,
                    width: image.size.width,
                    height: image.size.height
                ))
        }
    }
}

private final class FakePokemonCardTextRecognizer: PokemonCardTextRecognizing, @unchecked Sendable {
    private var responses: [[PokemonCardRawTextObservation]]
    private(set) var requestedImageSizes: [CGSize] = []

    init(responses: [[PokemonCardRawTextObservation]]) {
        self.responses = responses
    }

    func recognizeText(
        in image: UIImage,
        configuration: PokemonCardTextRecognizerConfiguration
    ) -> Result<[PokemonCardRawTextObservation], PokemonCardTextRecognitionError> {
        requestedImageSizes.append(image.size)

        guard !responses.isEmpty else {
            return .success([])
        }

        return .success(responses.removeFirst())
    }
}

private func rawObservation(
    text: String,
    confidence: Float,
    box: CGRect
) -> PokemonCardRawTextObservation {
    PokemonCardRawTextObservation(
        text: text,
        topCandidates: [PokemonCardRecognizedTextCandidate(text: text, confidence: confidence)],
        confidence: confidence,
        boundingBox: box
    )
}

private enum PokemonCardOrientationCorrectionTestError: Error {
    case missingSample(String)
}
