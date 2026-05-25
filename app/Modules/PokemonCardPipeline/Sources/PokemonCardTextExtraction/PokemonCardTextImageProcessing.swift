//
//  PokemonCardTextImageProcessing.swift
//  PokemonCardPipeline
//
//  Created by Kamaal M Farah on 5/25/26.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import PokemonCardImageProcessing
import UIKit

enum PokemonCardTextImageProcessing {
    private static let context = CIContext()

    static func normalized(_ image: UIImage) -> UIImage {
        PokemonCardImageNormalizer.normalizedForPokemonOcr(image)
    }

    static func enhanced(_ image: UIImage) -> UIImage {
        let normalizedImage = normalized(image)
        let cgImage = requiredCgImage(forNormalizedImage: normalizedImage)

        let inputImage = CIImage(cgImage: cgImage)
        let colorControlsFilter = CIFilter.colorControls()
        colorControlsFilter.inputImage = inputImage
        colorControlsFilter.saturation = 0
        colorControlsFilter.contrast = 2.4
        colorControlsFilter.brightness = 0.04
        guard let contrastImage = colorControlsFilter.outputImage else { return normalizedImage }

        let sharpenFilter = CIFilter.unsharpMask()
        sharpenFilter.inputImage = contrastImage
        sharpenFilter.radius = 1.1
        sharpenFilter.intensity = 1.4

        guard let filteredImage = sharpenFilter.outputImage else { return normalizedImage }

        let filteredCgImage = context.createCGImage(filteredImage, from: filteredImage.extent)
        guard let filteredCgImage else { return normalizedImage }

        return UIImage(cgImage: filteredCgImage, scale: normalizedImage.scale, orientation: .up)
    }

    static func croppedDebugImage(
        from image: UIImage,
        regionOfInterest: CGRect
    ) -> UIImage {
        let normalizedImage = normalized(image)
        let cgImage = requiredCgImage(forNormalizedImage: normalizedImage)
        let imageSize = normalizedImage.size
        let imageRect = CGRect(
            x: regionOfInterest.minX * imageSize.width,
            y: (1 - regionOfInterest.maxY) * imageSize.height,
            width: regionOfInterest.width * imageSize.width,
            height: regionOfInterest.height * imageSize.height
        ).intersection(CGRect(origin: .zero, size: imageSize))

        let pixelRect = CGRect(
            x: imageRect.minX * normalizedImage.scale,
            y: imageRect.minY * normalizedImage.scale,
            width: imageRect.width * normalizedImage.scale,
            height: imageRect.height * normalizedImage.scale
        ).integral
        guard let croppedCgImage = cgImage.cropping(to: pixelRect) else { return normalizedImage }

        return UIImage(cgImage: croppedCgImage, scale: normalizedImage.scale, orientation: .up)
    }

    private static func requiredCgImage(forNormalizedImage image: UIImage) -> CGImage {
        guard let cgImage = image.cgImage else {
            preconditionFailure("Pokemon OCR image normalization must produce a CGImage-backed image.")
        }

        return cgImage
    }
}
