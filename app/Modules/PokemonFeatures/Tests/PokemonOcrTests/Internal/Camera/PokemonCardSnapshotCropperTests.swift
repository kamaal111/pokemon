//
//  PokemonCardSnapshotCropperTests.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/18/26.
//

import CoreGraphics
import Testing

@testable import PokemonOcr

@Suite("PokemonCardSnapshotCropper Tests")
struct PokemonCardSnapshotCropperTests {
    @Test
    func `Should convert normalized Vision box into padded image crop rect`() {
        let detection = PokemonCardShapeDetection(
            boundingBox: CGRect(x: 0.25, y: 0.2, width: 0.4, height: 0.5),
            confidence: 0.9
        )

        let rect = PokemonCardSnapshotCropper.cropRect(
            for: detection,
            in: CGSize(width: 1000, height: 2000)
        )

        #expect(rect == CGRect(x: 210, y: 520, width: 481, height: 1160))
    }

    @Test
    func `Should keep padded crop inside image bounds`() {
        let detection = PokemonCardShapeDetection(
            boundingBox: CGRect(x: 0.01, y: 0.02, width: 0.2, height: 0.3),
            confidence: 0.9
        )

        let rect = PokemonCardSnapshotCropper.cropRect(
            for: detection,
            in: CGSize(width: 1000, height: 2000)
        )

        #expect(rect == CGRect(x: 0, y: 1280, width: 250, height: 720))
    }
}
