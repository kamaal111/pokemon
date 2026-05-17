//
//  PokemonCardSnapshotCropper.swift
//  PokemonFeatures
//
//  Created by Kamaal M Farah on 5/18/26.
//

import CoreGraphics
import UIKit

enum PokemonCardSnapshotCropper {
    private static let cropPadding: CGFloat = 0.04

    static func cropCard(from image: UIImage, detection: PokemonCardShapeDetection) -> UIImage {
        guard let cgImage = image.cgImage else {
            return image
        }

        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let rect = cropRect(for: detection, in: imageSize)
        guard let croppedImage = cgImage.cropping(to: rect) else {
            return image
        }

        return UIImage(cgImage: croppedImage, scale: image.scale, orientation: .up)
    }

    static func cropRect(
        for detection: PokemonCardShapeDetection,
        in imageSize: CGSize
    ) -> CGRect {
        let paddedBoundingBox = detection.boundingBox.insetBy(
            dx: -cropPadding,
            dy: -cropPadding
        )
        let boundedBox = paddedBoundingBox.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))

        return CGRect(
            x: boundedBox.minX * imageSize.width,
            y: (1 - boundedBox.maxY) * imageSize.height,
            width: boundedBox.width * imageSize.width,
            height: boundedBox.height * imageSize.height
        ).integral
    }
}
