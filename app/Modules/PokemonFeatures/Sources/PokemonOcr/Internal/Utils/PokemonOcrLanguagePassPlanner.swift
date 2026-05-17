//
//  PokemonOcrLanguagePassPlanner.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/17/26.
//

import Foundation

enum PokemonOcrLanguagePassPlanner {
    private static let defaultLanguagePasses: [[PokemonRecognitionLanguage]] = [
        [.japaneseJapan],
        [.koreanKorea],
        [.chineseSimplified, .chineseTraditional],
        [.englishUnitedStates],
    ]
    private static let latinSuffixes = ["VMAX", "VSTAR", "ex", "EX", "GX", "V"]

    static func supplementalLanguagePasses(
        for candidates: [PokemonOcrCandidate],
        selectedCandidate: PokemonOcrCandidate?
    ) -> [[PokemonRecognitionLanguage]] {
        let evidenceTexts = evidenceTexts(from: candidates, selectedCandidate: selectedCandidate)
        let primaryLanguage = evidenceTexts.compactMap(inferredPrimaryLanguage).first
        guard let primaryLanguage else {
            return defaultLanguagePasses
        }

        return reorderedLanguagePasses(primaryLanguageFirst: primaryLanguage)
    }

    private static func evidenceTexts(
        from candidates: [PokemonOcrCandidate],
        selectedCandidate: PokemonOcrCandidate?
    ) -> [String] {
        let selectedTexts = selectedCandidate.map { [$0.normalizedText] } ?? []
        let candidateTexts = candidates.map(\.normalizedText)

        return selectedTexts + candidateTexts
    }

    private static func inferredPrimaryLanguage(
        for text: String
    ) -> PokemonRecognitionLanguage? {
        let titleText = strippedLatinMechanicSuffixes(from: text)
        guard !titleText.isEmpty else {
            return nil
        }

        if containsJapaneseSignal(titleText) {
            return .japaneseJapan
        }

        if containsKoreanSignal(titleText) {
            return .koreanKorea
        }

        if containsChineseSignal(titleText) {
            return .chineseSimplified
        }

        if containsPlausibleLatinTitle(titleText) {
            return .englishUnitedStates
        }

        return nil
    }

    private static func reorderedLanguagePasses(
        primaryLanguageFirst primaryLanguage: PokemonRecognitionLanguage
    ) -> [[PokemonRecognitionLanguage]] {
        let primaryPass = languagePass(containing: primaryLanguage)
        guard let primaryPass else {
            return defaultLanguagePasses
        }

        return [primaryPass] + defaultLanguagePasses.filter { pass in pass != primaryPass }
    }

    private static func languagePass(
        containing language: PokemonRecognitionLanguage
    ) -> [PokemonRecognitionLanguage]? {
        defaultLanguagePasses.first { pass in pass.contains(language) }
    }

    private static func strippedLatinMechanicSuffixes(from text: String) -> String {
        var strippedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var strippedSuffix = true
        while strippedSuffix {
            strippedSuffix = false
            for suffix in latinSuffixes {
                guard strippedText.hasSuffix(suffix) else {
                    continue
                }

                strippedText = String(strippedText.dropLast(suffix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                strippedSuffix = true
                break
            }
        }

        return strippedText
    }

    private static func containsJapaneseSignal(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            scalar == "の" || PokemonCardTitleNormalizer.isHiragana(scalar)
                || PokemonCardTitleNormalizer.isKatakana(scalar)
        }
    }

    private static func containsKoreanSignal(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            scalar == "의" || PokemonCardTitleNormalizer.isHangul(scalar)
        }
    }

    private static func containsChineseSignal(_ text: String) -> Bool {
        let scalars = Array(text.unicodeScalars)
        if scalars.contains("的") {
            return true
        }

        let cjkScalars = scalars.filter(PokemonCardTitleNormalizer.isCJK)
        guard !cjkScalars.isEmpty else {
            return false
        }

        return cjkScalars.count == scalars.count
    }

    private static func containsPlausibleLatinTitle(_ text: String) -> Bool {
        let scalars = text.unicodeScalars
        let containsLatin = scalars.contains { scalar in
            CharacterSet.letters.contains(scalar)
                && !PokemonCardTitleNormalizer.containsSupportedNameScript(String(scalar))
        }
        guard containsLatin else {
            return false
        }

        return !PokemonCardTitleNormalizer.containsSupportedNameScript(text)
    }
}
