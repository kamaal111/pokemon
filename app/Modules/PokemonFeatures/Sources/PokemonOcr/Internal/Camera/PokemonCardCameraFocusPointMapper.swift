//
//  PokemonCardCameraFocusPointMapper.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/18/26.
//

import CoreGraphics

enum PokemonCardCameraFocusPointMapper {
    static func devicePoint(for detection: PokemonCardShapeDetection) -> CGPoint {
        CGPoint(
            x: detection.boundingBox.midX,
            y: 1 - detection.boundingBox.midY
        )
    }
}
