//
//  PokemonCardFramePipeline.swift
//  PokemonCardPipeline
//
//  Created by Kamaal M Farah on 5/25/26.
//

import CoreGraphics
import PokemonCardCropping
import PokemonCardDetection
import PokemonCardStability
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

public struct PokemonCardPipelineCapture {
    public let originalImage: UIImage
    public let detection: PokemonCardShapeDetection
    public let cropResult: PokemonCardCropResult
}

public struct PokemonCardPipelineFrameResult {
    public let detectionReport: PokemonCardShapeDetectionReport
    public let cropResult: PokemonCardCropResult?
    public let capture: PokemonCardPipelineCapture?
}

public struct PokemonCardFramePipeline {
    typealias DetectionStage = (UIImage) -> Result<PokemonCardShapeDetectionReport, PokemonCardShapeDetectionError>
    typealias CropStage = (UIImage, CGRect) -> Result<PokemonCardCropResult, PokemonCardCropError>

    private let detectCardShape: DetectionStage
    private let cropCard: CropStage
    private var autoCaptureGate: PokemonCardAutoCaptureGate

    public init() {
        self.init(
            detectCardShape: PokemonCardShapeDetector.detectCardShapeReport(in:),
            cropCard: { image, rect in
                PokemonCardCropper.cropCard(from: image, detectedNormalizedCardRect: rect)
            },
            autoCaptureGate: PokemonCardAutoCaptureGate()
        )
    }

    init(
        detectCardShape: @escaping DetectionStage,
        cropCard: @escaping CropStage,
        autoCaptureGate: PokemonCardAutoCaptureGate
    ) {
        self.detectCardShape = detectCardShape
        self.cropCard = cropCard
        self.autoCaptureGate = autoCaptureGate
    }

    public mutating func process(_ frame: UIImage) -> Result<PokemonCardPipelineFrameResult, PokemonCardPipelineError> {
        let report: PokemonCardShapeDetectionReport
        switch detectCardShape(frame) {
        case .success(let value):
            report = value
        case .failure(let error):
            return .failure(.detectionFailed(error))
        }

        guard let detection = report.selectedDetection else {
            _ = autoCaptureGate.shouldCapture(nil)
            return .success(
                PokemonCardPipelineFrameResult(
                    detectionReport: report,
                    cropResult: nil,
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

        let capture: PokemonCardPipelineCapture? =
            if autoCaptureGate.shouldCapture(detection) {
                PokemonCardPipelineCapture(
                    originalImage: frame,
                    detection: detection,
                    cropResult: cropResult
                )
            } else {
                nil
            }

        return .success(
            PokemonCardPipelineFrameResult(
                detectionReport: report,
                cropResult: cropResult,
                capture: capture
            ))
    }
}
