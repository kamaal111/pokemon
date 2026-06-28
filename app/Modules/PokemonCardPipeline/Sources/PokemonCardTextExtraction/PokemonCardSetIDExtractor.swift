//
//  PokemonCardSetIDExtractor.swift
//  PokemonCardPipeline
//
//  Created by Codex on 6/27/26.
//

import CoreGraphics
import Foundation
import PokemonCardUtilities
import UIKit
import Vision

public struct PokemonCardSetIDDebugImage: Identifiable, Sendable {
    private let imageSnapshot: PokemonCardImageSnapshot

    public let id: UUID
    public let label: String
    public let regionOfInterest: CGRect?

    init(
        id: UUID = UUID(),
        label: String,
        image: UIImage,
        regionOfInterest: CGRect? = nil
    ) {
        self.id = id
        self.label = label
        self.imageSnapshot = PokemonCardImageSnapshot(image: image)
        self.regionOfInterest = regionOfInterest
    }

    public var image: UIImage {
        imageSnapshot.image
    }
}

public struct PokemonCardSetIDDebugInfo: Equatable, Sendable {
    public let rawCandidates: [String]
    public let selectedCropLabel: String?
    public let debugImageLabels: [String]

    public init(
        rawCandidates: [String],
        selectedCropLabel: String?,
        debugImageLabels: [String]
    ) {
        self.rawCandidates = rawCandidates
        self.selectedCropLabel = selectedCropLabel
        self.debugImageLabels = debugImageLabels
    }
}

public struct PokemonCardSetIDExtractionResult: Sendable {
    public let setID: String?
    public let rawCandidates: [String]
    public let selectedCropLabel: String?
    public let debugImages: [PokemonCardSetIDDebugImage]

    public var debugInfo: PokemonCardSetIDDebugInfo {
        PokemonCardSetIDDebugInfo(
            rawCandidates: rawCandidates,
            selectedCropLabel: selectedCropLabel,
            debugImageLabels: debugImages.map(\.label)
        )
    }
}

public enum PokemonCardSetIDExtractionError: LocalizedError, Equatable, Sendable {
    case emptyCrop
    case textRecognitionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .emptyCrop:
            "The card set ID area could not be cropped."
        case .textRecognitionFailed(let message):
            "The card set ID could not be read. \(message)"
        }
    }
}

public struct PokemonCardSetIDExtractor: Sendable {
    private let recognizer: PokemonCardTextRecognizing

    public init() {
        self.init(recognizer: VisionPokemonCardTextRecognizer())
    }

    init(recognizer: PokemonCardTextRecognizing) {
        self.recognizer = recognizer
    }

    public func extractSetID(
        from image: UIImage
    ) async -> Result<PokemonCardSetIDExtractionResult, PokemonCardSetIDExtractionError> {
        let cropResult = PokemonCardSetIDCropper.crops(from: image)
        let crops: [PokemonCardSetIDCrop]
        switch cropResult {
        case .success(let value):
            crops = value
        case .failure:
            return .failure(.emptyCrop)
        }

        var rawCandidates: [String] = []
        var scoredCandidates: [ScoredSetIDCandidate] = []
        var firstRecognitionFailure: PokemonCardTextExtractionError?
        for (cropIndex, crop) in crops.enumerated() {
            let recognitionResult = await recognizer.recognizeText(
                in: crop.enhancedImage,
                configuration: Self.recognitionConfiguration
            )
            switch recognitionResult {
            case .success(let observations):
                let candidates = Self.candidates(from: observations, crop: crop, cropIndex: cropIndex)
                rawCandidates.append(contentsOf: candidates.map(\.rawText))
                scoredCandidates.append(contentsOf: candidates.compactMap(\.validCandidate))
            case .failure(let error):
                firstRecognitionFailure = firstRecognitionFailure ?? error
            }
        }

        if rawCandidates.isEmpty, let firstRecognitionFailure {
            return .failure(.textRecognitionFailed(firstRecognitionFailure.localizedDescription))
        }

        let debugImages = crops.flatMap { crop in
            [
                PokemonCardSetIDDebugImage(label: "\(crop.label)-raw", image: crop.image),
                PokemonCardSetIDDebugImage(label: "\(crop.label)-enhanced", image: crop.enhancedImage),
            ]
        }
        let selectedCandidate = scoredCandidates.sorted().first

        return .success(
            PokemonCardSetIDExtractionResult(
                setID: selectedCandidate?.setID,
                rawCandidates: rawCandidates,
                selectedCropLabel: selectedCandidate?.cropLabel,
                debugImages: debugImages
            ))
    }

    private static func candidates(
        from observations: [PokemonCardRawTextObservation],
        crop: PokemonCardSetIDCrop,
        cropIndex: Int
    ) -> [RawSetIDCandidate] {
        observations.flatMap { observation in
            observation.topCandidates.map { candidate in
                RawSetIDCandidate(
                    rawText: candidate.text,
                    confidence: candidate.confidence,
                    boundingBox: observation.boundingBox,
                    cropLabel: crop.label,
                    cropIndex: cropIndex
                )
            }
        }
    }

    private static let recognitionConfiguration = PokemonCardTextRecognizerConfiguration(
        recognitionLevel: .accurate,
        automaticallyDetectsLanguage: true,
        recognitionLanguages: [],
        minimumTextHeight: 0.004,
        regionOfInterest: nil
    )
}

private struct RawSetIDCandidate {
    let rawText: String
    let confidence: Float
    let boundingBox: CGRect
    let cropLabel: String
    let cropIndex: Int

    var validCandidate: ScoredSetIDCandidate? {
        guard let setID = PokemonCardFoundationModelMetadataNormalizer.normalizedSetID(rawText) else {
            return nil
        }

        return ScoredSetIDCandidate(
            setID: setID,
            rawText: rawText,
            confidence: confidence,
            boundingBox: boundingBox,
            cropLabel: cropLabel,
            cropIndex: cropIndex
        )
    }
}

private struct ScoredSetIDCandidate: Comparable {
    let setID: String
    let rawText: String
    let confidence: Float
    let boundingBox: CGRect
    let cropLabel: String
    let cropIndex: Int

    private var lowerLeftScore: CGFloat {
        let standardizedBox = boundingBox.standardized
        let leftScore = 1 - standardizedBox.midX
        let bottomScore = 1 - standardizedBox.midY

        return (leftScore * 0.12) + (bottomScore * 0.08)
    }

    private var score: CGFloat {
        CGFloat(confidence) + lowerLeftScore - (CGFloat(cropIndex) * 0.05)
    }

    static func < (lhs: ScoredSetIDCandidate, rhs: ScoredSetIDCandidate) -> Bool {
        if lhs.score != rhs.score {
            return lhs.score > rhs.score
        }

        if lhs.cropIndex != rhs.cropIndex {
            return lhs.cropIndex < rhs.cropIndex
        }

        return lhs.rawText < rhs.rawText
    }
}
