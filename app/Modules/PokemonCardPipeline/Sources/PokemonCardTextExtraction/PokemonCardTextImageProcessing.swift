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

struct PokemonCardProcessedTextImage {
    let label: String
    let image: UIImage
}

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
        guard let croppedImage = croppedImage(from: normalizedImage, regionOfInterest: regionOfInterest) else {
            return normalizedImage
        }

        return croppedImage
    }

    static func croppedImage(
        from image: UIImage,
        regionOfInterest: CGRect
    ) -> UIImage? {
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
        guard let croppedCgImage = cgImage.cropping(to: pixelRect) else { return nil }

        return UIImage(cgImage: croppedCgImage, scale: normalizedImage.scale, orientation: .up)
    }

    static func setIdentifierImages(for image: UIImage) -> [PokemonCardProcessedTextImage] {
        let normalizedImage = normalized(image)
        let cgImage = requiredCgImage(forNormalizedImage: normalizedImage)
        guard let croppedImage = croppedImage(from: cgImage, regionOfInterest: setIdentifierRegion) else {
            return [PokemonCardProcessedTextImage(label: "normalized-set-id-bottom-left", image: normalizedImage)]
        }

        let baseImage = CIImage(cgImage: croppedImage)
        let enhancedImage = processedSetIdentifierImage(from: baseImage, contrast: 3.2, brightness: 0.08)
        let highContrastImage = processedSetIdentifierImage(from: baseImage, contrast: 5.8, brightness: 0.02)
        let invertedImage = invertedImage(from: highContrastImage)

        return [
            PokemonCardProcessedTextImage(
                label: "enhanced-set-id-bottom-left",
                image: uiImage(from: enhancedImage, fallback: croppedImage)
            ),
            PokemonCardProcessedTextImage(
                label: "high-contrast-set-id-bottom-left",
                image: uiImage(from: highContrastImage, fallback: croppedImage)
            ),
            PokemonCardProcessedTextImage(
                label: "inverted-set-id-bottom-left",
                image: uiImage(from: invertedImage, fallback: croppedImage)
            ),
        ]
    }

    private static func croppedImage(from cgImage: CGImage, regionOfInterest: CGRect) -> CGImage? {
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let imageRect = CGRect(
            x: regionOfInterest.minX * imageSize.width,
            y: (1 - regionOfInterest.maxY) * imageSize.height,
            width: regionOfInterest.width * imageSize.width,
            height: regionOfInterest.height * imageSize.height
        ).intersection(CGRect(origin: .zero, size: imageSize))

        return cgImage.cropping(to: imageRect.integral)
    }

    private static func processedSetIdentifierImage(
        from image: CIImage,
        contrast: Float,
        brightness: Float
    ) -> CIImage {
        let scaleFilter = CIFilter.lanczosScaleTransform()
        scaleFilter.inputImage = image
        scaleFilter.scale = 4
        scaleFilter.aspectRatio = 1
        let upscaledImage = scaleFilter.outputImage ?? image

        let colorControlsFilter = CIFilter.colorControls()
        colorControlsFilter.inputImage = upscaledImage
        colorControlsFilter.saturation = 0
        colorControlsFilter.contrast = contrast
        colorControlsFilter.brightness = brightness
        let contrastImage = colorControlsFilter.outputImage ?? upscaledImage

        let sharpenFilter = CIFilter.unsharpMask()
        sharpenFilter.inputImage = contrastImage
        sharpenFilter.radius = 1.0
        sharpenFilter.intensity = 1.8

        return sharpenFilter.outputImage ?? contrastImage
    }

    private static func invertedImage(from image: CIImage) -> CIImage {
        let invertFilter = CIFilter.colorInvert()
        invertFilter.inputImage = image

        return invertFilter.outputImage ?? image
    }

    private static func uiImage(from image: CIImage, fallback: CGImage) -> UIImage {
        let outputRect = image.extent.integral
        guard let cgImage = context.createCGImage(image, from: outputRect) else {
            return UIImage(cgImage: fallback, scale: 1, orientation: .up)
        }

        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }

    private static func requiredCgImage(forNormalizedImage image: UIImage) -> CGImage {
        guard let cgImage = image.cgImage else {
            preconditionFailure("Pokemon OCR image normalization must produce a CGImage-backed image.")
        }

        return cgImage
    }

    private static let setIdentifierRegion = CGRect(x: 0.045, y: 0.015, width: 0.36, height: 0.08)
}
