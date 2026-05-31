//
//  PokemonCardFocusQualityTests.swift
//  PokemonCardPipeline
//
//  Created by Kamaal M Farah on 5/31/26.
//

import PokemonCardPipelineTestSupport
import Testing
import UIKit

@testable import PokemonCardFocusQuality

@Suite("PokemonCardFocusQuality Tests")
struct PokemonCardFocusQualityTests {
    @Test
    func `Should accept a sharp text band`() {
        let report = Self.evaluateReadyFrame(
            image: PokemonCardTestImages.focusQualityCard(),
            cardAreaFraction: Self.normalCardAreaFraction
        )

        #expect(report.isSharpEnough)
        #expect(report.reason == .focused)
        #expect(report.sharpnessScore >= 120)
        #expect(report.gradientScore >= 18)
    }

    @Test
    func `Should reject a blurred text band`() throws {
        let sharpReport = Self.evaluateReadyFrame(
            image: PokemonCardTestImages.focusQualityCard(),
            cardAreaFraction: Self.normalCardAreaFraction
        )
        let blurredReport = Self.evaluateReadyFrame(
            image: try PokemonCardTestImageFilters.gaussianBlurred(PokemonCardTestImages.focusQualityCard()),
            cardAreaFraction: Self.normalCardAreaFraction
        )

        #expect(!blurredReport.isSharpEnough)
        #expect(blurredReport.reason == .tooBlurry)
        #expect(blurredReport.sharpnessScore < sharpReport.sharpnessScore)
        #expect(blurredReport.gradientScore < sharpReport.gradientScore)
    }

    @Test
    func `Should reject a dark frame before blur classification`() {
        let report = Self.evaluateReadyFrame(
            image: PokemonCardTestImages.focusQualityCard(background: .black, text: .darkGray),
            cardAreaFraction: Self.normalCardAreaFraction
        )

        #expect(!report.isSharpEnough)
        #expect(report.reason == .tooDark)
    }

    @Test
    func `Should reject a low contrast frame before blur classification`() {
        let report = Self.evaluateReadyFrame(
            image: PokemonCardTestImages.focusQualityCard(
                background: UIColor(white: 0.55, alpha: 1),
                text: UIColor(white: 0.58, alpha: 1)
            ),
            cardAreaFraction: Self.normalCardAreaFraction
        )

        #expect(!report.isSharpEnough)
        #expect(report.reason == .tooLowContrast)
    }

    @Test
    func `Should classify large blurry card as likely too close`() throws {
        let report = Self.evaluateReadyFrame(
            image: try PokemonCardTestImageFilters.gaussianBlurred(PokemonCardTestImages.focusQualityCard()),
            cardAreaFraction: Self.closeCardAreaFraction
        )

        #expect(!report.isSharpEnough)
        #expect(report.reason == .tooCloseLikely)
    }

    @Test
    func `Should wait while autofocus is adjusting`() {
        let report = PokemonCardFocusQualityAnalyzer.evaluate(
            image: PokemonCardTestImages.focusQualityCard(),
            cardAreaFraction: Self.normalCardAreaFraction,
            isFocusAdjusting: true,
            isFocusSettling: false
        )

        #expect(!report.isSharpEnough)
        #expect(report.reason == .waitingForAutofocus)
    }

    private static func evaluateReadyFrame(
        image: UIImage,
        cardAreaFraction: CGFloat
    ) -> PokemonCardFocusQualityReport {
        PokemonCardFocusQualityAnalyzer.evaluate(
            image: image,
            cardAreaFraction: cardAreaFraction,
            isFocusAdjusting: false,
            isFocusSettling: false
        )
    }

    private static let normalCardAreaFraction: CGFloat = 0.45
    private static let closeCardAreaFraction: CGFloat = 0.80
}
