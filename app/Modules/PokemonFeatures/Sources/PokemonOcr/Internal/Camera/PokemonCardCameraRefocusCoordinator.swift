//
//  PokemonCardCameraRefocusCoordinator.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/31/26.
//

import CoreGraphics
import Foundation
import PokemonCardFocusQuality

class PokemonCardCameraRefocusCoordinator {
    let minimumRequestInterval: TimeInterval
    let settlingDuration: TimeInterval
    let minimumPointDrift: CGFloat

    private var lastFocusPoint: CGPoint?
    private var lastFocusRequestTime: TimeInterval?
    private var blurryFrameCount = 0

    private init(minimumRequestInterval: TimeInterval, settlingDuration: TimeInterval, minimumPointDrift: CGFloat) {
        self.minimumRequestInterval = minimumRequestInterval
        self.settlingDuration = settlingDuration
        self.minimumPointDrift = minimumPointDrift
    }

    convenience init() {
        self.init(minimumRequestInterval: 0.80, settlingDuration: 0.60, minimumPointDrift: 0.08)
    }

    func shouldRequestFocus(
        point: CGPoint,
        focusQuality: PokemonCardFocusQualityReport?,
        at time: TimeInterval
    ) -> Bool {
        let hasMoved = hasMovedEnough(to: point)
        let isPersistentlyBlurry: Bool
        if focusQuality?.reason == .tooBlurry || focusQuality?.reason == .tooCloseLikely {
            blurryFrameCount += 1
            isPersistentlyBlurry = blurryFrameCount >= 2
        } else {
            blurryFrameCount = 0
            isPersistentlyBlurry = false
        }

        guard hasMoved || isPersistentlyBlurry else { return false }
        guard canRequestFocus(at: time) else { return false }

        lastFocusPoint = point
        lastFocusRequestTime = time
        blurryFrameCount = 0
        return true
    }

    func isSettling(at time: TimeInterval) -> Bool {
        guard let lastFocusRequestTime else { return false }

        return time - lastFocusRequestTime < settlingDuration
    }

    func markFocusRequested(point: CGPoint, at time: TimeInterval) {
        lastFocusPoint = point
        lastFocusRequestTime = time
        blurryFrameCount = 0
    }

    func reset() {
        lastFocusPoint = nil
        lastFocusRequestTime = nil
        blurryFrameCount = 0
    }

    private func hasMovedEnough(to point: CGPoint) -> Bool {
        guard let lastFocusPoint else { return true }

        return hypot(point.x - lastFocusPoint.x, point.y - lastFocusPoint.y) >= minimumPointDrift
    }

    private func canRequestFocus(at time: TimeInterval) -> Bool {
        guard let lastFocusRequestTime else { return true }

        return time - lastFocusRequestTime >= minimumRequestInterval
    }
}
