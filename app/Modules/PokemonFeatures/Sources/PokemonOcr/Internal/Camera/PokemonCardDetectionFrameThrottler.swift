//
//  PokemonCardDetectionFrameThrottler.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/18/26.
//

import Foundation

struct PokemonCardDetectionFrameThrottler {
    private let minimumInterval: TimeInterval

    private var lastDetectionTime: TimeInterval?

    init(minimumInterval: TimeInterval = 0.25) {
        self.minimumInterval = minimumInterval
    }

    mutating func shouldRunDetection(at time: TimeInterval) -> Bool {
        guard let lastDetectionTime else {
            self.lastDetectionTime = time
            return true
        }

        guard time - lastDetectionTime >= minimumInterval else {
            return false
        }

        self.lastDetectionTime = time
        return true
    }

    mutating func reset() {
        lastDetectionTime = nil
    }
}
