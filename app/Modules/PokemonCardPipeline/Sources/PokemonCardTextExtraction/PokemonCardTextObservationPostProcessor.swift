//
//  PokemonCardTextObservationPostProcessor.swift
//  PokemonCardPipeline
//
//  Created by Kamaal M Farah on 5/25/26.
//

import CoreGraphics
import Foundation
import KamaalExtensions

enum PokemonCardTextObservationPostProcessor {
    static func normalizedText(_ text: String) -> String {
        text
            .precomposedStringWithCompatibilityMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()
    }

    static func deduplicated(
        _ observations: [PokemonCardTextObservation]
    ) -> [PokemonCardTextObservation] {
        observations.reduce([]) { accepted, observation in
            guard !observation.normalizedText.isEmpty else { return accepted }

            func isDuplicate(_ existing: PokemonCardTextObservation) -> Bool {
                existing.normalizedText == observation.normalizedText
                    && PokemonCardTextGeometry.intersectionOverUnion(
                        existing.normalizedBoundingBox,
                        observation.normalizedBoundingBox
                    ) >= 0.35
            }

            let duplicateIndex = accepted.firstIndex(where: isDuplicate)
            guard let duplicateIndex else { return accepted.appended(observation) }

            let existing = accepted[duplicateIndex]
            var accepted = accepted
            accepted[duplicateIndex] = merged(existing, observation)

            return accepted
        }
    }

    static func combinedText(from observations: [PokemonCardTextObservation]) -> String {
        observations
            .sorted(by: readingOrder)
            .map(\.text)
            .joined(separator: "\n")
    }

    static func readingOrder(lhs: PokemonCardTextObservation, rhs: PokemonCardTextObservation) -> Bool {
        let verticalTolerance = CGFloat(0.025)
        let lhsY = lhs.normalizedBoundingBox.midY
        let rhsY = rhs.normalizedBoundingBox.midY

        if abs(lhsY - rhsY) > verticalTolerance {
            return lhsY > rhsY
        }

        return lhs.normalizedBoundingBox.minX < rhs.normalizedBoundingBox.minX
    }

    private static func merged(
        _ lhs: PokemonCardTextObservation,
        _ rhs: PokemonCardTextObservation
    ) -> PokemonCardTextObservation {
        let preferred = lhs.confidence >= rhs.confidence ? lhs : rhs
        let other = lhs.confidence >= rhs.confidence ? rhs : lhs
        let mergedCandidates = uniqueCandidates(preferred.topCandidates + other.topCandidates)

        return PokemonCardTextObservation(
            id: preferred.id,
            text: preferred.text,
            normalizedText: preferred.normalizedText,
            topCandidates: mergedCandidates,
            confidence: preferred.confidence,
            normalizedBoundingBox: preferred.normalizedBoundingBox,
            sourcePassLabel: preferred.sourcePassLabel,
            imageRect: preferred.imageRect
        )
    }

    private static func uniqueCandidates(
        _ candidates: [PokemonCardTextCandidate]
    ) -> [PokemonCardTextCandidate] {
        candidates.reduce([]) { accepted, candidate in
            let normalizedCandidate = normalizedText(candidate.text)
            guard !accepted.contains(where: { normalizedText($0.text) == normalizedCandidate }) else { return accepted }

            return accepted.appended(candidate)
        }
    }
}
