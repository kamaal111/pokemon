//
//  PokemonCardTextGeometry.swift
//  PokemonCardPipeline
//
//  Created by Kamaal M Farah on 5/25/26.
//

import CoreGraphics

enum PokemonCardTextGeometry {
    static func project(
        observationBoundingBox: CGRect,
        from regionOfInterest: CGRect?
    ) -> CGRect {
        guard let regionOfInterest else { return observationBoundingBox.standardized }

        return CGRect(
            x: regionOfInterest.minX + (observationBoundingBox.minX * regionOfInterest.width),
            y: regionOfInterest.minY + (observationBoundingBox.minY * regionOfInterest.height),
            width: observationBoundingBox.width * regionOfInterest.width,
            height: observationBoundingBox.height * regionOfInterest.height
        ).standardized
    }

    static func imageRect(
        for normalizedBoundingBox: CGRect,
        imageSize: CGSize
    ) -> CGRect {
        CGRect(
            x: normalizedBoundingBox.minX * imageSize.width,
            y: (1 - normalizedBoundingBox.maxY) * imageSize.height,
            width: normalizedBoundingBox.width * imageSize.width,
            height: normalizedBoundingBox.height * imageSize.height
        ).standardized
    }

    static func intersectionOverUnion(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.standardized.intersection(rhs.standardized)
        guard !intersection.isNull else { return 0 }

        let intersectionArea = intersection.width * intersection.height
        let unionArea = (lhs.width * lhs.height + rhs.width * rhs.height) - intersectionArea
        guard unionArea > 0 else { return 0 }

        return intersectionArea / unionArea
    }
}
