//
//  PokemonCardOrientationCorrector.swift
//  PokemonCardPipeline
//
//  Created by Codex on 6/6/26.
//

import CoreGraphics
import Foundation
import PokemonCardImageProcessing
import PokemonCardTextRecognition
import PokemonCardUtilities
import UIKit
import Vision

public enum PokemonCardOrientationCorrectionError: LocalizedError, Equatable, Sendable {
    case invalidImage
    case textRecognitionFailed

    public var errorDescription: String? {
        switch self {
        case .invalidImage:
            "The card image could not be prepared for orientation correction."
        case .textRecognitionFailed:
            "The card orientation could not be determined from recognized text."
        }
    }
}

public enum PokemonCardOrientationRotation: String, Equatable, Hashable, Sendable, CaseIterable {
    case none
    case clockwise90
    case clockwise180
    case counterclockwise90
}

public struct PokemonCardOrientationEvidence: Equatable, Sendable {
    public let rotation: PokemonCardOrientationRotation
    public let score: CGFloat
    public let observationCount: Int
    public let topText: [String]

    public init(
        rotation: PokemonCardOrientationRotation,
        score: CGFloat,
        observationCount: Int,
        topText: [String]
    ) {
        self.rotation = rotation
        self.score = score
        self.observationCount = observationCount
        self.topText = topText
    }
}

public struct PokemonCardOrientationCorrectionResult: Sendable {
    private let originalImageSnapshot: PokemonCardImageSnapshot
    private let correctedImageSnapshot: PokemonCardImageSnapshot
    public let selectedRotation: PokemonCardOrientationRotation
    public let score: CGFloat
    public let evidence: [PokemonCardOrientationEvidence]

    public var originalImage: UIImage {
        originalImageSnapshot.image
    }

    public var correctedImage: UIImage {
        correctedImageSnapshot.image
    }

    public init(
        originalImage: UIImage,
        correctedImage: UIImage,
        selectedRotation: PokemonCardOrientationRotation,
        score: CGFloat,
        evidence: [PokemonCardOrientationEvidence]
    ) {
        self.originalImageSnapshot = PokemonCardImageSnapshot(image: originalImage)
        self.correctedImageSnapshot = PokemonCardImageSnapshot(image: correctedImage)
        self.selectedRotation = selectedRotation
        self.score = score
        self.evidence = evidence
    }
}

public struct PokemonCardOrientationCorrector: Sendable {
    struct Configuration: Sendable {
        let minimumPortraitScore: CGFloat
        let minimumPortraitFlipWinningMargin: CGFloat
        let minimumPortraitFlipTitleEvidence: CGFloat
        let minimumLandscapeWinningMargin: CGFloat
        let minimumLandscapeScore: CGFloat

        static let `default` = Configuration(
            minimumPortraitScore: 0.36,
            minimumPortraitFlipWinningMargin: 0.60,
            minimumPortraitFlipTitleEvidence: 0.35,
            minimumLandscapeWinningMargin: 0.20,
            minimumLandscapeScore: 0.18
        )
    }

    private let recognizer: PokemonCardTextRecognizing
    private let configuration: Configuration

    public init() {
        self.init(recognizer: VisionPokemonCardTextRecognizer(), configuration: .default)
    }

    init(
        recognizer: PokemonCardTextRecognizing,
        configuration: Configuration = .default
    ) {
        self.recognizer = recognizer
        self.configuration = configuration
    }

    public func correctOrientation(
        of image: UIImage
    ) -> Result<PokemonCardOrientationCorrectionResult, PokemonCardOrientationCorrectionError> {
        let normalizedImage = PokemonCardImageNormalizer.normalizedForPokemonOcr(image)
        guard normalizedImage.size.width > 0 else { return .failure(.invalidImage) }
        guard normalizedImage.size.height > 0 else { return .failure(.invalidImage) }
        guard normalizedImage.cgImage != nil else { return .failure(.invalidImage) }

        let candidates = candidateRotations(for: normalizedImage).map { rotation in
            OrientationCandidate(rotation: rotation, image: rotated(normalizedImage, by: rotation))
        }
        let scoredCandidates = candidates.compactMap { candidate -> ScoredOrientationCandidate? in
            let result = recognizer.recognizeText(
                in: candidate.image,
                configuration: Self.recognitionConfiguration
            )
            guard case .success(let observations) = result else { return nil }

            return ScoredOrientationCandidate(
                candidate: candidate,
                observations: observations,
                score: score(observations: observations, imageSize: candidate.image.size)
            )
        }

        guard !scoredCandidates.isEmpty else {
            if isPortrait(normalizedImage) {
                return .success(result(for: normalizedImage, selected: nil, scoredCandidates: []))
            }

            return .failure(.textRecognitionFailed)
        }

        let selected = selectCandidate(from: scoredCandidates, originalImage: normalizedImage)

        return .success(result(for: normalizedImage, selected: selected, scoredCandidates: scoredCandidates))
    }

    private func selectCandidate(
        from candidates: [ScoredOrientationCandidate],
        originalImage: UIImage
    ) -> ScoredOrientationCandidate? {
        let sortedCandidates = candidates.sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.candidate.rotation.sortPriority < rhs.candidate.rotation.sortPriority
            }

            return lhs.score > rhs.score
        }
        guard let bestCandidate = sortedCandidates.first else { return nil }

        if isPortrait(originalImage) {
            return selectPortraitCandidate(bestCandidate, from: candidates)
        }

        let landscapeCandidates = candidates.filter {
            $0.candidate.rotation == .clockwise90 || $0.candidate.rotation == .counterclockwise90
        }
        let sortedLandscapeCandidates = landscapeCandidates.sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.candidate.rotation.sortPriority < rhs.candidate.rotation.sortPriority
            }

            return lhs.score > rhs.score
        }
        guard let bestLandscapeCandidate = sortedLandscapeCandidates.first else { return nil }
        guard bestLandscapeCandidate.score >= configuration.minimumLandscapeScore else { return nil }

        let oppositeRotation: PokemonCardOrientationRotation =
            bestLandscapeCandidate.candidate.rotation == .clockwise90 ? .counterclockwise90 : .clockwise90
        let oppositeCandidate = candidates.first { $0.candidate.rotation == oppositeRotation }
        let oppositeScore = oppositeCandidate?.score ?? 0
        let winningMargin = landscapeWinningMargin(
            for: bestLandscapeCandidate,
            against: oppositeCandidate
        )
        guard bestLandscapeCandidate.score >= oppositeScore + winningMargin else {
            return nil
        }

        return bestLandscapeCandidate
    }

    private func landscapeWinningMargin(
        for bestCandidate: ScoredOrientationCandidate,
        against oppositeCandidate: ScoredOrientationCandidate?
    ) -> CGFloat {
        let bestHeaderCueScore = headerCueScore(in: bestCandidate.observations)
        let oppositeHeaderCueScore = oppositeCandidate.map { headerCueScore(in: $0.observations) } ?? 0
        guard bestHeaderCueScore >= oppositeHeaderCueScore + 0.5 else {
            return configuration.minimumLandscapeWinningMargin
        }

        return 0.04
    }

    private func selectPortraitCandidate(
        _ bestCandidate: ScoredOrientationCandidate,
        from candidates: [ScoredOrientationCandidate]
    ) -> ScoredOrientationCandidate? {
        let currentCandidate = candidates.first { $0.candidate.rotation == .none }
        let flippedCandidate = candidates.first { $0.candidate.rotation == .clockwise180 }

        if bestCandidate.candidate.rotation == .none {
            guard bestCandidate.score >= configuration.minimumPortraitScore else { return nil }

            return bestCandidate
        }

        guard bestCandidate.candidate.rotation == .clockwise180 else {
            return currentCandidate?.score ?? 0 >= configuration.minimumPortraitScore ? currentCandidate : nil
        }
        guard bestCandidate.score >= configuration.minimumPortraitScore else { return nil }

        let currentScore = currentCandidate?.score ?? 0
        let flippedTitleEvidence = flippedCandidate?.titleBandEvidenceScore ?? 0
        guard flippedTitleEvidence >= configuration.minimumPortraitFlipTitleEvidence else {
            return currentScore >= configuration.minimumPortraitScore ? currentCandidate : nil
        }
        guard bestCandidate.score >= currentScore + configuration.minimumPortraitFlipWinningMargin else {
            return currentScore >= configuration.minimumPortraitScore ? currentCandidate : nil
        }

        return bestCandidate
    }

    private func result(
        for originalImage: UIImage,
        selected: ScoredOrientationCandidate?,
        scoredCandidates: [ScoredOrientationCandidate]
    ) -> PokemonCardOrientationCorrectionResult {
        let correctedImage = selected?.candidate.image ?? originalImage
        let selectedRotation = selected?.candidate.rotation ?? .none

        return PokemonCardOrientationCorrectionResult(
            originalImage: originalImage,
            correctedImage: correctedImage,
            selectedRotation: selectedRotation,
            score: selected?.score ?? 0,
            evidence: scoredCandidates.map(\.evidence).sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.rotation.sortPriority < rhs.rotation.sortPriority
                }

                return lhs.score > rhs.score
            }
        )
    }

    private func score(
        observations: [PokemonCardRawTextObservation],
        imageSize: CGSize
    ) -> CGFloat {
        guard imageSize.width > 0 else { return 0 }
        guard imageSize.height > 0 else { return 0 }

        let portraitBonus = imageSize.height >= imageSize.width ? CGFloat(0.35) : 0
        let observationScore = observations.reduce(CGFloat(0)) { partialScore, observation in
            partialScore + score(observation)
        }

        return portraitBonus + observationScore
    }

    private func score(_ observation: PokemonCardRawTextObservation) -> CGFloat {
        let box = observation.boundingBox.standardized
        guard box.width > 0 else { return 0 }
        guard box.height > 0 else { return 0 }

        let regionWeight = regionWeight(for: box)
        let confidence = max(0, min(CGFloat(observation.confidence), 1))
        let textWeight = textWeight(for: observation.text)
        let sizeWeight = max(0.20, min(box.height * 10, 1.20))
        if isTopRightHitPointsCue(observation.text, box: box) {
            return confidence * 6.0 * sizeWeight
        }

        let titleBandPenalty: CGFloat =
            isTitleBand(box) && Self.containsRejectedTitleFragment(observation.text) ? -2.0 : 0

        return confidence * ((regionWeight * textWeight * sizeWeight) + titleBandPenalty)
    }

    private func regionWeight(for box: CGRect) -> CGFloat {
        let centerY = box.midY
        let centerX = box.midX

        if isTitleBand(box), centerX <= 0.82 {
            return 7.0
        }
        if centerY >= 0.66 && centerY < 0.78 {
            return 2.5
        }
        if centerY >= 0.32 && centerY < 0.66 {
            return 0.75
        }
        if centerY < 0.32 {
            return 0.35
        }

        return 1
    }

    private func isTitleBand(_ box: CGRect) -> Bool {
        box.midY >= 0.78 && box.midY <= 0.98
    }

    private func textWeight(for text: String) -> CGFloat {
        let visibleScalars = text.unicodeScalars.filter { !$0.properties.isWhitespace }
        guard visibleScalars.count >= 2 else { return 0.25 }

        if Self.containsRejectedTitleFragment(text) {
            return 0.05
        }

        let letterCount = visibleScalars.filter { CharacterSet.letters.contains($0) }.count
        let digitCount = visibleScalars.filter { CharacterSet.decimalDigits.contains($0) }.count
        let letterFraction = CGFloat(letterCount) / CGFloat(visibleScalars.count)
        let digitFraction = CGFloat(digitCount) / CGFloat(visibleScalars.count)

        if letterFraction >= 0.45 {
            return 1.25
        }
        if digitFraction >= 0.60 {
            return 0.35
        }

        return 0.80
    }

    private func isTopRightHitPointsCue(
        _ text: String,
        box: CGRect
    ) -> Bool {
        guard isTitleBand(box) else { return false }
        guard box.midX >= 0.64 else { return false }

        let compact = text.replacingOccurrences(of: " ", with: "").lowercased()
        let digitCount = compact.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) }.count
        guard digitCount > 0 else { return false }

        return compact.contains("hp")
            || compact.hasPrefix("h")
            || Self.hitPointTextFragments.contains { compact.contains($0) }
    }

    private func headerCueScore(in observations: [PokemonCardRawTextObservation]) -> CGFloat {
        observations.reduce(CGFloat(0)) { partialScore, observation in
            let box = observation.boundingBox.standardized
            guard isTopRightHitPointsCue(observation.text, box: box) else {
                return partialScore
            }

            return partialScore + CGFloat(observation.confidence)
        }
    }

    fileprivate static func containsRejectedTitleFragment(_ text: String) -> Bool {
        let compact = text.replacingOccurrences(of: " ", with: "").lowercased()

        return rejectedTitleFragments.contains { fragment in
            compact.contains(fragment.lowercased())
        }
    }

    private func isPortrait(_ image: UIImage) -> Bool {
        image.size.height >= image.size.width
    }

    private func candidateRotations(for image: UIImage) -> [PokemonCardOrientationRotation] {
        if isPortrait(image) {
            return [.none, .clockwise180]
        }

        return [.clockwise90, .counterclockwise90]
    }

    private func rotated(
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

    private func rotate(
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

    private static let recognitionConfiguration = PokemonCardTextRecognizerConfiguration(
        recognitionLevel: .fast,
        automaticallyDetectsLanguage: true,
        recognitionLanguages: [],
        minimumTextHeight: 0.008,
        regionOfInterest: nil
    )

    private static let hitPointTextFragments = [
        "60",
        "70",
        "80",
        "90",
        "100",
        "110",
        "120",
        "130",
        "140",
        "150",
        "160",
        "170",
        "180",
        "190",
        "200",
        "210",
        "220",
        "230",
        "240",
        "250",
        "260",
        "270",
        "280",
        "290",
        "300",
        "310",
        "320",
        "330",
        "340",
    ]

    fileprivate static let rejectedTitleFragments = [
        "hp",
        "기본",
        "진화",
        "進化",
        "から",
        "테라스탈",
        "약점",
        "저항력",
        "후퇴",
        "弱点",
        "抵抗力",
        "にげる",
        "撤退",
        "전국도감",
        "illus",
        "pokemon",
        "pokémon",
        "nintendo",
        "creatures",
        "gamefreak",
        "상대의모습",
        "놀라게",
        "둔갑",
        "둔잡",
        "말수",
    ]
}

private struct OrientationCandidate {
    let rotation: PokemonCardOrientationRotation
    let image: UIImage
}

private struct ScoredOrientationCandidate {
    let candidate: OrientationCandidate
    let observations: [PokemonCardRawTextObservation]
    let score: CGFloat

    var evidence: PokemonCardOrientationEvidence {
        PokemonCardOrientationEvidence(
            rotation: candidate.rotation,
            score: score,
            observationCount: observations.count,
            topText:
                observations
                .sorted { $0.confidence > $1.confidence }
                .prefix(3)
                .map(\.text)
        )
    }

    var titleBandEvidenceScore: CGFloat {
        observations.reduce(CGFloat(0)) { partialScore, observation in
            let box = observation.boundingBox.standardized
            guard box.width > 0, box.height > 0 else { return partialScore }
            guard box.midY >= 0.78, box.midY <= 0.98, box.midX <= 0.42 else {
                return partialScore
            }

            let visibleScalars = observation.text.unicodeScalars.filter { !$0.properties.isWhitespace }
            guard visibleScalars.count >= 2 else { return partialScore }
            guard !PokemonCardOrientationCorrector.containsRejectedTitleFragment(observation.text) else {
                return partialScore - (CGFloat(observation.confidence) * 1.5)
            }

            let letterCount = visibleScalars.filter { CharacterSet.letters.contains($0) }.count
            let digitCount = visibleScalars.filter { CharacterSet.decimalDigits.contains($0) }.count
            let letterFraction = CGFloat(letterCount) / CGFloat(visibleScalars.count)
            let digitFraction = CGFloat(digitCount) / CGFloat(visibleScalars.count)
            guard letterFraction >= 0.45, digitFraction < 0.35 else { return partialScore }

            return partialScore + (CGFloat(observation.confidence) * min(box.height * 12, 1.4))
        }
    }
}

extension PokemonCardOrientationRotation {
    fileprivate var sortPriority: Int {
        switch self {
        case .none:
            0
        case .clockwise90:
            1
        case .clockwise180:
            2
        case .counterclockwise90:
            3
        }
    }
}
