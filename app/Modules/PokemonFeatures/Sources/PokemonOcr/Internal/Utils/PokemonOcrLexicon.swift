//
//  PokemonOcrLexicon.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/16/26.
//

import Foundation

struct PokemonOcrLexicon {
    private static let speciesLexiconUrl = Bundle.module
        .url(forResource: "PokemonSpeciesLexicon", withExtension: "tsv")!
    private static let wordsByLanguage = loadWordsByLanguage()
    private static let speciesMatchers = loadSpeciesMatchers()

    static func customWords(for recognitionLanguages: [PokemonRecognitionLanguage]) -> [String] {
        words(for: recognitionLanguages)
    }

    static func words(for recognitionLanguages: [PokemonRecognitionLanguage]) -> [String] {
        let lexiconLanguages = Set(
            recognitionLanguages.flatMap { language in
                language.lexiconLanguages
            }
        )

        let effectiveLanguages =
            lexiconLanguages.isEmpty ? Set(wordsByLanguage.keys) : lexiconLanguages

        var orderedWords: [String] = []
        var seenWords = Set<String>()
        for language in effectiveLanguages.sorted() {
            guard let words = wordsByLanguage[language] else { continue }

            for word in words where seenWords.insert(word).inserted {
                orderedWords.append(word)
            }
        }

        return orderedWords
    }

    static func bestSpeciesMatchScore(for text: String) -> Double {
        let searchableText = searchableText(for: text)

        return speciesMatchers.reduce(0) { bestScore, matcher in
            guard matcher.matches(searchableText) else { return bestScore }

            return max(bestScore, matcher.score)
        }
    }

    private static func loadWordsByLanguage() -> [String: [String]] {
        let contents = try! String(contentsOf: speciesLexiconUrl, encoding: .utf8)

        return contents.split(whereSeparator: \.isNewline)
            .reduce([String: [String]]()) { wordsByLanguage, line in
                let columns = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
                precondition(
                    columns.count == 2,
                    "Each line should have 2 columns, otherwise the file has been corrupted"
                )

                let language = String(columns[0])
                let word = String(columns[1]).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !word.isEmpty else { return wordsByLanguage }

                var wordsByLanguage = wordsByLanguage
                wordsByLanguage[language, default: []].append(word)

                return wordsByLanguage
            }
    }

    private static func loadSpeciesMatchers() -> [PokemonOcrLexiconSpeciesMatcher] {
        wordsByLanguage.values
            .flatMap(\.self)
            .map(PokemonOcrLexiconSpeciesMatcher.init(speciesName:))
    }

    private static func searchableText(for text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

private struct PokemonOcrLexiconSpeciesMatcher {
    private let speciesName: String
    private let searchableSpeciesName: String
    private let needsLatinBoundary: Bool

    init(speciesName: String) {
        self.speciesName = speciesName
        self.searchableSpeciesName =
            speciesName
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        self.needsLatinBoundary = speciesName.unicodeScalars.allSatisfy { scalar in
            scalar.value < 128
        }
    }

    var score: Double {
        min(120, 70 + Double(speciesName.count * 3))
    }

    func matches(_ text: String) -> Bool {
        guard let range = text.range(of: searchableSpeciesName) else { return false }

        guard needsLatinBoundary else { return true }

        let startsAtBoundary =
            range.lowerBound == text.startIndex
            || !text[text.index(before: range.lowerBound)].isLatinNameCharacter
        let endsAtBoundary =
            range.upperBound == text.endIndex
            || !text[range.upperBound].isLatinNameCharacter

        return startsAtBoundary && endsAtBoundary
    }
}

extension Character {
    fileprivate var isLatinNameCharacter: Bool {
        unicodeScalars.allSatisfy { scalar in
            CharacterSet.letters.contains(scalar)
                || CharacterSet.decimalDigits.contains(scalar)
                || scalar.value == 45
        }
    }
}
