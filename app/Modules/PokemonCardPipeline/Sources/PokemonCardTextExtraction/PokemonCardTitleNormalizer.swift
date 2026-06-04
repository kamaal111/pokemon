//
//  PokemonCardTitleNormalizer.swift
//  PokemonCardPipeline
//
//  Created by Codex on 6/4/26.
//

import Foundation
import PokemonCardUtilities

enum PokemonCardTitleNormalizer {
    static func normalize(_ text: String) -> String {
        let foldedText = foldFullWidthLatin(text)
        var normalizedText = foldedText.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Vision can split East Asian title glyphs with spaces. Collapse those
        // gaps only when the title is entirely in supported non-Latin scripts so
        // mixed names like "N의 조로아" keep their meaningful word spacing.
        if shouldCompactSupportedScriptSpacing(in: normalizedText) {
            normalizedText = normalizedText.components(separatedBy: .whitespacesAndNewlines)
                .joined()
        }

        if shouldRepairTrailingE(normalizedText) {
            normalizedText.removeLast()
            normalizedText.append("ex")
        }

        return normalizeCjkExSuffix(in: normalizedText)
    }

    /// Converts OCR output that uses East Asian full-width Latin glyphs into the
    /// ASCII forms the rest of the title normalization pipeline expects.
    ///
    /// This keeps non-Latin scalars untouched while fixing the two width variants
    /// that commonly appear in card titles:
    /// - U+3000 ideographic spaces become standard spaces.
    /// - U+FF01...U+FF5E full-width ASCII variants become their half-width forms.
    private static func foldFullWidthLatin(_ text: String) -> String {
        let scalars = text.unicodeScalars.compactMap { scalar in
            // Japanese OCR often emits ideographic spaces, but later whitespace
            // cleanup expects the regular ASCII space scalar.
            if scalar.value == 0x3000 {
                return Unicode.Scalar(0x20)
            }

            // Full-width Latin letters, digits, and punctuation live in a block
            // with a fixed offset from ASCII, so subtracting that offset folds
            // them back to the standard half-width representation.
            if (0xFF01...0xFF5E).contains(scalar.value) {
                return Unicode.Scalar(scalar.value - 0xFEE0)
            }

            // Leave every other scalar alone so non-Latin scripts preserve their
            // original code points and downstream script detection still works.
            return scalar
        }

        return String(String.UnicodeScalarView(scalars))
    }

    static func containsSupportedNameScript(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            isHiragana(scalar) || isKatakana(scalar) || isCJK(scalar) || isHangul(scalar)
        }
    }

    static func containsLatinLetters(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            CharacterSet.letters.contains(scalar) && !containsSupportedNameScript(String(scalar))
        }
    }

    private static func shouldCompactSupportedScriptSpacing(in text: String) -> Bool {
        containsSupportedNameScript(text) && !containsLatinLetters(text)
    }

    private static func shouldRepairTrailingE(_ text: String) -> Bool {
        guard text.hasSuffix("e") else {
            return false
        }

        let prefix = text.dropLast()
        return prefix.unicodeScalars.contains { scalar in
            isHiragana(scalar) || isKatakana(scalar) || isCJK(scalar) || isHangul(scalar)
        }
    }

    private static func normalizeCjkExSuffix(in text: String) -> String {
        guard text.count >= 2 else {
            return text
        }

        let suffix = String(text.suffix(2))
        guard suffix.lowercased() == "ex" else {
            return text
        }

        let prefix = text.dropLast(2)
        let containsSupportedPrefixScript = prefix.unicodeScalars.contains { scalar in
            isHiragana(scalar) || isKatakana(scalar) || isCJK(scalar) || isHangul(scalar)
        }
        guard containsSupportedPrefixScript else {
            return text
        }

        return "\(prefix.trimmingCharacters(in: .whitespacesAndNewlines))ex"
    }

    /// Matches Hiragana scalars so we can recognize Japanese card names that
    /// OCR reads in their phonetic script rather than Latin letters.
    static func isHiragana(_ scalar: Unicode.Scalar) -> Bool {
        scalar.isHiraganaScript
    }

    /// Matches Katakana scalars, which commonly appear in Japanese Pokemon
    /// names and suffixes captured from the card title line.
    static func isKatakana(_ scalar: Unicode.Scalar) -> Bool {
        scalar.isKatakanaScript
    }

    /// Matches the unified CJK ideograph block so kanji-based titles still
    /// count as supported name script during OCR cleanup.
    static func isCJK(_ scalar: Unicode.Scalar) -> Bool {
        scalar.isKanjiOrChineseScript
    }

    /// Matches Hangul syllables so Korean card titles participate in the same
    /// mixed-script normalization path as Japanese and Chinese titles.
    static func isHangul(_ scalar: Unicode.Scalar) -> Bool {
        scalar.isHangulScript
    }
}
