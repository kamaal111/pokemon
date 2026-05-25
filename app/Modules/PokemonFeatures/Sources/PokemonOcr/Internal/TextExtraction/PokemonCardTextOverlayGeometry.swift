//
//  PokemonCardTextOverlayGeometry.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/25/26.
//

import CoreGraphics

enum PokemonCardTextOverlayGeometry {
    static func displayedImageFrame(
        imageSize: CGSize,
        containerSize: CGSize
    ) -> CGRect {
        guard imageSize.width > 0 else { return .zero }
        guard imageSize.height > 0 else { return .zero }
        guard containerSize.width > 0 else { return .zero }
        guard containerSize.height > 0 else { return .zero }

        let scale = min(
            containerSize.width / imageSize.width,
            containerSize.height / imageSize.height
        )
        let displayedSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )

        return CGRect(
            x: (containerSize.width - displayedSize.width) / 2,
            y: (containerSize.height - displayedSize.height) / 2,
            width: displayedSize.width,
            height: displayedSize.height
        )
    }

    static func displayRect(
        for normalizedBoundingBox: CGRect,
        imageSize: CGSize,
        containerSize: CGSize
    ) -> CGRect {
        let imageFrame = displayedImageFrame(imageSize: imageSize, containerSize: containerSize)
        guard imageFrame.width > 0 else { return .zero }
        guard imageFrame.height > 0 else { return .zero }

        return CGRect(
            x: imageFrame.minX + (normalizedBoundingBox.minX * imageFrame.width),
            y: imageFrame.minY + ((1 - normalizedBoundingBox.maxY) * imageFrame.height),
            width: normalizedBoundingBox.width * imageFrame.width,
            height: normalizedBoundingBox.height * imageFrame.height
        )
    }
}
