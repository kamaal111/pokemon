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
}
