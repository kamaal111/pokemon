//
//  PokemonCardDetectionFrameThrottlerTests.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/18/26.
//

import Testing

@testable import PokemonOcr

@Suite("PokemonCardDetectionFrameThrottler Tests")
struct PokemonCardDetectionFrameThrottlerTests {
    @Test
    func `Should run first detection immediately`() {
        var throttler = PokemonCardDetectionFrameThrottler(minimumInterval: 0.25)

        let shouldRunDetection = throttler.shouldRunDetection(at: 10)

        #expect(shouldRunDetection)
    }

    @Test
    func `Should skip frames inside minimum interval`() {
        var throttler = PokemonCardDetectionFrameThrottler(minimumInterval: 0.25)

        let firstDetection = throttler.shouldRunDetection(at: 10)
        let earlyDetection = throttler.shouldRunDetection(at: 10.2)
        let nextDetection = throttler.shouldRunDetection(at: 10.25)

        #expect(firstDetection)
        #expect(!earlyDetection)
        #expect(nextDetection)
    }

    @Test
    func `Should reset detection timing`() {
        var throttler = PokemonCardDetectionFrameThrottler(minimumInterval: 0.25)

        _ = throttler.shouldRunDetection(at: 10)
        throttler.reset()
        let shouldRunDetection = throttler.shouldRunDetection(at: 10.1)

        #expect(shouldRunDetection)
    }
}
