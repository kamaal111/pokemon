//
//  VisionPokemonTextRecognitionRequestConfigurationTests.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/17/26.
//

import CoreGraphics
import Testing
import Vision

@testable import PokemonOcr

@Suite("VisionPokemonTextRecognitionRequestConfiguration Tests")
struct VisionPokemonTextRecognitionRequestConfigurationTests {
    @Test
    func `Should configure default Vision request without performing OCR`() {
        let region = CGRect(x: 0.06, y: 0.80, width: 0.75, height: 0.20)
        let configuration = VisionPokemonTextRecognitionRequestConfiguration(
            regionOfInterest: region,
            recognitionLanguages: nil
        )
        let request = configuration.makeRequest(recognitionLevel: .fast)

        #expect(request.recognitionLevel == .fast)
        #expect(request.regionOfInterest == region)
        #expect(request.recognitionLanguages == ["ko-KR", "ja-JP", "zh-Hans", "zh-Hant", "en-US"])
        #expect(request.customWords.contains("이브이"))
        #expect(request.customWords.contains("リザード"))
        #expect(request.customWords.contains("Charmeleon"))
        #expect(request.minimumTextHeight == 0.01)
        #expect(request.usesLanguageCorrection)
    }

    @Test
    func `Should disable language correction for single East Asian language passes`() {
        let japaneseConfiguration = VisionPokemonTextRecognitionRequestConfiguration(
            regionOfInterest: nil,
            recognitionLanguages: [.japaneseJapan]
        )
        let koreanConfiguration = VisionPokemonTextRecognitionRequestConfiguration(
            regionOfInterest: nil,
            recognitionLanguages: [.koreanKorea]
        )
        let chineseConfiguration = VisionPokemonTextRecognitionRequestConfiguration(
            regionOfInterest: nil,
            recognitionLanguages: [.chineseSimplified, .chineseTraditional]
        )

        #expect(!japaneseConfiguration.usesLanguageCorrection)
        #expect(!koreanConfiguration.usesLanguageCorrection)
        #expect(!chineseConfiguration.usesLanguageCorrection)
    }

    @Test
    func `Should keep language correction for English and mixed default passes`() {
        let englishConfiguration = VisionPokemonTextRecognitionRequestConfiguration(
            regionOfInterest: nil,
            recognitionLanguages: [.englishUnitedStates]
        )
        let mixedConfiguration = VisionPokemonTextRecognitionRequestConfiguration(
            regionOfInterest: nil,
            recognitionLanguages: nil
        )

        #expect(englishConfiguration.usesLanguageCorrection)
        #expect(mixedConfiguration.usesLanguageCorrection)
    }
}
