//
//  PokemonCardTextExtractionSampleSmokeTests.swift
//  PokemonCardPipeline
//
//  Created by Kamaal M Farah on 5/25/26.
//

import Foundation
import PokemonCardUtilities
import Testing
import UIKit

@testable import PokemonCardTextExtraction

@Suite("PokemonCardTextExtraction Sample Smoke Tests")
struct PokemonCardTextExtractionSampleSmokeTests {
    @Test
    func `Should extract non-empty observations from every bundled sample`() async throws {
        let extractor = PokemonCardTextExtractor()

        for sample in SampleCard.allCases {
            let result = try await extractor.extractText(from: sample.image).get()

            #expect(!result.observations.isEmpty, "Expected OCR observations for \(sample.rawValue)")
        }
    }

    @Test
    func `Should cover Latin Hangul Kana Kanji and Chinese scripts across samples`() async throws {
        let extractor = PokemonCardTextExtractor()
        var combinedText = ""

        for sample in SampleCard.allCases {
            let result = try await extractor.extractText(from: sample.image).get()
            combinedText += "\n" + result.combinedText
        }

        let containsLatin = combinedText.contains(where: \.isLatinScript)
        let containsHangul = combinedText.contains(where: \.isHangulScript)
        let containsKana = combinedText.contains(where: \.isKanaScript)
        let containsKanjiOrChinese = combinedText.contains(where: \.isKanjiOrChineseScript)

        #expect(containsLatin)
        #expect(containsHangul)
        #expect(containsKana)
        #expect(containsKanjiOrChinese)
    }
}

private enum SampleCard: String, CaseIterable {
    case cameraMeowth = "camera-meowth"
    case eevee
    case insectChinese = "insect-chinese"
    case shinyCharmeleon = "shiny-charmeleon"
    case trainersGhost = "trainers-ghost"
    case trainersSnorlax = "trainers-snorlax"
    case trainersWold = "trainers-wold"

    var image: UIImage {
        let url =
            Bundle.module.url(forResource: rawValue, withExtension: "jpg")
            ?? Bundle.module.url(forResource: rawValue, withExtension: "jpg", subdirectory: "SampleCards")
        guard let url else { preconditionFailure("Missing sample image resource: \(rawValue).jpg") }

        let data = try? Data(contentsOf: url)
        guard let data else { preconditionFailure("Sample image could not be loaded: \(rawValue).jpg") }

        let image = UIImage(data: data)
        guard let image else { preconditionFailure("Sample image could not be decoded: \(rawValue).jpg") }

        return image
    }
}
