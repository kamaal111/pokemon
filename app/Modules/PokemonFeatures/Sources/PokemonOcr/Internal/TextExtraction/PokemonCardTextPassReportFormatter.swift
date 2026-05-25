//
//  PokemonCardTextPassReportFormatter.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/25/26.
//

import PokemonCardTextExtraction

enum PokemonCardTextPassReportFormatter {
    static func summary(for report: PokemonCardTextRecognitionPassReport) -> String {
        let topText = report.topStrings.isEmpty ? "none" : report.topStrings.joined(separator: " | ")
        let languageMode = report.usedExplicitRecognitionLanguages ? "broad" : "auto"

        return "\(report.label): \(report.candidateCount) candidates, \(languageMode), \(topText)"
    }
}
