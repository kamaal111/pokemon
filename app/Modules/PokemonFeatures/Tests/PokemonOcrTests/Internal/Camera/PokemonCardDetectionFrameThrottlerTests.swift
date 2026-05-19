//
//  PokemonCardDetectionFrameThrottlerTests.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/19/26.
//

import Testing

@testable import PokemonOcr

@Suite("PokemonCardDetectionFrameThrottler Tests")
struct PokemonCardDetectionFrameThrottlerTests {
    @Test
    func `Should run detection for first frame`() {
        var throttler = PokemonCardDetectionFrameThrottler()
        let shouldRun = throttler.shouldRunDetection(at: 10)

        #expect(shouldRun)
    }

    @Test
    func `Should skip frames before interval`() {
        var throttler = PokemonCardDetectionFrameThrottler(interval: 0.25)

        let firstShouldRun = throttler.shouldRunDetection(at: 10)
        let secondShouldRun = throttler.shouldRunDetection(at: 10.20)

        #expect(firstShouldRun)
        #expect(!secondShouldRun)
    }

    @Test
    func `Should run frames after interval`() {
        var throttler = PokemonCardDetectionFrameThrottler(interval: 0.25)

        let firstShouldRun = throttler.shouldRunDetection(at: 10)
        let secondShouldRun = throttler.shouldRunDetection(at: 10.25)
        let thirdShouldRun = throttler.shouldRunDetection(at: 10.30)
        let fourthShouldRun = throttler.shouldRunDetection(at: 10.51)

        #expect(firstShouldRun)
        #expect(secondShouldRun)
        #expect(!thirdShouldRun)
        #expect(fourthShouldRun)
    }

    @Test
    func `Should allow immediate detection after reset`() {
        var throttler = PokemonCardDetectionFrameThrottler(interval: 0.25)

        let firstShouldRun = throttler.shouldRunDetection(at: 10)
        let secondShouldRun = throttler.shouldRunDetection(at: 10.10)
        throttler.reset()
        let thirdShouldRun = throttler.shouldRunDetection(at: 10.11)

        #expect(firstShouldRun)
        #expect(!secondShouldRun)
        #expect(thirdShouldRun)
    }
}
