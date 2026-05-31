//
//  PokemonCardCameraRefocusCoordinatorTests.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/31/26.
//

import CoreGraphics
import Testing

@testable import PokemonCardFocusQuality
@testable import PokemonOcr

@Suite("PokemonCardCameraRefocusCoordinator Tests")
struct PokemonCardCameraRefocusCoordinatorTests {
    @Test
    func `Should request focus for the first detected card point`() {
        let coordinator = PokemonCardCameraRefocusCoordinator()
        let shouldRequest = coordinator.shouldRequestFocus(
            point: CGPoint(x: 0.5, y: 0.5),
            focusQuality: PokemonCardFocusQualityReport.focused(),
            at: 10
        )

        #expect(shouldRequest)
    }

    @Test
    func `Should not request focus repeatedly before interval expires`() {
        let coordinator = PokemonCardCameraRefocusCoordinator()

        let first = coordinator.shouldRequestFocus(
            point: CGPoint(x: 0.5, y: 0.5),
            focusQuality: PokemonCardFocusQualityReport.focused(),
            at: 10
        )
        let second = coordinator.shouldRequestFocus(
            point: CGPoint(x: 0.7, y: 0.7),
            focusQuality: PokemonCardFocusQualityReport.focused(),
            at: 10.2
        )
        let third = coordinator.shouldRequestFocus(
            point: CGPoint(x: 0.7, y: 0.7),
            focusQuality: PokemonCardFocusQualityReport.focused(),
            at: 10.9
        )

        #expect(first)
        #expect(!second)
        #expect(third)
    }

    @Test
    func `Should request focus after persistent blur`() {
        let coordinator = PokemonCardCameraRefocusCoordinator()
        coordinator.markFocusRequested(point: CGPoint(x: 0.5, y: 0.5), at: 10)

        let first = coordinator.shouldRequestFocus(
            point: CGPoint(x: 0.51, y: 0.51),
            focusQuality: .rejected(reason: .tooBlurry, normalizedRegion: PokemonCardFocusQualityAnalyzer.fullRegion),
            at: 11
        )
        let second = coordinator.shouldRequestFocus(
            point: CGPoint(x: 0.51, y: 0.51),
            focusQuality: .rejected(reason: .tooBlurry, normalizedRegion: PokemonCardFocusQualityAnalyzer.fullRegion),
            at: 11.3
        )

        #expect(!first)
        #expect(second)
    }

    @Test
    func `Should report focus settling window`() {
        let coordinator = PokemonCardCameraRefocusCoordinator()
        coordinator.markFocusRequested(point: CGPoint(x: 0.5, y: 0.5), at: 10)

        #expect(coordinator.isSettling(at: 10.5))
        #expect(!coordinator.isSettling(at: 10.7))
    }
}
