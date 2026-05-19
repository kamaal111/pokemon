//
//  PokemonCardDetectionFrameThrottler.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/19/26.
//

import Foundation

struct PokemonCardDetectionFrameThrottler {
    let interval: TimeInterval

    private var lastDetectionTime: TimeInterval?

    init(interval: TimeInterval = 0.25) {
        self.interval = interval
    }

    mutating func shouldRunDetection(at time: TimeInterval) -> Bool {
        guard let lastDetectionTime else {
            self.lastDetectionTime = time
            return true
        }

        guard time - lastDetectionTime >= interval else {
            return false
        }

        self.lastDetectionTime = time
        return true
    }

    mutating func reset() {
        lastDetectionTime = nil
    }
}
