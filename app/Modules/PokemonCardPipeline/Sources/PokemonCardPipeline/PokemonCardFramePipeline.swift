//
//  PokemonCardFramePipeline.swift
//  PokemonCardPipeline
//
//  Created by Kamaal M Farah on 5/25/26.
//

import CoreGraphics
import Foundation
import PokemonCardCropping
import PokemonCardDetection
import PokemonCardFocusQuality
import PokemonCardOrientationCorrection
import PokemonCardStability
import PokemonCardTextExtraction
import PokemonCardUtilities
import UIKit

public enum PokemonCardPipelineError: LocalizedError, Equatable, Sendable {
    case detectionFailed(PokemonCardShapeDetectionError)
    case cropFailed(PokemonCardCropError)
    case orientationCorrectionFailed(PokemonCardOrientationCorrectionError)

    public var errorDescription: String? {
        switch self {
        case .detectionFailed(let error):
            error.localizedDescription
        case .cropFailed(let error):
            error.localizedDescription
        case .orientationCorrectionFailed(let error):
            error.localizedDescription
        }
    }
}

public struct PokemonCardPipelineCapture: Sendable {
    private let originalImageSnapshot: PokemonCardImageSnapshot
    public let detection: PokemonCardShapeDetection
    public let cropResult: PokemonCardCropResult
    public let focusQuality: PokemonCardFocusQualityReport?
    public let pokemonName: String?

    public var originalImage: UIImage {
        originalImageSnapshot.image
    }

    public init(
        originalImage: UIImage,
        detection: PokemonCardShapeDetection,
        cropResult: PokemonCardCropResult,
        focusQuality: PokemonCardFocusQualityReport?,
        pokemonName: String?
    ) {
        self.originalImageSnapshot = PokemonCardImageSnapshot(image: originalImage)
        self.detection = detection
        self.cropResult = cropResult
        self.focusQuality = focusQuality
        self.pokemonName = pokemonName
    }
}

public struct PokemonCardPipelineFrameResult {
    public let detectionReport: PokemonCardShapeDetectionReport
    public let cropResult: PokemonCardCropResult?
    public let focusQuality: PokemonCardFocusQualityReport?
    public let autoCaptureDecision: PokemonCardAutoCaptureDecision
    public let capture: PokemonCardPipelineCapture?
}

public class PokemonCardFramePipeline {
    typealias DetectionStage = (UIImage) -> Result<PokemonCardShapeDetectionReport, PokemonCardShapeDetectionError>
    typealias CropStage = (UIImage, PokemonCardShapeDetection) -> Result<PokemonCardCropResult, PokemonCardCropError>
    typealias OrientationCorrectionStage = (PokemonCardCropResult) -> Result<
        PokemonCardCropResult,
        PokemonCardOrientationCorrectionError
    >
    typealias PokemonNameStage = @Sendable (UIImage) async -> String?

    private let detectCardShape: DetectionStage
    private let cropCard: CropStage
    private let correctOrientation: OrientationCorrectionStage
    private let extractPokemonName: PokemonNameStage
    private var autoCaptureGate: PokemonCardAutoCaptureGate
    private var bestFocusedFrames: [FocusedFrame] = []

    public convenience init() {
        self.init(
            detectCardShape: PokemonCardShapeDetector.detectCardShapeReport(in:),
            cropCard: { image, detection in
                PokemonCardCropper.cropCard(
                    from: image,
                    detectedNormalizedCardQuadrilateral: cropQuadrilateral(from: detection.normalizedCorners),
                    detectedNormalizedCardRect: detection.normalizedBoundingBox
                )
            },
            correctOrientation: Self.handleCorrectOrientation(of:),
            extractPokemonName: Self.handleExtractPokemonName(from:),
            autoCaptureGate: PokemonCardAutoCaptureGate()
        )
    }

    init(
        detectCardShape: @escaping DetectionStage,
        cropCard: @escaping CropStage,
        correctOrientation: @escaping OrientationCorrectionStage = { .success($0) },
        extractPokemonName: @escaping PokemonNameStage,
        autoCaptureGate: PokemonCardAutoCaptureGate
    ) {
        self.detectCardShape = detectCardShape
        self.cropCard = cropCard
        self.correctOrientation = correctOrientation
        self.extractPokemonName = extractPokemonName
        self.autoCaptureGate = autoCaptureGate
    }

    public func process(
        _ frame: UIImage,
        isFocusAdjusting: Bool,
        isFocusSettling: Bool
    ) -> Result<PokemonCardPipelineFrameResult, PokemonCardPipelineError> {
        let report: PokemonCardShapeDetectionReport
        switch detectCardShape(frame) {
        case .success(let value):
            report = value
        case .failure(let error):
            return .failure(.detectionFailed(error))
        }

        guard let detection = report.selectedDetection else {
            let decision = autoCaptureGate.evaluate(nil, focusQuality: nil)
            bestFocusedFrames = []
            return .success(
                PokemonCardPipelineFrameResult(
                    detectionReport: report,
                    cropResult: nil,
                    focusQuality: nil,
                    autoCaptureDecision: decision,
                    capture: nil
                ))
        }

        let rawCropResult: PokemonCardCropResult
        switch cropCard(frame, detection) {
        case .success(let value):
            rawCropResult = value
        case .failure(let error):
            return .failure(.cropFailed(error))
        }

        let cropResult: PokemonCardCropResult
        switch correctOrientation(rawCropResult) {
        case .success(let value):
            cropResult = value
        case .failure(let error):
            return .failure(.orientationCorrectionFailed(error))
        }

        let focusQuality = PokemonCardFocusQualityAnalyzer.evaluate(
            image: cropResult.cropImage,
            cardAreaFraction: detection.normalizedBoundingBox.standardized.areaFraction,
            isFocusAdjusting: isFocusAdjusting,
            isFocusSettling: isFocusSettling
        )
        let decision = autoCaptureGate.evaluate(
            detection,
            focusQuality: focusQuality,
            isFocusAdjusting: isFocusAdjusting,
            isFocusSettling: isFocusSettling
        )
        if decision.didResetStability {
            bestFocusedFrames = []
        }
        appendBestFrame(
            frame: frame,
            detection: detection,
            cropResult: cropResult,
            focusQuality: focusQuality
        )

        let capture = processCapture(decision: decision)

        return .success(
            PokemonCardPipelineFrameResult(
                detectionReport: report,
                cropResult: cropResult,
                focusQuality: focusQuality,
                autoCaptureDecision: decision,
                capture: capture
            ))
    }

    public func completeCaptureName(for capture: PokemonCardPipelineCapture) async -> PokemonCardPipelineCapture {
        let pokemonName = await extractPokemonName(capture.cropResult.cropImage)

        return PokemonCardPipelineCapture(
            originalImage: capture.originalImage,
            detection: capture.detection,
            cropResult: capture.cropResult,
            focusQuality: capture.focusQuality,
            pokemonName: pokemonName
        )
    }

    private func processCapture(decision: PokemonCardAutoCaptureDecision) -> PokemonCardPipelineCapture? {
        guard decision.shouldCapture else { return nil }

        let bestFocusedFrame = bestFocusedFrames.max(by: { $0.focusQuality.score < $1.focusQuality.score })
        guard let bestFocusedFrame else { return nil }

        return PokemonCardPipelineCapture(
            originalImage: bestFocusedFrame.originalImage,
            detection: bestFocusedFrame.detection,
            cropResult: bestFocusedFrame.cropResult,
            focusQuality: bestFocusedFrame.focusQuality,
            pokemonName: nil
        )
    }

    private static func handleExtractPokemonName(from image: UIImage) async -> String? {
        let result = await PokemonCardNameExtractor().extractName(from: image)
        guard case .success(let value) = result else { return nil }

        return value.pokemonName
    }

    private static func handleCorrectOrientation(
        of cropResult: PokemonCardCropResult
    ) -> Result<PokemonCardCropResult, PokemonCardOrientationCorrectionError> {
        let result = PokemonCardOrientationCorrector().correctOrientation(of: cropResult.cropImage)
        switch result {
        case .success(let correctionResult):
            return .success(
                PokemonCardCropResult(
                    originalImage: cropResult.originalImage,
                    cropImage: correctionResult.correctedImage,
                    cropRect: cropResult.cropRect,
                    normalizedCropRect: cropResult.normalizedCropRect,
                    isClippedToImageBounds: cropResult.isClippedToImageBounds
                ))
        case .failure(let error):
            return .failure(error)
        }
    }

    private func appendBestFrame(
        frame: UIImage,
        detection: PokemonCardShapeDetection,
        cropResult: PokemonCardCropResult,
        focusQuality: PokemonCardFocusQualityReport
    ) {
        guard focusQuality.isSharpEnough else { return }

        bestFocusedFrames.append(
            FocusedFrame(
                originalImage: frame,
                detection: detection,
                cropResult: cropResult,
                focusQuality: focusQuality
            ))
        if bestFocusedFrames.count > Self.maximumBestFrameCount {
            bestFocusedFrames.removeFirst(bestFocusedFrames.count - Self.maximumBestFrameCount)
        }
    }

    private static let maximumBestFrameCount = 8
}

private func cropQuadrilateral(
    from quadrilateral: PokemonCardShapeQuadrilateral?
) -> PokemonCardCropQuadrilateral? {
    guard let quadrilateral else { return nil }

    return PokemonCardCropQuadrilateral(
        topLeft: quadrilateral.topLeft,
        topRight: quadrilateral.topRight,
        bottomRight: quadrilateral.bottomRight,
        bottomLeft: quadrilateral.bottomLeft
    )
}

private struct FocusedFrame {
    let originalImage: UIImage
    let detection: PokemonCardShapeDetection
    let cropResult: PokemonCardCropResult
    let focusQuality: PokemonCardFocusQualityReport
}
