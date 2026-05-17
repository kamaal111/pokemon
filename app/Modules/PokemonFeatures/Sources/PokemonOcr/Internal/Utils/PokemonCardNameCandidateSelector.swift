//
//  PokemonCardNameCandidateSelector.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/16/26.
//

import Foundation

struct PokemonCardNameCandidateSelector {
    private static let rejectedFragments = ["hp", "기본", "진화", "進化", "から", "테라스탈"]
    private static let latinSuffixes = ["ex", "EX", "GX", "V", "VMAX", "VSTAR"]

    private init() {}

    /// Picks the OCR candidate that most likely represents the printed card name.
    ///
    /// The selector combines OCR confidence with lightweight text and layout
    /// heuristics so likely title candidates beat out labels, stats, and other
    /// nearby text.
    static func chooseBestCandidate(
        from candidates: [PokemonOcrCandidate],
        preferredRegion: CGRect?
    ) -> PokemonOcrCandidate? {
        candidates
            .compactMap { scoredCandidate($0, preferredRegion: preferredRegion) }
            .max { left, right in
                if left.score == right.score {
                    return left.candidate.confidence < right.candidate.confidence
                }

                return left.score < right.score
            }?
            .candidate
    }

    private static func scoredCandidate(
        _ candidate: PokemonOcrCandidate,
        preferredRegion: CGRect?
    ) -> ScoredCandidate? {
        let normalizedText = candidate.normalizedText
        guard !normalizedText.isEmpty else { return nil }
        guard !isJunk(normalizedText) else { return nil }
        guard containsMeaningfulNameCharacters(normalizedText) else { return nil }

        // OCR confidence is the baseline so clearer detections start ahead.
        var score = Double(candidate.confidence) * 100

        // Card names should primarily be written in a supported name script, so
        // this gets a strong bump that can outweigh small OCR confidence swings.
        if PokemonCardTitleNormalizer.containsSupportedNameScript(normalizedText) {
            score += 80
        }

        // Latin letters commonly appear in localized names and suffixes, but are
        // a weaker signal than the main supported-script match above.
        if PokemonCardTitleNormalizer.containsLatinLetters(normalizedText) {
            score += 45
        }

        score += PokemonOcrLexicon.bestSpeciesMatchScore(for: normalizedText)

        // Recognized card suffixes like EX or V are useful tie-breakers because
        // they frequently appear in real card names but not in surrounding text.
        if hasValidLatinSuffix(normalizedText) {
            score += 20
        }

        let characterCount = normalizedText.count
        // Most card names land in this range, so reward plausible lengths and
        // gently penalize strings that are unusually short or long.
        if (2...18).contains(characterCount) {
            score += 15
        } else {
            score -= Double(abs(characterCount - 10))
        }

        // Standalone digits often indicate HP, set numbers, or attack damage
        // rather than the card title, so push those candidates down.
        if normalizedText.rangeOfCharacter(from: .decimalDigits) != nil {
            score -= 35
        }

        // Heavily numeric strings are almost never names, so use a stronger
        // penalty to keep stat-like OCR results from winning.
        if numericCharacterRatio(in: normalizedText) >= 0.5 {
            score -= 80
        }

        if let preferredRegion {
            let intersection = preferredRegion.intersection(candidate.boundingBox)
            let intersectionArea = intersection.area
            let candidateArea = candidate.boundingBox.area
            let overlapRatio = candidateArea > 0 ? intersectionArea / candidateArea : 0

            // Region overlap is one of the strongest layout cues: candidates
            // inside the expected title area should decisively outrank ones that
            // only partially overlap or miss it entirely.
            if overlapRatio >= 0.8 {
                score += 120
            } else if overlapRatio >= 0.35 {
                score += 60
            } else {
                score -= 90
            }

            // Text above the preferred title band is more likely to be headers
            // or labels, so nudge those candidates downward.
            if candidate.boundingBox.minY < preferredRegion.minY {
                score -= 20
            }

            // Very narrow boxes are usually fragments or punctuation rather than
            // full card names.
            if candidate.boundingBox.width < 0.08 {
                score -= 20
            }
        }

        return ScoredCandidate(candidate: candidate, score: score)
    }

    private static func isJunk(_ text: String) -> Bool {
        let compact = text.replacingOccurrences(of: " ", with: "").lowercased()

        return rejectedFragments.contains { fragment in compact.contains(fragment.lowercased()) }
    }

    static func hasValidLatinSuffixForTesting(_ text: String) -> Bool {
        hasValidLatinSuffix(text)
    }

    private static func hasValidLatinSuffix(_ text: String) -> Bool {
        latinSuffixes.contains { suffix in hasValidSuffixBoundary(in: text, suffix: suffix) }
    }

    private static func hasValidSuffixBoundary(in text: String, suffix: String) -> Bool {
        guard text.hasSuffix(suffix) else { return false }

        let prefix = text.dropLast(suffix.count)
        guard let boundaryScalar = prefix.unicodeScalars.last else { return false }

        let isWhitespaceBoundary = CharacterSet.whitespacesAndNewlines.contains(boundaryScalar)
        let isSupportedScriptBoundary = PokemonCardTitleNormalizer.containsSupportedNameScript(String(boundaryScalar))

        return isWhitespaceBoundary || isSupportedScriptBoundary
    }

    private static func containsMeaningfulNameCharacters(_ text: String) -> Bool {
        PokemonCardTitleNormalizer.containsSupportedNameScript(text)
            || PokemonCardTitleNormalizer.containsLatinLetters(text)
    }

    private static func numericCharacterRatio(in text: String) -> Double {
        guard !text.isEmpty else {
            return 0
        }

        let numericCount = text.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) }.count
        return Double(numericCount) / Double(text.count)
    }
}

private struct ScoredCandidate {
    let candidate: PokemonOcrCandidate
    let score: Double
}

extension CGRect {
    fileprivate var area: Double {
        guard !isNull, !isEmpty else {
            return 0
        }

        return Double(width * height)
    }
}
