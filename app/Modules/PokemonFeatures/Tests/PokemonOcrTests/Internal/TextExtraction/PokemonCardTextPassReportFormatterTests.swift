//
//  PokemonCardTextPassReportFormatterTests.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/25/26.
//

import Testing

@testable import PokemonCardTextExtraction
@testable import PokemonOcr

@Suite("PokemonCardTextPassReportFormatter Tests")
struct PokemonCardTextPassReportFormatterTests {
    @Test
    func `Should format empty pass reports`() {
        let report = Self.report(candidateCount: 0, topStrings: [])

        #expect(PokemonCardTextPassReportFormatter.summary(for: report) == "pass: 0 candidates, broad, none")
    }

    @Test
    func `Should format populated pass reports`() {
        let report = Self.report(candidateCount: 2, topStrings: ["Pikachu", "HP 70"])

        #expect(PokemonCardTextPassReportFormatter.summary(for: report) == "pass: 2 candidates, broad, Pikachu | HP 70")
    }

    private static func report(
        candidateCount: Int,
        topStrings: [String]
    ) -> PokemonCardTextRecognitionPassReport {
        PokemonCardTextRecognitionPassReport(
            label: "pass",
            regionOfInterest: nil,
            recognitionLevel: "fast",
            minimumTextHeight: 0.01,
            supportedLanguageCount: 5,
            automaticallyDetectsLanguage: true,
            usedExplicitRecognitionLanguages: true,
            candidateCount: candidateCount,
            topStrings: topStrings
        )
    }
}
