//
//  PokemonCardSetIdentifierLexicon.swift
//  PokemonCardPipeline
//
//  Created by Codex on 6/14/26.
//

import Foundation

enum PokemonCardSetIdentifierLexicon {
    private static let lexiconUrl = Bundle.module
        .url(forResource: "PokemonSetIdentifierLexicon", withExtension: "tsv")!
    private static let loadedCodes = loadCodes()

    static var codes: [String] {
        loadedCodes.ordered
    }

    static var codesByDescendingLength: [String] {
        loadedCodes.byDescendingLength
    }

    static func contains(_ code: String) -> Bool {
        loadedCodes.set.contains(code)
    }

    private static func loadCodes() -> (ordered: [String], byDescendingLength: [String], set: Set<String>) {
        let contents = try! String(contentsOf: lexiconUrl, encoding: .utf8)
        var orderedCodes: [String] = []
        var seenCodes = Set<String>()

        for line in contents.split(whereSeparator: \.isNewline) {
            let columns = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
            precondition(
                columns.count == 2,
                "Each line should have 2 columns, otherwise the file has been corrupted"
            )

            let code = String(columns[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !code.isEmpty else { continue }
            guard seenCodes.insert(code).inserted else { continue }

            orderedCodes.append(code)
        }

        let byDescendingLength = orderedCodes.sorted { left, right in
            if left.count == right.count {
                return left < right
            }

            return left.count > right.count
        }

        return (orderedCodes, byDescendingLength, seenCodes)
    }
}
