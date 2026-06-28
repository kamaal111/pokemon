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
import PokemonCardStability
import PokemonCardTextExtraction
import PokemonCardUtilities
import UIKit

public enum PokemonCardPipelineError: LocalizedError, Equatable, Sendable {
    case detectionFailed(PokemonCardShapeDetectionError)
    case cropFailed(PokemonCardCropError)

    public var errorDescription: String? {
        switch self {
        case .detectionFailed(let error):
            error.localizedDescription
        case .cropFailed(let error):
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
    public let setID: String?
    public let setIDDebugInfo: PokemonCardSetIDDebugInfo?
    public let setIDDebugImages: [PokemonCardSetIDDebugImage]
    public let metadataErrorMessage: String?

    public var originalImage: UIImage {
        originalImageSnapshot.image
    }

    public init(
        originalImage: UIImage,
        detection: PokemonCardShapeDetection,
        cropResult: PokemonCardCropResult,
        focusQuality: PokemonCardFocusQualityReport?,
        pokemonName: String?,
        setID: String? = nil,
        setIDDebugInfo: PokemonCardSetIDDebugInfo? = nil,
        setIDDebugImages: [PokemonCardSetIDDebugImage] = [],
        metadataErrorMessage: String? = nil
    ) {
        self.originalImageSnapshot = PokemonCardImageSnapshot(image: originalImage)
        self.detection = detection
        self.cropResult = cropResult
        self.focusQuality = focusQuality
        self.pokemonName = pokemonName
        self.setID = setID
        self.setIDDebugInfo = setIDDebugInfo
        self.setIDDebugImages = setIDDebugImages
        self.metadataErrorMessage = metadataErrorMessage
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
    typealias CropStage = (UIImage, CGRect) -> Result<PokemonCardCropResult, PokemonCardCropError>
    typealias PokemonNameStage = @Sendable (UIImage) async -> String?
    typealias FoundationModelMetadataStage =
        @Sendable (
            UIImage
        ) async -> Result<PokemonCardMetadataExtractionResult, PokemonCardMetadataExtractionError>

    private let detectCardShape: DetectionStage
    private let cropCard: CropStage
    private let extractPokemonName: PokemonNameStage
    private let extractFoundationModelMetadata: FoundationModelMetadataStage
    private let useFoundationModelsForCardTextExtraction: Bool
    private var autoCaptureGate: PokemonCardAutoCaptureGate
    private var bestFocusedFrames: [FocusedFrame] = []

    public convenience init(useFoundationModelsForCardTextExtraction: Bool = true) {
        self.init(
            detectCardShape: PokemonCardShapeDetector.detectCardShapeReport(in:),
            cropCard: { image, rect in
                PokemonCardCropper.cropCard(from: image, detectedNormalizedCardRect: rect)
            },
            extractPokemonName: Self.handleExtractPokemonName(from:),
            extractFoundationModelMetadata: Self.handleExtractFoundationModelMetadata(from:),
            useFoundationModelsForCardTextExtraction: useFoundationModelsForCardTextExtraction,
            autoCaptureGate: PokemonCardAutoCaptureGate()
        )
    }

    init(
        detectCardShape: @escaping DetectionStage,
        cropCard: @escaping CropStage,
        extractPokemonName: @escaping PokemonNameStage,
        extractFoundationModelMetadata: FoundationModelMetadataStage? = nil,
        useFoundationModelsForCardTextExtraction: Bool = true,
        autoCaptureGate: PokemonCardAutoCaptureGate
    ) {
        self.detectCardShape = detectCardShape
        self.cropCard = cropCard
        self.extractPokemonName = extractPokemonName
        self.extractFoundationModelMetadata =
            extractFoundationModelMetadata ?? { image in
                await Self.handleExtractFoundationModelMetadata(from: image)
            }
        self.useFoundationModelsForCardTextExtraction = useFoundationModelsForCardTextExtraction
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

        let cropResult: PokemonCardCropResult
        switch cropCard(frame, detection.normalizedBoundingBox) {
        case .success(let value):
            cropResult = value
        case .failure(let error):
            return .failure(.cropFailed(error))
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
            pokemonName: pokemonName,
            setID: capture.setID,
            setIDDebugInfo: capture.setIDDebugInfo,
            setIDDebugImages: capture.setIDDebugImages,
            metadataErrorMessage: capture.metadataErrorMessage
        )
    }

    public func completeCaptureMetadata(for capture: PokemonCardPipelineCapture) async -> PokemonCardPipelineCapture {
        guard useFoundationModelsForCardTextExtraction else {
            return await completeCaptureName(for: capture)
        }

        let image = capture.cropResult.cropImage
        let result = await extractFoundationModelMetadata(image)
        switch result {
        case .success(let metadata):
            return PokemonCardPipelineCapture(
                originalImage: capture.originalImage,
                detection: capture.detection,
                cropResult: capture.cropResult,
                focusQuality: capture.focusQuality,
                pokemonName: metadata.pokemonName,
                setID: metadata.setID,
                setIDDebugInfo: metadata.setIDDebugInfo,
                setIDDebugImages: metadata.setIDDebugImages,
                metadataErrorMessage: nil
            )
        case .failure(let error):
            let pokemonName = await extractPokemonName(image)
            return PokemonCardPipelineCapture(
                originalImage: capture.originalImage,
                detection: capture.detection,
                cropResult: capture.cropResult,
                focusQuality: capture.focusQuality,
                pokemonName: pokemonName,
                setID: nil,
                setIDDebugInfo: capture.setIDDebugInfo,
                setIDDebugImages: capture.setIDDebugImages,
                metadataErrorMessage: error.localizedDescription
            )
        }
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
            pokemonName: nil,
            setID: nil,
            setIDDebugInfo: nil,
            setIDDebugImages: [],
            metadataErrorMessage: nil
        )
    }

    private static func handleExtractPokemonName(from image: UIImage) async -> String? {
        let result = await PokemonCardNameExtractor().extractName(from: image)
        guard case .success(let value) = result else { return nil }

        return value.pokemonName
    }

    private static func handleExtractFoundationModelMetadata(
        from image: UIImage
    ) async -> Result<PokemonCardMetadataExtractionResult, PokemonCardMetadataExtractionError> {
        await PokemonCardFoundationModelMetadataExtractor().extractMetadata(from: image)
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

private struct FocusedFrame {
    let originalImage: UIImage
    let detection: PokemonCardShapeDetection
    let cropResult: PokemonCardCropResult
    let focusQuality: PokemonCardFocusQualityReport
}
